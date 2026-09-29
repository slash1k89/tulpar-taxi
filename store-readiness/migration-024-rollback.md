# Migration 024 rollback plan

`20260923_024_store_readiness.sql` is additive: it creates four tables and their
indexes, and does not update existing users, orders, chats, ratings, or rides.

Before production application, create and verify a full PostgreSQL backup. If
the migration transaction itself fails, PostgreSQL rolls it back automatically.
Before the new backend is exposed to users, a manual rollback may drop (in this
order) `content_reports`, `moderation_admins`, `user_blocks`, and
`user_terms_acceptances`.

After the new backend has accepted Terms or moderation data, do not drop these
tables: restore the verified pre-migration backup or deploy a reviewed forward
fix so acceptance history and reports are not silently lost.
