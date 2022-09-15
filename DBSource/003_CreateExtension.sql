
CREATE EXTENSION IF NOT EXISTS plpython3u WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpython3u IS 'Python';

CREATE EXTENSION IF NOT EXISTS pg_repack WITH SCHEMA public;
COMMENT ON EXTENSION pg_repack IS 'Reorganize tables in PostgreSQL databases with minimal locks';

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;
COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';

CREATE EXTENSION IF NOT EXISTS pgstattuple WITH SCHEMA public;
COMMENT ON EXTENSION pgstattuple IS 'show tuple-level statistics';

CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA public;
COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';
