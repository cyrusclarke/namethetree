/* Name That Tree — network data layer (Phase 2)
   Opt-in Supabase backend. With no window.NTT_CONFIG this stays inert and the
   game runs in local mode (localStorage + simulated crowd) exactly as before.

   Exposes window.NTT_NET:
     enabled            boolean — is a real backend configured + reachable?
     init()             async — sign in (anon), ensure profile, returns {userId, rep}
     fetchTrees()       async — [{id, lat, lng, photo_url, created_by}]
     fetchConsensus()   async — { [treeId]: {leading_label, total_weight, share, resolved} }
     fetchVotes(treeId) async — [{label, label_key, weight, user_id}]
     plantTree({lat,lng,photoUrl}) async — returns new tree id
     castVote(treeId, label) async — server recomputes weight from rep
     onChange(cb)       subscribe to realtime tree/vote changes (returns unsub)
   Every method rejects cleanly if the backend is down; callers fall back to local. */
(function () {
  const CFG = (typeof window !== 'undefined' && window.NTT_CONFIG) || null;
  const net = {
    enabled: false,
    _sb: null,
    _userId: null,
  };

  // Lazy-load the Supabase UMD client only when a backend is configured.
  function loadSupabase() {
    return new Promise((resolve, reject) => {
      if (window.supabase && window.supabase.createClient) return resolve(window.supabase);
      const s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js';
      s.onload = () => resolve(window.supabase);
      s.onerror = () => reject(new Error('supabase-js failed to load'));
      document.head.appendChild(s);
    });
  }

  net.init = async function () {
    if (!CFG || !CFG.supabaseUrl || !CFG.supabaseAnonKey) return null; // local mode
    const lib = await loadSupabase();
    net._sb = lib.createClient(CFG.supabaseUrl, CFG.supabaseAnonKey, {
      auth: { persistSession: true, autoRefreshToken: true },
    });
    // anonymous device account
    let { data: sess } = await net._sb.auth.getSession();
    if (!sess || !sess.session) {
      const { data, error } = await net._sb.auth.signInAnonymously();
      if (error) throw error;
      sess = { session: data.session };
    }
    net._userId = sess.session.user.id;
    // ensure a profile row exists (SPROUT by default)
    await net._sb.from('profiles').upsert(
      { id: net._userId },
      { onConflict: 'id', ignoreDuplicates: true }
    );
    const { data: prof } = await net._sb.from('profiles')
      .select('rep, handle').eq('id', net._userId).single();
    net.enabled = true;
    return { userId: net._userId, rep: (prof && prof.rep) || 0, handle: prof && prof.handle };
  };

  net.fetchTrees = async function () {
    const { data, error } = await net._sb.from('trees').select('*');
    if (error) throw error;
    return data || [];
  };

  net.fetchConsensus = async function () {
    const { data, error } = await net._sb.from('tree_consensus').select('*');
    if (error) throw error;
    const out = {};
    (data || []).forEach(r => { out[r.tree_id] = r; });
    return out;
  };

  net.fetchVotes = async function (treeId) {
    const q = net._sb.from('votes').select('label, label_key, weight, user_id');
    const { data, error } = treeId ? await q.eq('tree_id', treeId) : await q;
    if (error) throw error;
    return data || [];
  };

  // upload a dataURL snap to the tree-photos bucket, return its public URL
  net.uploadPhoto = async function (dataUrl) {
    if (!dataUrl || !net._userId) return null;
    const blob = await (await fetch(dataUrl)).blob();
    const path = net._userId + '/' + Date.now() + '.jpg';
    const { error } = await net._sb.storage.from('tree-photos')
      .upload(path, blob, { contentType: 'image/jpeg', upsert: false });
    if (error) throw error;
    const { data } = net._sb.storage.from('tree-photos').getPublicUrl(path);
    return data.publicUrl;
  };

  net.plantTree = async function ({ lat, lng, photoUrl }) {
    const { data, error } = await net._sb.from('trees')
      .insert({ lat, lng, photo_url: photoUrl || null, created_by: net._userId })
      .select('id').single();
    if (error) throw error;
    return data.id;
  };

  net.castVote = async function (treeId, label) {
    const { data, error } = await net._sb.rpc('cast_vote', { p_tree: treeId, p_label: label });
    if (error) throw error;
    // server returns { verdict, repDelta, rep, resolved, resolvedLabel }
    return data || null;
  };

  // fetch the caller's current rep from profiles (server is source of truth)
  net.fetchMyRep = async function () {
    if (!net._userId) return null;
    const { data, error } = await net._sb.from('profiles')
      .select('rep').eq('id', net._userId).single();
    if (error) throw error;
    return (data && typeof data.rep === 'number') ? data.rep : 0;
  };

  net.onChange = function (cb) {
    if (!net._sb) return () => {};
    const ch = net._sb
      .channel('ntt-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'votes' }, cb)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trees' }, cb)
      .subscribe();
    return () => { try { net._sb.removeChannel(ch); } catch (e) {} };
  };

  if (typeof window !== 'undefined') window.NTT_NET = net;
})();
