-- Need conditional test for Revoke if rolename doesn't already exist 

DO $$
BEGIN
IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='actionexportersvc') THEN
   REVOKE ALL PRIVILEGES ON DATABASE postgres FROM actionexportersvc;
END IF;
END$$;

DROP SCHEMA IF EXISTS actionexporter CASCADE;
DROP ROLE IF EXISTS actionexportersvc;

CREATE USER actionexportersvc PASSWORD 'actionexportersvc'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION INHERIT LOGIN;

CREATE SCHEMA actionexporter AUTHORIZATION actionexportersvc;

REVOKE ALL ON ALL TABLES IN SCHEMA actionexporter FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA actionexporter FROM PUBLIC;
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;

GRANT CONNECT ON DATABASE postgres TO actionexportersvc;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA actionexporter TO actionexportersvc;
GRANT ALL ON ALL SEQUENCES IN SCHEMA actionexporter TO actionexportersvc;
