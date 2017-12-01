--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.3
-- Dumped by pg_dump version 9.6.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- Name: action; Type: SCHEMA; Schema: -; Owner: actionsvc
--

CREATE SCHEMA action;


ALTER SCHEMA action OWNER TO actionsvc;

--
-- Name: actionexporter; Type: SCHEMA; Schema: -; Owner: actionexportersvc
--

CREATE SCHEMA actionexporter;


ALTER SCHEMA actionexporter OWNER TO actionexportersvc;

--
-- Name: casesvc; Type: SCHEMA; Schema: -; Owner: casesvc
--

CREATE SCHEMA casesvc;


ALTER SCHEMA casesvc OWNER TO casesvc;

--
-- Name: collectionexercise; Type: SCHEMA; Schema: -; Owner: collectionexercisesvc
--

CREATE SCHEMA collectionexercise;


ALTER SCHEMA collectionexercise OWNER TO collectionexercisesvc;

--
-- Name: iac; Type: SCHEMA; Schema: -; Owner: iacsvc
--

CREATE SCHEMA iac;


ALTER SCHEMA iac OWNER TO iacsvc;

--
-- Name: notifygatewaysvc; Type: SCHEMA; Schema: -; Owner: notifygatewaysvc
--

CREATE SCHEMA notifygatewaysvc;


ALTER SCHEMA notifygatewaysvc OWNER TO notifygatewaysvc;

--
-- Name: sample; Type: SCHEMA; Schema: -; Owner: samplesvc
--

CREATE SCHEMA sample;


ALTER SCHEMA sample OWNER TO samplesvc;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- PostgreSQL database dump complete
--

