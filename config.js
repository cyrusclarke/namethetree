/* Name That Tree — runtime backend config.
   Sets window.NTT_CONFIG before net.js loads. With this present the game runs
   in backend (live crowd) mode; remove it and the game falls back to local mode.

   The anon key is SAFE to ship in a static site: all writes are guarded by
   Row Level Security + the server-authoritative cast_vote RPC (see DECISIONS.md).
   It is a public, rate-limited, RLS-scoped key — not a secret. */
window.NTT_CONFIG = {
  supabaseUrl: 'https://lfxporaztupmxelxvowr.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxmeHBvcmF6dHVwbXhlbHh2b3dyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU4Njg1MzYsImV4cCI6MjEwMTQ0NDUzNn0.3Nn9yWwC05-5d-4WGsOLzUgln8K5uIG76fnPVY1CSA4',
};
