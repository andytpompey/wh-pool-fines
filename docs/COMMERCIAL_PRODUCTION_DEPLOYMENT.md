# Commercial production deployment

Commercial Admin is disabled by default. Set `VITE_COMMERCIAL_ADMIN_ENABLED=true`
only after the target Supabase project completes every gate below.

## Safety gates

1. Record the exact production Supabase project reference and confirm it is not
   the staging project.
2. Create and verify a recoverable production database backup.
3. Run `supabase/audits/commercial_production_readiness.sql` in the target project.
   Save the missing-object output as deployment evidence.
4. Establish a migration baseline before applying migrations. A database without
   `supabase_migrations.schema_migrations` must not receive the complete migration
   folder blindly; reconcile its existing schema first.
5. Rehearse the reconciled migration plan against a restored copy or staging.
6. Apply only canonical migration filenames, in timestamp order. Never apply the
   accidental duplicate files whose names end in ` 2.sql`.
7. Deploy the commercial Edge Functions and configure their production secrets.
   Never copy staging credentials into production.
8. Run the SQL smoke tests for authorization, commercial foundation, operations,
   enforcement, administration, support, incidents, grants, pilots, and usage.
9. Run `supabase/audits/commercial_production_readiness.sql` again. Both arrays must
   be empty.
10. Enable `VITE_COMMERCIAL_ADMIN_ENABLED=true` for production and deploy the web
    app. Verify a platform administrator can load the page without console errors.

## Rollback boundary

If any migration or smoke test fails, leave the web flag disabled. Do not repair
production by pasting individual RPCs: restore the backup or correct and rehearse
the ordered migration plan before retrying.
