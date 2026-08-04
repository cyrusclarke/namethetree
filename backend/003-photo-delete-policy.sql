-- Name That Tree — Migration 003: Owner DELETE policy on tree-photos storage
-- Users should be able to delete their own uploaded photos. Bucket already has
-- SELECT (public read) and INSERT (own-folder write) policies; this adds the
-- matching DELETE policy scoped to the same "<uid>/<file>" folder rule.
-- Safe to re-run.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema='storage' AND table_name='objects'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
       WHERE schemaname='storage' AND policyname='tree_photos_delete'
    ) THEN
      CREATE POLICY tree_photos_delete ON storage.objects FOR DELETE
        USING (
          bucket_id = 'tree-photos'
          AND (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
  END IF;
END $$;
