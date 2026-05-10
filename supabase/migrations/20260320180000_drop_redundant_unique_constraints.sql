-- Drop redundant UNIQUE constraints on follows, fires, and saved_outfits when more than one
-- exists on the same table (duplicate enforcement / extra indexes). Keeps the lexicographically
-- first constraint name and removes the rest. Safe no-op if only one UNIQUE (besides PK) exists.
-- See docs/REMAINING_WORK.md §1.2 additional finding.

DO $$
DECLARE
  tbl text;
  keep_name text;
  drop_name text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['follows', 'fires', 'saved_outfits']
  LOOP
    SELECT c.conname INTO keep_name
    FROM pg_constraint c
    WHERE c.conrelid = format('public.%I', tbl)::regclass
      AND c.contype = 'u'
    ORDER BY c.conname
    LIMIT 1;

    IF keep_name IS NULL THEN
      CONTINUE;
    END IF;

    FOR drop_name IN
      SELECT c.conname
      FROM pg_constraint c
      WHERE c.conrelid = format('public.%I', tbl)::regclass
        AND c.contype = 'u'
        AND c.conname <> keep_name
      ORDER BY c.conname
    LOOP
      EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I', tbl, drop_name);
      RAISE NOTICE 'Dropped redundant unique constraint % on %', drop_name, tbl;
    END LOOP;
  END LOOP;
END $$;
