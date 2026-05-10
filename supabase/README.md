# Supabase (GAZE)

This folder holds **SQL migrations** for the GAZE Postgres database (`supabase/migrations/`).

- Migrations are applied in timestamp order (Supabase CLI: `supabase db push`, or SQL Editor for one-offs).
- Migration `20260320180000_drop_redundant_unique_constraints.sql` may already be applied on the linked production project; re-running it is a no-op if only one UNIQUE constraint remains per table.

For a full local CLI workflow, run `supabase init` in the repo root and link your project (`supabase link`) — that generates `config.toml` with your project ref.
