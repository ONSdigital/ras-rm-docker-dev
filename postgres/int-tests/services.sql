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
-- Name: partysvc; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA partysvc;


ALTER SCHEMA partysvc OWNER TO postgres;

--
-- Name: ras_ci; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ras_ci;


ALTER SCHEMA ras_ci OWNER TO postgres;

--
-- Name: sample; Type: SCHEMA; Schema: -; Owner: samplesvc
--

CREATE SCHEMA sample;


ALTER SCHEMA sample OWNER TO samplesvc;

--
-- Name: survey; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA survey;


ALTER SCHEMA survey OWNER TO postgres;

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


SET search_path = public, pg_catalog;

--
-- Name: businessrespondentstatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE businessrespondentstatus AS ENUM (
    'ACTIVE',
    'INACTIVE',
    'SUSPENDED',
    'ENDED'
);


ALTER TYPE businessrespondentstatus OWNER TO postgres;

--
-- Name: enrolmentstatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE enrolmentstatus AS ENUM (
    'PENDING',
    'ENABLED',
    'DISABLED',
    'SUSPENDED'
);


ALTER TYPE enrolmentstatus OWNER TO postgres;

--
-- Name: kind; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE kind AS ENUM (
    'LEGAL_STATUS',
    'INDUSTRY',
    'SIZE',
    'GEOGRAPHY',
    'COLLECTION_EXERCISE',
    'RU_REF'
);


ALTER TYPE kind OWNER TO postgres;

--
-- Name: respondentstatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE respondentstatus AS ENUM (
    'CREATED',
    'ACTIVE',
    'SUSPENDED'
);


ALTER TYPE respondentstatus OWNER TO postgres;

--
-- Name: status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE status AS ENUM (
    'uploading',
    'pending',
    'active'
);


ALTER TYPE status OWNER TO postgres;

SET search_path = action, pg_catalog;

--
-- Name: createactions(integer); Type: FUNCTION; Schema: action; Owner: actionsvc
--

CREATE FUNCTION createactions(p_actionplanjobpk integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

DECLARE
v_text             text;
v_plan_name        text;
v_plan_description text;
v_errmess          text;
v_actionplanid     integer;
v_currentdatetime  timestamp;
v_number_of_rows   integer;

BEGIN

   SELECT j.actionplanFK FROM action.actionplanjob j WHERE j.actionplanjobPK = p_actionplanjobPK INTO v_actionplanid;

   v_currentdatetime := current_timestamp;
   --v_currentdatetime := '2016-09-09 01:00:01+01'; -- for testing


   v_number_of_rows := 0;

   -- Look at the case table to see if any cases are due to run for the actionplan passed in
   -- start date before or equal current date
   -- end date after or equal current date
   -- rules found, for plan passed in, due as days offset is less than or equal to days passed since start date (current date minus start date)
   IF EXISTS (SELECT 1
              FROM action.case c, action.actionrule r
              WHERE c.actionplanstartdate <= v_currentdatetime AND c.actionplanenddate >= v_currentdatetime
              AND r.daysoffset <= EXTRACT(DAY FROM (v_currentdatetime - c.actionplanstartdate))
              AND c.actionplanFk = v_actionplanid
              AND r.actionplanFK = c.actionplanFK) THEN

       -- Get plan description for messagelog using the actionplan passed in
      SELECT p.name, p.description
      FROM action.actionplan p
      WHERE p.actionplanPK = v_actionplanid INTO v_plan_name,v_plan_description;

      -- Collection Exercise start date reached, Run the rules due
      INSERT INTO action.action
        (
         id
        ,actionPK
        ,caseId
        ,caseFK
        ,actionplanFK
        ,actionruleFK
        ,actiontypeFK
        ,createdby
        ,manuallycreated
        ,situation
        ,stateFK
        ,createddatetime
        ,updateddatetime
        )
      SELECT
         gen_random_uuid()
        ,nextval('action.actionPKseq')
        ,l.id
        ,l.casePK
        ,l.actionplanFk
        ,l.actionrulePK
        ,l.actiontypeFK
        ,'SYSTEM'
        ,FALSE
        ,NULL
        ,'SUBMITTED'
        ,v_currentdatetime
        ,v_currentdatetime
       FROM
        (SELECT c.id
               ,c.casePK
               ,r.actionplanFK
               ,r.actionrulePK
               ,r.actiontypeFK
         FROM action.actionrule r
              ,action.case c
         WHERE  c.actionplanFk = v_actionplanid
         AND    r.actionplanFk = c.actionplanFK
         AND r.daysoffset <= EXTRACT(DAY FROM (v_currentdatetime - c.actionplanstartdate)) -- looking at start date to see if the rule is due
         AND c.actionplanstartdate <= v_currentdatetime AND c.actionplanenddate >= v_currentdatetime -- start date before or equal current date AND end date after or equal current date
         EXCEPT
         SELECT a.caseId
               ,a.caseFK
               ,a.actionplanFK
               ,a.actionruleFK
               ,a.actiontypeFK
         FROM action.action a
         WHERE a.actionplanFk = v_actionplanid) l;

      GET DIAGNOSTICS v_number_of_rows = ROW_COUNT; -- number of actions inserted

     IF v_number_of_rows > 0 THEN
         v_text := v_number_of_rows  || ' ACTIONS CREATED: ' || v_plan_description || ' (PLAN NAME: ' || v_plan_name || ') (PLAN ID: ' || v_actionplanid || ')';
         PERFORM action.logmessage(p_messagetext := v_text
                                  ,p_jobid := p_actionplanjobPK
                                  ,p_messagelevel := 'INFO'
                                  ,p_functionname := 'action.createactions');
      END IF;
   END IF;

   -- Update the date the actionplan was run on the actionplan table
   UPDATE action.actionplan
   SET lastrundatetime = v_currentdatetime
   WHERE actionplanPK  = v_actionplanid;

   -- Update the date the actionplan was run on the actionplanjob table
   UPDATE action.actionplanjob
   SET updateddatetime = v_currentdatetime
      ,stateFK = 'COMPLETED'
   WHERE actionplanjobPK =  p_actionplanjobPK
   AND   actionplanFK    =  v_actionplanid;

RETURN TRUE;

EXCEPTION

WHEN OTHERS THEN
    v_errmess := SQLSTATE;
    PERFORM action.logmessage(p_messagetext := 'CREATE ACTION(S) EXCEPTION TRIGGERED SQLERRM: ' || SQLERRM || ' SQLSTATE : ' || v_errmess
                             ,p_jobid := p_actionplanjobPK
                             ,p_messagelevel := 'FATAL'
                             ,p_functionname := 'action.createactions');
  RETURN FALSE;
END;

$$;


ALTER FUNCTION action.createactions(p_actionplanjobpk integer) OWNER TO actionsvc;

--
-- Name: generate_action_mi(); Type: FUNCTION; Schema: action; Owner: actionsvc
--

CREATE FUNCTION generate_action_mi() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

v_contents      text;
r_dataline      record;
v_rows          integer;

BEGIN
    
    PERFORM action.logmessage(p_messagetext := 'GENERATING ACTION MI REPORT'
                              ,p_jobid := 0
                              ,p_messagelevel := 'INFO'
                              ,p_functionname := 'action.generate_action_mi');  
    
       v_rows     := 0;
       v_contents := '';
       v_contents := 'Action Plan No,Action Plan Name,Action Type,Action Plan Start Date,Days Offset,Handler,Count,State';

-- Action State Report

       FOR r_dataline IN (SELECT  template.actionplan                       AS actionplan
                                , template.plan_description                 AS action_plan_name
                                , template.type_description                 AS action_type
                                , action_case_cnt.actionplanstartdate::date AS action_plan_startdate      
                                , template.daysoffset                       AS daysoffset
                                , template.handler                          AS handler
                                , COALESCE(action_case_cnt.cnt,0) AS cnt
                                , action_case_cnt.actionstate     AS action_state     
                          FROM (SELECT COALESCE(cases.actionplanFK,actions.actionplanFK) AS  actionplan
                                     , cases.actionplanstartdate
                                     , actions.createddatetime
                                     , COALESCE(cases.actionrulePK,actions.actionruleFK) AS actionrule
                                     , COALESCE(cases.actiontypeFK,actions.actiontypeFK) AS actiontype
                                     , actions.stateFK                                   AS actionstate
                                     , COUNT(*) cnt
                                FROM (SELECT  c.actionplanFK
                                            , c.actionplanstartdate::DATE
                                            , c.casePK
                                            , r.actionrulePK
                                            , r.actiontypeFK
                                      FROM  action.case c
                                          , action.actionrule r
                                      WHERE c.actionplanFK = r.actionplanFK) cases
                                      FULL JOIN (SELECT a.actionplanFK
                                                      , a.createddatetime::DATE
                                                      , a.caseFK
                                                      , a.actionruleFK
                                                      , a.actiontypeFK
                                                      , a.stateFK
                                                 FROM action.action a) actions
                                      ON (actions.actionplanFK = cases.actionplanFK 
                                      AND actions.actionruleFK = cases.actionrulePK
                                      AND actions.actiontypeFK = cases.actiontypeFK
                                      AND actions.caseFK       = cases.casePK) 
                              GROUP BY actionplan, actionplanstartdate, actionrule, actiontype, actionstate, createddatetime) action_case_cnt 
                              FULL JOIN (SELECT  r.actionplanFK AS actionplan
                                               , r.actionrulePK AS actionrule
                                               , r.actiontypeFK AS actiontype
                                               , p.description  AS plan_description
                                               , t.description  AS type_description
                                               , r.daysoffset  
                                               , t.handler    
                                         FROM   action.actionplan p
                                              , action.actionrule r
                                              , action.actiontype t
                                         WHERE p.actionplanPK = r.actionplanFK 
                                         AND   r.actiontypeFK = t.actiontypePK) template
                                         ON (template.actionplan = action_case_cnt.actionplan 
                                         AND template.actiontype = action_case_cnt.actiontype
                                         AND template.actionrule = action_case_cnt.actionrule)
                                         ORDER BY template.actionplan,template.daysoffset,template.plan_description,action_plan_startdate) LOOP

                           v_contents := v_contents                         || CHR(10) 
                           || r_dataline.actionplan                         || ','
                           || r_dataline.action_plan_name                   || ','
                           || r_dataline.action_type                        || ','
                           || COALESCE(r_dataline.action_plan_startdate::text,'') || ','
                           || r_dataline.daysoffset                         || ','
                           || r_dataline.handler                            || ','
                           || r_dataline.cnt                                || ','
                           || COALESCE(r_dataline.action_state,'') ;   
             v_rows := v_rows+1;  
       END LOOP;       

       -- Insert the data into the report table
       INSERT INTO action.report (id, reportPK,reporttypeFK,contents, createddatetime) VALUES(gen_random_uuid(), nextval('action.reportPKseq'), 'ACTIONS', v_contents, CURRENT_TIMESTAMP); 

               
       PERFORM action.logmessage(p_messagetext := 'GENERATING ACTIONS MI REPORT COMPLETED ROWS WRIITEN = ' || v_rows
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'action.generate_action_mi'); 
      
    
       PERFORM action.logmessage(p_messagetext := 'ACTIONS MI REPORT GENERATED'
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'action.generate_action_mi');
      
  RETURN TRUE;

  EXCEPTION
  WHEN OTHERS THEN   
     PERFORM action.logmessage(p_messagetext := 'GENERATE REPORTS EXCEPTION TRIGGERED SQLERRM: ' || SQLERRM || ' SQLSTATE : ' || SQLSTATE
                               ,p_jobid := 0
                               ,p_messagelevel := 'FATAL'
                               ,p_functionname := 'action.generate_action_mi');
                               
  RETURN FALSE;
END;
$$;


ALTER FUNCTION action.generate_action_mi() OWNER TO actionsvc;

--
-- Name: logmessage(text, numeric, text, text); Type: FUNCTION; Schema: action; Owner: actionsvc
--

CREATE FUNCTION logmessage(p_messagetext text DEFAULT NULL::text, p_jobid numeric DEFAULT NULL::numeric, p_messagelevel text DEFAULT NULL::text, p_functionname text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
v_text TEXT ;
v_function TEXT;
BEGIN
INSERT INTO action.messagelog
(messagetext, jobid, messagelevel, functionname, createddatetime )
values (p_messagetext, p_jobid, p_messagelevel, p_functionname, current_timestamp);
  RETURN TRUE;
EXCEPTION
WHEN OTHERS THEN
RETURN FALSE;
END;
$$;


ALTER FUNCTION action.logmessage(p_messagetext text, p_jobid numeric, p_messagelevel text, p_functionname text) OWNER TO actionsvc;

SET search_path = actionexporter, pg_catalog;

--
-- Name: generate_print_volumes_mi(); Type: FUNCTION; Schema: actionexporter; Owner: actionexportersvc
--

CREATE FUNCTION generate_print_volumes_mi() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

v_contents      text;
r_dataline      record;
v_rows          integer;

BEGIN
    
    PERFORM actionexporter.logmessage(p_messagetext := 'GENERATING PRINT VOLUMES MI REPORT'
                              ,p_jobid := 0
                              ,p_messagelevel := 'INFO'
                              ,p_functionname := 'actionexporter.generate_print_volumes_mi');  
    
       v_rows := 0;
       v_contents    := '';
       v_contents    := 'filename,rowcount,datesent,success'; -- Set header line    

       FOR r_dataline IN (SELECT * FROM actionexporter.filerowcount f WHERE NOT f.reported) LOOP
             v_contents := v_contents || chr(10) || r_dataline.filename || ',' || r_dataline.rowcount || ',' || r_dataline.datesent || ',' || r_dataline.sendresult;                                     
             v_rows := v_rows+1;  
             UPDATE actionexporter.filerowcount   
             SET reported = TRUE;
       END LOOP;       

       IF v_rows > 0 THEN  
          -- Insert the data into the report table
          INSERT INTO actionexporter.report(id, reportPK,reporttypeFK,contents, createddatetime) VALUES(gen_random_uuid(), nextval('actionexporter.reportPKseq'), 'PRINT_VOLUMES', v_contents, CURRENT_TIMESTAMP); 
       END IF;

       PERFORM actionexporter.logmessage(p_messagetext := 'GENERATING PRINT VOLUMES MI REPORT COMPLETED ROWS WRIITEN = ' || v_rows
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'actionexporter.generate_print_volumes_mi'); 
      
    
       PERFORM actionexporter.logmessage(p_messagetext := 'PRINT VOLUMES MI REPORT GENERATED'
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'actionexporter.generate_print_volumes_mi'); 
  RETURN TRUE;

  EXCEPTION
  WHEN OTHERS THEN   
     PERFORM actionexporter.logmessage(p_messagetext := 'GENERATE PRINT VOLUMES MI REPORT EXCEPTION TRIGGERED SQLERRM: ' || 

SQLERRM || ' SQLSTATE : ' || SQLSTATE
                               ,p_jobid := 0
                               ,p_messagelevel := 'FATAL'
                               ,p_functionname := 'actionexporter.generate_print_volumes_mi');
                               
  RETURN FALSE;
END;
$$;


ALTER FUNCTION actionexporter.generate_print_volumes_mi() OWNER TO actionexportersvc;

--
-- Name: logmessage(text, numeric, text, text); Type: FUNCTION; Schema: actionexporter; Owner: actionexportersvc
--

CREATE FUNCTION logmessage(p_messagetext text DEFAULT NULL::text, p_jobid numeric DEFAULT NULL::numeric, p_messagelevel text DEFAULT NULL::text, p_functionname text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
v_text TEXT ;
v_function TEXT;
BEGIN

INSERT INTO actionexporter.messagelog (messagetext, jobid, messagelevel, functionname, createddatetime )
VALUES (p_messagetext, p_jobid, p_messagelevel, p_functionname, current_timestamp);

  RETURN TRUE;
EXCEPTION
WHEN OTHERS THEN
RETURN FALSE;
END;
$$;


ALTER FUNCTION actionexporter.logmessage(p_messagetext text, p_jobid numeric, p_messagelevel text, p_functionname text) OWNER TO actionexportersvc;

SET search_path = casesvc, pg_catalog;

--
-- Name: generate_case_events_report(); Type: FUNCTION; Schema: casesvc; Owner: casesvc
--

CREATE FUNCTION generate_case_events_report() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE

v_contents      text;
r_dataline      record;
v_rows          integer;

BEGIN
   
   PERFORM casesvc.logmessage(p_messagetext := 'GENERATING CASE EVENTS REPORT'
                             ,p_jobid := 0
                             ,p_messagelevel := 'INFO'
                             ,p_functionname := 'casesvc.generate_case_events_report');  
   
      v_rows := 0;
      v_contents    := '';
      v_contents    := 'Sample Unit Ref,Sample Unit Type,Case Ref,Case Created,Action Created,Action Completed,Respondent Account Created,Respondent Enrolled,Access Code Authentication Attempt,Collection Instrument Downloaded,Unsuccessful Response Upload,Successful Response Upload,Offline Response Processed'; -- Set header line    

      FOR r_dataline IN (SELECT
  events.sampleunitref 
, events.sampleunittype
, events.caseref
, events.case_created
, events.action_created
--, events.action_cancellation_created
--, events.action_cancellation_completed
, events.action_completed
--, events.action_updated     
, events.respondent_account_created                                                                                           
, events.respondent_enroled         
, events.access_code_authentication_attempt_ind 
, events.collection_instrument_downloaded_ind 
, events.unsuccessful_response_upload_ind  
, events.successful_response_upload_ind 
, events.offline_response_processed_ind   
  
FROM 
(SELECT 
    cg.sampleunitref
  , c.sampleunittype 
  , c.caseref
  -- response chasing categories
  , MAX(CASE WHEN ce.categoryFK = 'ACCESS_CODE_AUTHENTICATION_ATTEMPT'  THEN 1 ELSE  0 END) access_code_authentication_attempt_ind 	--(B)  -- count distinct event
  , SUM(CASE WHEN ce.categoryFK = 'RESPONDENT_ACCOUNT_CREATED' 		THEN 1 ELSE  0 END) respondent_account_created 			--(B)  -- count all events
  , SUM(CASE WHEN ce.categoryFK = 'RESPONDENT_ENROLED' 			THEN 1 ELSE  0 END) respondent_enroled 				--(B)  -- count all events
  , MAX(CASE WHEN ce.categoryFK = 'COLLECTION_INSTRUMENT_DOWNLOADED'    THEN 1 ELSE  0 END) collection_instrument_downloaded_ind	--(BI) -- count distinct event
  , MAX(CASE WHEN ce.categoryFK = 'SUCCESSFUL_RESPONSE_UPLOAD' 		THEN 1 ELSE  0 END) successful_response_upload_ind		--(BI) -- count distinct event
  -- remaining categories
  , SUM(CASE WHEN ce.categoryFK = 'CASE_CREATED'                        THEN 1 ELSE  0 END) case_created 				--(B,BI) -- count all event
  , SUM(CASE WHEN ce.categoryFK = 'ACTION_CREATED'                      THEN 1 ELSE  0 END) action_created  				--(B,BI) -- count all events
  , SUM(CASE WHEN ce.categoryFK = 'ACTION_CANCELLATION_COMPLETED' 	THEN 1 ELSE  0 END) action_cancellation_completed 		--(B,BI) -- count all events
  , SUM(CASE WHEN ce.categoryFK = 'ACTION_CANCELLATION_CREATED' 	THEN 1 ELSE  0 END) action_cancellation_created 		--(B,BI) -- count all events
  , SUM(CASE WHEN ce.categoryFK = 'ACTION_COMPLETED' 			THEN 1 ELSE  0 END) action_completed 				--(B,BI) -- count all events
  , SUM(CASE WHEN ce.categoryFK = 'ACTION_UPDATED' 			THEN 1 ELSE  0 END) action_updated 				--(B,BI) -- count all events  
  , MAX(CASE WHEN ce.categoryFK = 'OFFLINE_RESPONSE_PROCESSED' 		THEN 1 ELSE  0 END) offline_response_processed_ind		--(BI)	 -- count distinct event
  , MAX(CASE WHEN ce.categoryFK = 'UNSUCCESSFUL_RESPONSE_UPLOAD' 	THEN 1 ELSE  0 END) unsuccessful_response_upload_ind 		--(BI)   -- count distinct event   
FROM   casesvc.caseevent ce
RIGHT OUTER JOIN casesvc.case c  ON c.casePK = ce.caseFK 
INNER JOIN casesvc.casegroup cg  ON c.casegroupFK = cg.casegroupPK
GROUP BY cg.sampleunitref
       , c.sampleunittype
       , c.casePK) events
ORDER BY events.sampleunitref
       , events.sampleunittype
       , events.caseref) LOOP
            v_contents := v_contents || chr(10) || r_dataline.sampleunitref || ',' || r_dataline.sampleunittype || ',' 
            || r_dataline.caseref || ',' 
            || r_dataline.case_created ||',' 
            || r_dataline.action_created ||',' 
            || r_dataline.action_completed ||',' 
            || r_dataline.respondent_account_created ||',' 
            || r_dataline.respondent_enroled ||',' 
            || r_dataline.access_code_authentication_attempt_ind ||',' 
            || r_dataline.collection_instrument_downloaded_ind ||',' 
            || r_dataline.unsuccessful_response_upload_ind ||',' 
            || r_dataline.successful_response_upload_ind ||',' 
            || r_dataline.offline_response_processed_ind ;                                    
            v_rows := v_rows+1;  
      END LOOP;      

      IF v_rows > 0 THEN  
         -- Insert the data into the report table
         INSERT INTO casesvc.report(id, reportPK,reporttypeFK,contents, createddatetime) VALUES(gen_random_uuid(), nextval('casesvc.reportPKseq'), 'CASE_EVENTS', v_contents, CURRENT_TIMESTAMP);
      END IF;

      PERFORM casesvc.logmessage(p_messagetext := 'GENERATING CASE EVENTS REPORT COMPLETED ROWS WRIITEN = ' || v_rows
                                       ,p_jobid := 0
                                       ,p_messagelevel := 'INFO'
                                       ,p_functionname := 'casesvc.generate_case_events_report');
     
   
      PERFORM casesvc.logmessage(p_messagetext := 'CASE EVENTS REPORT GENERATED'
                                       ,p_jobid := 0
                                       ,p_messagelevel := 'INFO'
                                       ,p_functionname := 'casesvc.generate_case_events_report');
 RETURN TRUE;

 EXCEPTION
 WHEN OTHERS THEN  
    PERFORM casesvc.logmessage(p_messagetext := 'GENERATING CASE EVENTS REPORT EXCEPTION TRIGGERED SQLERRM: ' ||

SQLERRM || ' SQLSTATE : ' || SQLSTATE
                              ,p_jobid := 0
                              ,p_messagelevel := 'FATAL'
                              ,p_functionname := 'casesvc.generate_case_events_report');
                             
 RETURN FALSE;
END;
$$;


ALTER FUNCTION casesvc.generate_case_events_report() OWNER TO casesvc;

--
-- Name: generate_response_chasing_report(); Type: FUNCTION; Schema: casesvc; Owner: casesvc
--

CREATE FUNCTION generate_response_chasing_report() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE

	v_contents      text;
	r_dataline      record;
	v_rows          integer;

	BEGIN
   
	   PERFORM casesvc.logmessage(p_messagetext := 'GENERATING RESPONSE CHASING REPORT'
	                             ,p_jobid := 0
	                             ,p_messagelevel := 'INFO'
	                             ,p_functionname := 'casesvc.generate_response_chasing_report');  
   
	      v_rows := 0;
	      v_contents    := '';
	      v_contents    := 'Sample Unit Ref,Sample Unit Type,Case Ref,Authentication Attempt No Account Created,Account Created No Enrolment,Collection Instrument Downloaded No Successful Response Upload';   

	      FOR r_dataline IN (SELECT
	  events.sampleunitref
	, events.sampleunittype
	, events.caseref  
	, CASE WHEN events.access_code_authentication_attempt_ind = 1  AND events.respondent_account_created 	 = 0 THEN 1 ELSE 0 END  authentication_attempt_no_account_created  --(B) 
	, (events.respondent_account_created - events.respondent_enroled) account_created_no_enrolment  --(B)  
	, CASE WHEN events.collection_instrument_downloaded_ind   = 1  AND events.successful_response_upload_ind = 0 THEN 1 ELSE 0 END  collection_instrument_downloaded_no_successful_upload --(BI)
	FROM 
	(SELECT 
	    cg.sampleunitref
	  , c.sampleunittype 
	  , c.caseref
	  , MAX(CASE WHEN ce.categoryFK = 'ACCESS_CODE_AUTHENTICATION_ATTEMPT'  THEN 1 ELSE  0 END) access_code_authentication_attempt_ind --(B)  -- count distinct event
	  , SUM(CASE WHEN ce.categoryFK = 'RESPONDENT_ACCOUNT_CREATED' 		THEN 1 ELSE  0 END) respondent_account_created 		   --(B)  -- count all events
	  , SUM(CASE WHEN ce.categoryFK = 'RESPONDENT_ENROLED' 			THEN 1 ELSE  0 END) respondent_enroled 			   --(B)  -- count all events
	  , MAX(CASE WHEN ce.categoryFK = 'COLLECTION_INSTRUMENT_DOWNLOADED'    THEN 1 ELSE  0 END) collection_instrument_downloaded_ind   --(BI) -- count distinct event
	  , MAX(CASE WHEN ce.categoryFK = 'SUCCESSFUL_RESPONSE_UPLOAD' 		THEN 1 ELSE  0 END) successful_response_upload_ind	   --(BI) -- count distinct event 
	FROM casesvc.caseevent ce
	RIGHT OUTER JOIN casesvc.case c  ON c.casePK      = ce.caseFK 
	INNER JOIN casesvc.casegroup cg  ON c.casegroupFK = cg.casegroupPK
	WHERE ce.categoryFK = ANY (ARRAY['ACCESS_CODE_AUTHENTICATION_ATTEMPT','RESPONDENT_ACCOUNT_CREATED','RESPONDENT_ENROLED','COLLECTION_INSTRUMENT_DOWNLOADED','SUCCESSFUL_RESPONSE_UPLOAD'])
	GROUP BY cg.sampleunitref
	       , c.sampleunittype
	       , c.casePK) events
	WHERE (events.access_code_authentication_attempt_ind = 1  AND events.respondent_account_created     = 0)
	OR    (events.collection_instrument_downloaded_ind   = 1  AND events.successful_response_upload_ind = 0)
	OR    (events.respondent_account_created > events.respondent_enroled)
	ORDER BY events.sampleunitref
	       , events.sampleunittype
	       , events.caseref) LOOP
	            v_contents := v_contents || chr(10) || r_dataline.sampleunitref || ',' || r_dataline.sampleunittype || ',' 
	            || r_dataline.caseref || ',' 
	            || r_dataline.authentication_attempt_no_account_created ||',' 
	            || r_dataline.account_created_no_enrolment ||',' 
	            || r_dataline.collection_instrument_downloaded_no_successful_upload ;                                    
	            v_rows := v_rows+1;  
	      END LOOP;      

	      IF v_rows > 0 THEN  
	         -- Insert the data into the report table
	         INSERT INTO casesvc.report(id, reportPK,reporttypeFK,contents, createddatetime) VALUES(gen_random_uuid(), nextval('casesvc.reportPKseq'), 'RESPONSE_CHASING', v_contents, CURRENT_TIMESTAMP);
	      END IF;

	      PERFORM casesvc.logmessage(p_messagetext := 'GENERATING RESPONSE CHASING REPORT COMPLETED ROWS WRIITEN = ' || v_rows
	                                       ,p_jobid := 0
	                                       ,p_messagelevel := 'INFO'
	                                       ,p_functionname := 'casesvc.generate_response_chasing_report');
     
   
	      PERFORM casesvc.logmessage(p_messagetext := 'RESPONSE CHASING REPORT GENERATED'
	                                       ,p_jobid := 0
	                                       ,p_messagelevel := 'INFO'
	                                       ,p_functionname := 'casesvc.generate_response_chasing_report');
	 RETURN TRUE;

	 EXCEPTION
	 WHEN OTHERS THEN  
	    PERFORM casesvc.logmessage(p_messagetext := 'GENERATING RESPONSE CHASING REPORT EXCEPTION TRIGGERED SQLERRM: ' ||

	SQLERRM || ' SQLSTATE : ' || SQLSTATE
	                              ,p_jobid := 0
	                              ,p_messagelevel := 'FATAL'
	                              ,p_functionname := 'casesvc.generate_response_chasing_report');
                             
	 RETURN FALSE;
	END;
	$$;


ALTER FUNCTION casesvc.generate_response_chasing_report() OWNER TO casesvc;

--
-- Name: logmessage(text, numeric, text, text); Type: FUNCTION; Schema: casesvc; Owner: casesvc
--

CREATE FUNCTION logmessage(p_messagetext text DEFAULT NULL::text, p_jobid numeric DEFAULT NULL::numeric, p_messagelevel text DEFAULT NULL::text, p_functionname text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
v_text TEXT ;
v_function TEXT;
BEGIN

INSERT INTO casesvc.messagelog (messagetext, jobid, messagelevel, functionname, createddatetime )
VALUES (p_messagetext, p_jobid, p_messagelevel, p_functionname, current_timestamp);

  RETURN TRUE;
EXCEPTION
WHEN OTHERS THEN
RETURN FALSE;
END;
$$;


ALTER FUNCTION casesvc.logmessage(p_messagetext text, p_jobid numeric, p_messagelevel text, p_functionname text) OWNER TO casesvc;

SET search_path = collectionexercise, pg_catalog;

--
-- Name: generate_collectionexercise_mi(); Type: FUNCTION; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE FUNCTION generate_collectionexercise_mi() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

v_contents      text;
r_dataline      record;
v_rows          integer;

BEGIN
    
    PERFORM collectionexercise.logmessage(p_messagetext := 'GENERATING COLLECTION EXERCISE MI REPORT'
                              ,p_jobid := 0
                              ,p_messagelevel := 'INFO'
                              ,p_functionname := 'collectionexercise.generate_collectionexercise_mi');  
    
       v_rows     := 0;
       v_contents := '';
       v_contents := 'CE Name,Scheduled Start DateTime,Scheduled Execution DateTime,Scheduled Return DateTime,Scheduled End DateTime,Period Start DateTime,Period End DateTime,Actual Execution DateTime,Actual Publish DateTime,Executed By,State,Sample Size';

-- collectionexercise Report

       FOR r_dataline IN (SELECT  c.name
                                , c.scheduledstartdatetime
                                , c.scheduledexecutiondatetime
                                , c.scheduledreturndatetime
                                , c.scheduledenddatetime
                                , c.periodstartdatetime
                                , c.periodenddatetime
                                , c.actualexecutiondatetime
                                , c.actualpublishdatetime
                                , c.executedby
                                , c.stateFK
                                , c.samplesize 
                          FROM collectionexercise.collectionexercise c) LOOP

                                v_contents := v_contents                                    || chr(10) 
                                || r_dataline.name                                          || ','
                                || COALESCE(r_dataline.scheduledstartdatetime::text,'')     || ','
                                || COALESCE(r_dataline.scheduledexecutiondatetime::text,'') || ','
                                || COALESCE(r_dataline.scheduledreturndatetime::text,'')    || ','
                                || COALESCE(r_dataline.scheduledenddatetime::text,'')       || ','
                                || COALESCE(r_dataline.periodstartdatetime::text,'')        || ','
                                || COALESCE(r_dataline.periodenddatetime::text,'')          || ','
                                || COALESCE(r_dataline.actualexecutiondatetime::text,'')    || ','
                                || COALESCE(r_dataline.actualpublishdatetime ::text,'')     || ','
                                || COALESCE(r_dataline.executedby::text,'')                 || ','
                                || COALESCE(r_dataline.stateFK::text,'')                    || ','
                                || COALESCE(r_dataline.samplesize::text,'');
                              
             v_rows := v_rows+1;  
       END LOOP;       

       -- Insert the data into the report table
       INSERT INTO collectionexercise.report (id, reportPK,reporttypeFK,contents, createddatetime) VALUES(gen_random_uuid(), nextval('collectionexercise.reportPKseq'), 'COLLECTIONEXERCISE', v_contents, CURRENT_TIMESTAMP); 

 
       PERFORM collectionexercise.logmessage(p_messagetext := 'GENERATING COLLECTION EXERCISE MI REPORT COMPLETED ROWS WRIITEN = ' || v_rows
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'collectionexercise.generate_collectionexercise_mi'); 
      
    
       PERFORM collectionexercise.logmessage(p_messagetext := 'COLLECTION EXERCISE MI REPORT GENERATED'
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'collectionexercise.generate_collectionexercise_mi');
  
  RETURN TRUE;

  EXCEPTION
  WHEN OTHERS THEN   
     PERFORM collectionexercise.logmessage(p_messagetext := 'GENERATE REPORTS EXCEPTION TRIGGERED SQLERRM: ' || SQLERRM || ' SQLSTATE : ' || SQLSTATE
                               ,p_jobid := 0
                               ,p_messagelevel := 'FATAL'
                               ,p_functionname := 'collectionexercise.generate_collectionexercise_mi');
                               
  RETURN FALSE;
END;
$$;


ALTER FUNCTION collectionexercise.generate_collectionexercise_mi() OWNER TO collectionexercisesvc;

--
-- Name: logmessage(text, numeric, text, text); Type: FUNCTION; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE FUNCTION logmessage(p_messagetext text DEFAULT NULL::text, p_jobid numeric DEFAULT NULL::numeric, p_messagelevel text DEFAULT NULL::text, p_functionname text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
v_text TEXT ;
v_function TEXT;
BEGIN
INSERT INTO collectionexercise.messagelog
(messagetext, jobid, messagelevel, functionname, createddatetime )
values (p_messagetext, p_jobid, p_messagelevel, p_functionname, current_timestamp);
  RETURN TRUE;
EXCEPTION
WHEN OTHERS THEN
RETURN FALSE;
END;
$$;


ALTER FUNCTION collectionexercise.logmessage(p_messagetext text, p_jobid numeric, p_messagelevel text, p_functionname text) OWNER TO collectionexercisesvc;

SET search_path = sample, pg_catalog;

--
-- Name: generate_sample_mi(); Type: FUNCTION; Schema: sample; Owner: samplesvc
--

CREATE FUNCTION generate_sample_mi() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE

v_contents      text;
r_dataline      record;
v_rows          integer;

BEGIN
    
    PERFORM sample.logmessage(p_messagetext := 'GENERATING SAMPLE MI REPORTS'
                              ,p_jobid := 0
                              ,p_messagelevel := 'INFO'
                              ,p_functionname := 'sample.generate_sample_mi');  
    
       v_rows     := 0;
       v_contents := '';
       v_contents := 'Sample Unit Ref,Form Type';

-- sample Report

       FOR r_dataline IN (SELECT  s.sampleunitref, s.formtype FROM sample.sampleunit s ORDER BY s.sampleunitref) LOOP

                           v_contents := v_contents     || chr(10) 
                           || r_dataline.sampleunitref  || ','
                           || r_dataline.formtype  ;   
             v_rows := v_rows+1;  
       END LOOP;       

       -- Insert the data into the report table
       INSERT INTO sample.report (id, reportPK,reporttypeFK,contents, createddatetime) VALUES(gen_random_uuid(), nextval('sample.reportPKseq'), 'SAMPLE', v_contents, CURRENT_TIMESTAMP); 

               
       PERFORM sample.logmessage(p_messagetext := 'GENERATING SAMPLE MI REPORT COMPLETED ROWS WRIITEN = ' || v_rows
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'sample.generate_sample_mi'); 
      
    
       PERFORM sample.logmessage(p_messagetext := 'SAMPLE MI REPORT GENERATED'
                                        ,p_jobid := 0
                                        ,p_messagelevel := 'INFO'
                                        ,p_functionname := 'sample.generate_sample_mi');
  
  RETURN TRUE;

  EXCEPTION
  WHEN OTHERS THEN   
     PERFORM sample.logmessage(p_messagetext := 'GENERATE REPORTS EXCEPTION TRIGGERED SQLERRM: ' || SQLERRM || ' SQLSTATE : ' || SQLSTATE
                               ,p_jobid := 0
                               ,p_messagelevel := 'FATAL'
                               ,p_functionname := 'sample.generate_sample_mi');
                               
  RETURN FALSE;
END;
$$;


ALTER FUNCTION sample.generate_sample_mi() OWNER TO samplesvc;

--
-- Name: logmessage(text, numeric, text, text); Type: FUNCTION; Schema: sample; Owner: samplesvc
--

CREATE FUNCTION logmessage(p_messagetext text DEFAULT NULL::text, p_jobid numeric DEFAULT NULL::numeric, p_messagelevel text DEFAULT NULL::text, p_functionname text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
v_text TEXT ;
v_function TEXT;
BEGIN
INSERT INTO sample.messagelog
(messagetext, jobid, messagelevel, functionname, createddatetime )
values (p_messagetext, p_jobid, p_messagelevel, p_functionname, current_timestamp);
  RETURN TRUE;
EXCEPTION
WHEN OTHERS THEN
RETURN FALSE;
END;
$$;


ALTER FUNCTION sample.logmessage(p_messagetext text, p_jobid numeric, p_messagelevel text, p_functionname text) OWNER TO samplesvc;

SET search_path = action, pg_catalog;

--
-- Name: actionpkseq; Type: SEQUENCE; Schema: action; Owner: actionsvc
--

CREATE SEQUENCE actionpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE actionpkseq OWNER TO actionsvc;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: action; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE action (
    id uuid NOT NULL,
    actionpk bigint DEFAULT nextval('actionpkseq'::regclass) NOT NULL,
    caseid uuid NOT NULL,
    casefk bigint NOT NULL,
    actionplanfk integer,
    actionrulefk integer,
    actiontypefk integer NOT NULL,
    createdby character varying(50) NOT NULL,
    manuallycreated boolean NOT NULL,
    priority integer DEFAULT 3,
    situation character varying(100),
    statefk character varying(20) NOT NULL,
    createddatetime timestamp with time zone NOT NULL,
    updateddatetime timestamp with time zone,
    optlockversion integer DEFAULT 0
);


ALTER TABLE action OWNER TO actionsvc;

--
-- Name: COLUMN action.priority; Type: COMMENT; Schema: action; Owner: actionsvc
--

COMMENT ON COLUMN action.priority IS '1 = highest, 5 = lowest';


--
-- Name: actionplan; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE actionplan (
    id uuid NOT NULL,
    actionplanpk integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(250) NOT NULL,
    createdby character varying(20) NOT NULL,
    lastrundatetime timestamp with time zone
);


ALTER TABLE actionplan OWNER TO actionsvc;

--
-- Name: actionplanjobseq; Type: SEQUENCE; Schema: action; Owner: actionsvc
--

CREATE SEQUENCE actionplanjobseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE actionplanjobseq OWNER TO actionsvc;

--
-- Name: actionplanjob; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE actionplanjob (
    id uuid NOT NULL,
    actionplanjobpk integer DEFAULT nextval('actionplanjobseq'::regclass) NOT NULL,
    actionplanfk integer NOT NULL,
    createdby character varying(20) NOT NULL,
    statefk character varying(20) NOT NULL,
    createddatetime timestamp with time zone NOT NULL,
    updateddatetime timestamp with time zone
);


ALTER TABLE actionplanjob OWNER TO actionsvc;

--
-- Name: actionplanjobstate; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE actionplanjobstate (
    statepk character varying(20) NOT NULL
);


ALTER TABLE actionplanjobstate OWNER TO actionsvc;

--
-- Name: actionrule; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE actionrule (
    actionrulepk integer NOT NULL,
    actionplanfk integer NOT NULL,
    actiontypefk integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(250) NOT NULL,
    daysoffset integer NOT NULL,
    priority integer DEFAULT 3
);


ALTER TABLE actionrule OWNER TO actionsvc;

--
-- Name: COLUMN actionrule.priority; Type: COMMENT; Schema: action; Owner: actionsvc
--

COMMENT ON COLUMN actionrule.priority IS '1 = highest, 5 = lowest';


--
-- Name: actionstate; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE actionstate (
    statepk character varying(100) NOT NULL
);


ALTER TABLE actionstate OWNER TO actionsvc;

--
-- Name: actiontype; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE actiontype (
    actiontypepk integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(250) NOT NULL,
    handler character varying(100),
    cancancel boolean NOT NULL,
    responserequired boolean
);


ALTER TABLE actiontype OWNER TO actionsvc;

--
-- Name: case; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE "case" (
    actionplanid uuid NOT NULL,
    id uuid NOT NULL,
    casepk bigint NOT NULL,
    actionplanfk integer NOT NULL,
    actionplanstartdate timestamp with time zone NOT NULL,
    actionplanenddate timestamp with time zone NOT NULL
);


ALTER TABLE "case" OWNER TO actionsvc;

--
-- Name: casepkseq; Type: SEQUENCE; Schema: action; Owner: actionsvc
--

CREATE SEQUENCE casepkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE casepkseq OWNER TO actionsvc;

--
-- Name: databasechangelog; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE databasechangelog OWNER TO actionsvc;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE databasechangeloglock OWNER TO actionsvc;

--
-- Name: messageseq; Type: SEQUENCE; Schema: action; Owner: actionsvc
--

CREATE SEQUENCE messageseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE messageseq OWNER TO actionsvc;

--
-- Name: messagelog; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE messagelog (
    messagepk bigint DEFAULT nextval('messageseq'::regclass) NOT NULL,
    messagetext character varying,
    jobid numeric,
    messagelevel character varying,
    functionname character varying,
    createddatetime timestamp with time zone
);


ALTER TABLE messagelog OWNER TO actionsvc;

--
-- Name: outcomecategory; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE outcomecategory (
    handlerpk character varying(100) NOT NULL,
    actionoutcomepk character varying(40) NOT NULL,
    eventcategory character varying(40)
);


ALTER TABLE outcomecategory OWNER TO actionsvc;

--
-- Name: report; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE report (
    id uuid NOT NULL,
    reportpk bigint NOT NULL,
    reporttypefk character varying(20),
    contents text,
    createddatetime timestamp with time zone
);


ALTER TABLE report OWNER TO actionsvc;

--
-- Name: reportpkseq; Type: SEQUENCE; Schema: action; Owner: actionsvc
--

CREATE SEQUENCE reportpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE reportpkseq OWNER TO actionsvc;

--
-- Name: reporttype; Type: TABLE; Schema: action; Owner: actionsvc
--

CREATE TABLE reporttype (
    reporttypepk character varying(20) NOT NULL,
    displayorder integer,
    displayname character varying(40)
);


ALTER TABLE reporttype OWNER TO actionsvc;

SET search_path = actionexporter, pg_catalog;

--
-- Name: actionrequest; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE actionrequest (
    actionrequestpk bigint NOT NULL,
    actionid uuid NOT NULL,
    responserequired boolean DEFAULT false,
    actionplanname character varying(100),
    actiontypename character varying(100) NOT NULL,
    questionset character varying(10),
    contactfk bigint,
    sampleunitreffk character varying(20) NOT NULL,
    caseid uuid NOT NULL,
    priority character varying(10),
    caseref character varying(16),
    iac character varying(24) NOT NULL,
    datestored timestamp with time zone,
    datesent timestamp with time zone,
    exerciseref character varying(20) NOT NULL
);


ALTER TABLE actionrequest OWNER TO actionexportersvc;

--
-- Name: actionrequestpkseq; Type: SEQUENCE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE SEQUENCE actionrequestpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE actionrequestpkseq OWNER TO actionexportersvc;

--
-- Name: address; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE address (
    sampleunitrefpk character varying(20) NOT NULL,
    addresstype character varying(6),
    estabtype character varying(6),
    category character varying(20),
    organisation_name character varying(60),
    address_line1 character varying(60),
    address_line2 character varying(60),
    locality character varying(35),
    town_name character varying(30),
    postcode character varying(8),
    lad character varying(9),
    latitude double precision,
    longitude double precision
);


ALTER TABLE address OWNER TO actionexportersvc;

--
-- Name: contactpkseq; Type: SEQUENCE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE SEQUENCE contactpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE contactpkseq OWNER TO actionexportersvc;

--
-- Name: contact; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE contact (
    contactpk integer DEFAULT nextval('contactpkseq'::regclass) NOT NULL,
    forename character varying(35),
    surname character varying(35),
    phonenumber character varying(20),
    emailaddress character varying(50),
    title character varying(20)
);


ALTER TABLE contact OWNER TO actionexportersvc;

--
-- Name: databasechangelog; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE databasechangelog OWNER TO actionexportersvc;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE databasechangeloglock OWNER TO actionexportersvc;

--
-- Name: filerowcount; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE filerowcount (
    filename character varying(100) NOT NULL,
    rowcount integer NOT NULL,
    datesent timestamp with time zone NOT NULL,
    reported boolean NOT NULL,
    sendresult boolean NOT NULL
);


ALTER TABLE filerowcount OWNER TO actionexportersvc;

--
-- Name: messageseq; Type: SEQUENCE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE SEQUENCE messageseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE messageseq OWNER TO actionexportersvc;

--
-- Name: messagelog; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE messagelog (
    messagepk bigint DEFAULT nextval('messageseq'::regclass) NOT NULL,
    messagetext character varying,
    jobid numeric,
    messagelevel character varying,
    functionname character varying,
    createddatetime timestamp with time zone
);


ALTER TABLE messagelog OWNER TO actionexportersvc;

--
-- Name: report; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE report (
    id uuid NOT NULL,
    reportpk bigint NOT NULL,
    reporttypefk character varying(20),
    contents text,
    createddatetime timestamp with time zone
);


ALTER TABLE report OWNER TO actionexportersvc;

--
-- Name: reportpkseq; Type: SEQUENCE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE SEQUENCE reportpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE reportpkseq OWNER TO actionexportersvc;

--
-- Name: reporttype; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE reporttype (
    reporttypepk character varying(20) NOT NULL,
    displayorder integer,
    displayname character varying(40)
);


ALTER TABLE reporttype OWNER TO actionexportersvc;

--
-- Name: template; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE template (
    templatenamepk character varying(100) NOT NULL,
    content text NOT NULL,
    datemodified timestamp with time zone
);


ALTER TABLE template OWNER TO actionexportersvc;

--
-- Name: templatemapping; Type: TABLE; Schema: actionexporter; Owner: actionexportersvc
--

CREATE TABLE templatemapping (
    actiontypenamepk character varying(100) NOT NULL,
    templatenamefk character varying(100) NOT NULL,
    filenameprefix character varying(100) NOT NULL,
    datemodified timestamp with time zone
);


ALTER TABLE templatemapping OWNER TO actionexportersvc;

SET search_path = casesvc, pg_catalog;

--
-- Name: caserefseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE caserefseq
    START WITH 1000000000000001
    INCREMENT BY 1
    MINVALUE 1000000000000001
    MAXVALUE 9999999999999999
    CACHE 1;


ALTER TABLE caserefseq OWNER TO casesvc;

--
-- Name: case; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE "case" (
    casepk bigint NOT NULL,
    id uuid NOT NULL,
    caseref character varying(16) DEFAULT nextval('caserefseq'::regclass),
    casegroupfk bigint NOT NULL,
    casegroupid uuid NOT NULL,
    partyid uuid,
    sampleunittype character varying(2),
    collectioninstrumentid uuid,
    statefk character varying(20),
    actionplanid uuid,
    createddatetime timestamp with time zone,
    createdby character varying(50),
    iac character varying(20),
    sourcecase bigint,
    optlockversion integer DEFAULT 0
);


ALTER TABLE "case" OWNER TO casesvc;

--
-- Name: caseevent; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE caseevent (
    caseeventpk bigint NOT NULL,
    casefk bigint NOT NULL,
    description character varying(350),
    createdby character varying(50),
    createddatetime timestamp with time zone,
    categoryfk character varying(40),
    subcategory character varying(100)
);


ALTER TABLE caseevent OWNER TO casesvc;

--
-- Name: caseeventseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE caseeventseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE caseeventseq OWNER TO casesvc;

--
-- Name: casegroup; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE casegroup (
    casegrouppk bigint NOT NULL,
    id uuid NOT NULL,
    partyid uuid,
    collectionexerciseid uuid,
    sampleunitref character varying(20),
    sampleunittype character varying(2)
);


ALTER TABLE casegroup OWNER TO casesvc;

--
-- Name: casegroupseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE casegroupseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE casegroupseq OWNER TO casesvc;

--
-- Name: caseseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE caseseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE caseseq OWNER TO casesvc;

--
-- Name: casestate; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE casestate (
    statepk character varying(20) NOT NULL
);


ALTER TABLE casestate OWNER TO casesvc;

--
-- Name: category; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE category (
    categorypk character varying(40) NOT NULL,
    shortdescription character varying(50),
    longdescription character varying(50),
    eventtype character varying(20),
    role character varying(100),
    generatedactiontype character varying(100),
    "group" character varying(20),
    oldcasesampleunittypes character varying(10) NOT NULL,
    newcasesampleunittype character varying(10),
    recalccollectioninstrument boolean
);


ALTER TABLE category OWNER TO casesvc;

--
-- Name: databasechangelog; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE databasechangelog OWNER TO casesvc;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE databasechangeloglock OWNER TO casesvc;

--
-- Name: messagelogseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE messagelogseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE messagelogseq OWNER TO casesvc;

--
-- Name: messagelog; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE messagelog (
    messagelogpk bigint DEFAULT nextval('messagelogseq'::regclass) NOT NULL,
    messagetext character varying,
    jobid numeric,
    messagelevel character varying,
    functionname character varying,
    createddatetime timestamp with time zone
);


ALTER TABLE messagelog OWNER TO casesvc;

--
-- Name: report; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE report (
    id uuid NOT NULL,
    reportpk bigint NOT NULL,
    reporttypefk character varying(20),
    contents text,
    createddatetime timestamp with time zone
);


ALTER TABLE report OWNER TO casesvc;

--
-- Name: reportpkseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE reportpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE reportpkseq OWNER TO casesvc;

--
-- Name: reporttype; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE reporttype (
    reporttypepk character varying(20) NOT NULL,
    displayorder integer,
    displayname character varying(40)
);


ALTER TABLE reporttype OWNER TO casesvc;

--
-- Name: response; Type: TABLE; Schema: casesvc; Owner: casesvc
--

CREATE TABLE response (
    responsepk bigint NOT NULL,
    casefk bigint NOT NULL,
    inboundchannel character varying(10),
    responsedatetime timestamp with time zone
);


ALTER TABLE response OWNER TO casesvc;

--
-- Name: responseseq; Type: SEQUENCE; Schema: casesvc; Owner: casesvc
--

CREATE SEQUENCE responseseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE responseseq OWNER TO casesvc;

SET search_path = collectionexercise, pg_catalog;

--
-- Name: casetypedefault; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE casetypedefault (
    casetypedefaultpk integer NOT NULL,
    surveyfk integer NOT NULL,
    sampleunittypefk character varying(2) NOT NULL,
    actionplanid uuid
);


ALTER TABLE casetypedefault OWNER TO collectionexercisesvc;

--
-- Name: casetypeoverride; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE casetypeoverride (
    casetypeoverridepk integer NOT NULL,
    exercisefk bigint NOT NULL,
    sampleunittypefk character varying(2) NOT NULL,
    actionplanid uuid
);


ALTER TABLE casetypeoverride OWNER TO collectionexercisesvc;

--
-- Name: exercisepkseq; Type: SEQUENCE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE SEQUENCE exercisepkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE exercisepkseq OWNER TO collectionexercisesvc;

--
-- Name: collectionexercise; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE collectionexercise (
    id uuid NOT NULL,
    exercisepk bigint DEFAULT nextval('exercisepkseq'::regclass) NOT NULL,
    surveyfk integer NOT NULL,
    name character varying(20),
    scheduledstartdatetime timestamp with time zone,
    scheduledexecutiondatetime timestamp with time zone,
    scheduledreturndatetime timestamp with time zone,
    scheduledenddatetime timestamp with time zone,
    periodstartdatetime timestamp with time zone,
    periodenddatetime timestamp with time zone,
    actualexecutiondatetime timestamp with time zone,
    actualpublishdatetime timestamp with time zone,
    executedby character varying(50),
    statefk character varying(20) NOT NULL,
    samplesize integer,
    exerciseref character varying(20) NOT NULL
);


ALTER TABLE collectionexercise OWNER TO collectionexercisesvc;

--
-- Name: collectionexercisestate; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE collectionexercisestate (
    statepk character varying(20) NOT NULL
);


ALTER TABLE collectionexercisestate OWNER TO collectionexercisesvc;

--
-- Name: databasechangelog; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE databasechangelog OWNER TO collectionexercisesvc;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE databasechangeloglock OWNER TO collectionexercisesvc;

--
-- Name: messagelogseq; Type: SEQUENCE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE SEQUENCE messagelogseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE messagelogseq OWNER TO collectionexercisesvc;

--
-- Name: messagelog; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE messagelog (
    messagelogpk bigint DEFAULT nextval('messagelogseq'::regclass) NOT NULL,
    messagetext character varying,
    jobid numeric,
    messagelevel character varying,
    functionname character varying,
    createddatetime timestamp with time zone
);


ALTER TABLE messagelog OWNER TO collectionexercisesvc;

--
-- Name: report; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE report (
    id uuid NOT NULL,
    reportpk bigint NOT NULL,
    reporttypefk character varying(20),
    contents text,
    createddatetime timestamp with time zone
);


ALTER TABLE report OWNER TO collectionexercisesvc;

--
-- Name: reportpkseq; Type: SEQUENCE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE SEQUENCE reportpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE reportpkseq OWNER TO collectionexercisesvc;

--
-- Name: reporttype; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE reporttype (
    reporttypepk character varying(20) NOT NULL,
    displayorder integer,
    displayname character varying(40)
);


ALTER TABLE reporttype OWNER TO collectionexercisesvc;

--
-- Name: samplelink; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE samplelink (
    collectionexerciseid uuid,
    samplesummaryid uuid,
    samplelinkpk bigint NOT NULL
);


ALTER TABLE samplelink OWNER TO collectionexercisesvc;

--
-- Name: samplelinkpkseq; Type: SEQUENCE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE SEQUENCE samplelinkpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE samplelinkpkseq OWNER TO collectionexercisesvc;

--
-- Name: sampleunitpkseq; Type: SEQUENCE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE SEQUENCE sampleunitpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE sampleunitpkseq OWNER TO collectionexercisesvc;

--
-- Name: sampleunit; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE sampleunit (
    sampleunitpk bigint DEFAULT nextval('sampleunitpkseq'::regclass) NOT NULL,
    sampleunitgroupfk bigint NOT NULL,
    collectioninstrumentid uuid,
    partyid uuid,
    sampleunitref character varying(20) NOT NULL,
    sampleunittypefk character varying(2) NOT NULL
);


ALTER TABLE sampleunit OWNER TO collectionexercisesvc;

--
-- Name: sampleunitgrouppkseq; Type: SEQUENCE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE SEQUENCE sampleunitgrouppkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE sampleunitgrouppkseq OWNER TO collectionexercisesvc;

--
-- Name: sampleunitgroup; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE sampleunitgroup (
    sampleunitgrouppk bigint DEFAULT nextval('sampleunitgrouppkseq'::regclass) NOT NULL,
    exercisefk bigint NOT NULL,
    formtype character varying(10) NOT NULL,
    statefk character varying(20) NOT NULL,
    createddatetime timestamp with time zone,
    modifieddatetime timestamp with time zone
);


ALTER TABLE sampleunitgroup OWNER TO collectionexercisesvc;

--
-- Name: sampleunitgroupstate; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE sampleunitgroupstate (
    statepk character varying(20) NOT NULL
);


ALTER TABLE sampleunitgroupstate OWNER TO collectionexercisesvc;

--
-- Name: sampleunittype; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE sampleunittype (
    sampleunittypepk character varying(2) NOT NULL
);


ALTER TABLE sampleunittype OWNER TO collectionexercisesvc;

--
-- Name: survey; Type: TABLE; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE TABLE survey (
    id uuid NOT NULL,
    surveypk integer NOT NULL,
    surveyref character varying(100) NOT NULL
);


ALTER TABLE survey OWNER TO collectionexercisesvc;

SET search_path = iac, pg_catalog;

--
-- Name: databasechangelog; Type: TABLE; Schema: iac; Owner: postgres
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE databasechangelog OWNER TO postgres;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: iac; Owner: postgres
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE databasechangeloglock OWNER TO postgres;

--
-- Name: iac; Type: TABLE; Schema: iac; Owner: postgres
--

CREATE TABLE iac (
    code character varying(20) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    createddatetime timestamp with time zone NOT NULL,
    createdby character varying(20) NOT NULL,
    updateddatetime timestamp with time zone,
    updatedby character varying(20),
    lastuseddatetime timestamp with time zone
);


ALTER TABLE iac OWNER TO postgres;

SET search_path = partysvc, pg_catalog;

--
-- Name: business; Type: TABLE; Schema: partysvc; Owner: postgres
--

CREATE TABLE business (
    party_uuid uuid NOT NULL,
    business_ref text,
    attributes jsonb,
    created_on timestamp without time zone
);


ALTER TABLE business OWNER TO postgres;

--
-- Name: business_respondent; Type: TABLE; Schema: partysvc; Owner: postgres
--

CREATE TABLE business_respondent (
    business_id uuid NOT NULL,
    respondent_id integer NOT NULL,
    status public.businessrespondentstatus,
    effective_from timestamp without time zone,
    effective_to timestamp without time zone,
    created_on timestamp without time zone
);


ALTER TABLE business_respondent OWNER TO postgres;

--
-- Name: enrolment; Type: TABLE; Schema: partysvc; Owner: postgres
--

CREATE TABLE enrolment (
    business_id uuid NOT NULL,
    respondent_id integer NOT NULL,
    survey_id text NOT NULL,
    survey_name text,
    status public.enrolmentstatus,
    created_on timestamp without time zone
);


ALTER TABLE enrolment OWNER TO postgres;

--
-- Name: pending_enrolment; Type: TABLE; Schema: partysvc; Owner: postgres
--

CREATE TABLE pending_enrolment (
    id integer NOT NULL,
    case_id uuid,
    respondent_id integer,
    business_id uuid,
    survey_id uuid,
    created_on timestamp without time zone
);


ALTER TABLE pending_enrolment OWNER TO postgres;

--
-- Name: pending_enrolment_id_seq; Type: SEQUENCE; Schema: partysvc; Owner: postgres
--

CREATE SEQUENCE pending_enrolment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pending_enrolment_id_seq OWNER TO postgres;

--
-- Name: pending_enrolment_id_seq; Type: SEQUENCE OWNED BY; Schema: partysvc; Owner: postgres
--

ALTER SEQUENCE pending_enrolment_id_seq OWNED BY pending_enrolment.id;


--
-- Name: respondent; Type: TABLE; Schema: partysvc; Owner: postgres
--

CREATE TABLE respondent (
    id integer NOT NULL,
    party_uuid uuid,
    status public.respondentstatus,
    email_address text,
    first_name text,
    last_name text,
    telephone text,
    created_on timestamp without time zone
);


ALTER TABLE respondent OWNER TO postgres;

--
-- Name: respondent_id_seq; Type: SEQUENCE; Schema: partysvc; Owner: postgres
--

CREATE SEQUENCE respondent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE respondent_id_seq OWNER TO postgres;

--
-- Name: respondent_id_seq; Type: SEQUENCE OWNED BY; Schema: partysvc; Owner: postgres
--

ALTER SEQUENCE respondent_id_seq OWNED BY respondent.id;


SET search_path = public, pg_catalog;

--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_group (
    id integer NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE auth_group OWNER TO postgres;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_group_id_seq OWNER TO postgres;

--
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_group_id_seq OWNED BY auth_group.id;


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE auth_group_permissions OWNER TO postgres;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_group_permissions_id_seq OWNER TO postgres;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_group_permissions_id_seq OWNED BY auth_group_permissions.id;


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE auth_permission OWNER TO postgres;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_permission_id_seq OWNER TO postgres;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_permission_id_seq OWNED BY auth_permission.id;


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(30) NOT NULL,
    first_name character varying(30) NOT NULL,
    last_name character varying(30) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE auth_user OWNER TO postgres;

--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE auth_user_groups OWNER TO postgres;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_user_groups_id_seq OWNER TO postgres;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_user_groups_id_seq OWNED BY auth_user_groups.id;


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_user_id_seq OWNER TO postgres;

--
-- Name: auth_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_user_id_seq OWNED BY auth_user.id;


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auth_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE auth_user_user_permissions OWNER TO postgres;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auth_user_user_permissions_id_seq OWNER TO postgres;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auth_user_user_permissions_id_seq OWNED BY auth_user_user_permissions.id;


--
-- Name: credentials_oauthclient; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE credentials_oauthclient (
    id integer NOT NULL,
    password character varying(160) NOT NULL,
    client_id character varying(254) NOT NULL,
    redirect_uri character varying(254) NOT NULL
);


ALTER TABLE credentials_oauthclient OWNER TO postgres;

--
-- Name: credentials_oauthclient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE credentials_oauthclient_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE credentials_oauthclient_id_seq OWNER TO postgres;

--
-- Name: credentials_oauthclient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE credentials_oauthclient_id_seq OWNED BY credentials_oauthclient.id;


--
-- Name: credentials_oauthuser; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE credentials_oauthuser (
    id integer NOT NULL,
    password character varying(160) NOT NULL,
    email character varying(254) NOT NULL,
    failed_logins integer NOT NULL,
    account_is_locked boolean NOT NULL,
    account_is_verified boolean NOT NULL
);


ALTER TABLE credentials_oauthuser OWNER TO postgres;

--
-- Name: credentials_oauthuser_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE credentials_oauthuser_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE credentials_oauthuser_id_seq OWNER TO postgres;

--
-- Name: credentials_oauthuser_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE credentials_oauthuser_id_seq OWNED BY credentials_oauthuser.id;


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE django_admin_log OWNER TO postgres;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE django_admin_log_id_seq OWNER TO postgres;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE django_admin_log_id_seq OWNED BY django_admin_log.id;


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE django_content_type OWNER TO postgres;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE django_content_type_id_seq OWNER TO postgres;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE django_content_type_id_seq OWNED BY django_content_type.id;


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_migrations (
    id integer NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE django_migrations OWNER TO postgres;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE django_migrations_id_seq OWNER TO postgres;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE django_migrations_id_seq OWNED BY django_migrations.id;


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE django_session OWNER TO postgres;

--
-- Name: tokens_oauthaccesstoken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tokens_oauthaccesstoken (
    id integer NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    access_token character varying(40) NOT NULL,
    client_id integer NOT NULL,
    refresh_token_id integer,
    user_id integer
);


ALTER TABLE tokens_oauthaccesstoken OWNER TO postgres;

--
-- Name: tokens_oauthaccesstoken_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tokens_oauthaccesstoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tokens_oauthaccesstoken_id_seq OWNER TO postgres;

--
-- Name: tokens_oauthaccesstoken_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tokens_oauthaccesstoken_id_seq OWNED BY tokens_oauthaccesstoken.id;


--
-- Name: tokens_oauthaccesstoken_scopes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tokens_oauthaccesstoken_scopes (
    id integer NOT NULL,
    oauthaccesstoken_id integer NOT NULL,
    oauthscope_id integer NOT NULL
);


ALTER TABLE tokens_oauthaccesstoken_scopes OWNER TO postgres;

--
-- Name: tokens_oauthaccesstoken_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tokens_oauthaccesstoken_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tokens_oauthaccesstoken_scopes_id_seq OWNER TO postgres;

--
-- Name: tokens_oauthaccesstoken_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tokens_oauthaccesstoken_scopes_id_seq OWNED BY tokens_oauthaccesstoken_scopes.id;


--
-- Name: tokens_oauthauthorizationcode; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tokens_oauthauthorizationcode (
    id integer NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    code character varying(40) NOT NULL,
    redirect_uri character varying(200),
    client_id integer NOT NULL,
    user_id integer
);


ALTER TABLE tokens_oauthauthorizationcode OWNER TO postgres;

--
-- Name: tokens_oauthauthorizationcode_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tokens_oauthauthorizationcode_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tokens_oauthauthorizationcode_id_seq OWNER TO postgres;

--
-- Name: tokens_oauthauthorizationcode_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tokens_oauthauthorizationcode_id_seq OWNED BY tokens_oauthauthorizationcode.id;


--
-- Name: tokens_oauthauthorizationcode_scopes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tokens_oauthauthorizationcode_scopes (
    id integer NOT NULL,
    oauthauthorizationcode_id integer NOT NULL,
    oauthscope_id integer NOT NULL
);


ALTER TABLE tokens_oauthauthorizationcode_scopes OWNER TO postgres;

--
-- Name: tokens_oauthauthorizationcode_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tokens_oauthauthorizationcode_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tokens_oauthauthorizationcode_scopes_id_seq OWNER TO postgres;

--
-- Name: tokens_oauthauthorizationcode_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tokens_oauthauthorizationcode_scopes_id_seq OWNED BY tokens_oauthauthorizationcode_scopes.id;


--
-- Name: tokens_oauthrefreshtoken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tokens_oauthrefreshtoken (
    id integer NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    refresh_token character varying(40) NOT NULL
);


ALTER TABLE tokens_oauthrefreshtoken OWNER TO postgres;

--
-- Name: tokens_oauthrefreshtoken_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tokens_oauthrefreshtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tokens_oauthrefreshtoken_id_seq OWNER TO postgres;

--
-- Name: tokens_oauthrefreshtoken_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tokens_oauthrefreshtoken_id_seq OWNED BY tokens_oauthrefreshtoken.id;


--
-- Name: tokens_oauthscope; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE tokens_oauthscope (
    id integer NOT NULL,
    scope character varying(200) NOT NULL,
    description text NOT NULL,
    is_default boolean NOT NULL
);


ALTER TABLE tokens_oauthscope OWNER TO postgres;

--
-- Name: tokens_oauthscope_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tokens_oauthscope_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tokens_oauthscope_id_seq OWNER TO postgres;

--
-- Name: tokens_oauthscope_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tokens_oauthscope_id_seq OWNED BY tokens_oauthscope.id;


SET search_path = ras_ci, pg_catalog;

--
-- Name: business; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE business (
    id integer NOT NULL,
    ru_ref character varying(32)
);


ALTER TABLE business OWNER TO postgres;

--
-- Name: business_id_seq; Type: SEQUENCE; Schema: ras_ci; Owner: postgres
--

CREATE SEQUENCE business_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE business_id_seq OWNER TO postgres;

--
-- Name: business_id_seq; Type: SEQUENCE OWNED BY; Schema: ras_ci; Owner: postgres
--

ALTER SEQUENCE business_id_seq OWNED BY business.id;


--
-- Name: classification; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE classification (
    id integer NOT NULL,
    instrument_id integer,
    kind public.kind,
    value character varying(64)
);


ALTER TABLE classification OWNER TO postgres;

--
-- Name: classification_id_seq; Type: SEQUENCE; Schema: ras_ci; Owner: postgres
--

CREATE SEQUENCE classification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE classification_id_seq OWNER TO postgres;

--
-- Name: classification_id_seq; Type: SEQUENCE OWNED BY; Schema: ras_ci; Owner: postgres
--

ALTER SEQUENCE classification_id_seq OWNED BY classification.id;


--
-- Name: exercise; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE exercise (
    id integer NOT NULL,
    exercise_id uuid,
    items integer,
    status public.status
);


ALTER TABLE exercise OWNER TO postgres;

--
-- Name: exercise_id_seq; Type: SEQUENCE; Schema: ras_ci; Owner: postgres
--

CREATE SEQUENCE exercise_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE exercise_id_seq OWNER TO postgres;

--
-- Name: exercise_id_seq; Type: SEQUENCE OWNED BY; Schema: ras_ci; Owner: postgres
--

ALTER SEQUENCE exercise_id_seq OWNED BY exercise.id;


--
-- Name: instrument; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE instrument (
    id integer NOT NULL,
    instrument_id uuid,
    data bytea,
    len integer,
    stamp timestamp without time zone,
    survey_id integer
);


ALTER TABLE instrument OWNER TO postgres;

--
-- Name: instrument_business; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE instrument_business (
    instrument_id integer,
    business_id integer
);


ALTER TABLE instrument_business OWNER TO postgres;

--
-- Name: instrument_exercise; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE instrument_exercise (
    instrument_id integer,
    exercise_id integer
);


ALTER TABLE instrument_exercise OWNER TO postgres;

--
-- Name: instrument_id_seq; Type: SEQUENCE; Schema: ras_ci; Owner: postgres
--

CREATE SEQUENCE instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE instrument_id_seq OWNER TO postgres;

--
-- Name: instrument_id_seq; Type: SEQUENCE OWNED BY; Schema: ras_ci; Owner: postgres
--

ALTER SEQUENCE instrument_id_seq OWNED BY instrument.id;


--
-- Name: survey; Type: TABLE; Schema: ras_ci; Owner: postgres
--

CREATE TABLE survey (
    id integer NOT NULL,
    survey_id uuid
);


ALTER TABLE survey OWNER TO postgres;

--
-- Name: survey_id_seq; Type: SEQUENCE; Schema: ras_ci; Owner: postgres
--

CREATE SEQUENCE survey_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE survey_id_seq OWNER TO postgres;

--
-- Name: survey_id_seq; Type: SEQUENCE OWNED BY; Schema: ras_ci; Owner: postgres
--

ALTER SEQUENCE survey_id_seq OWNED BY survey.id;


SET search_path = sample, pg_catalog;

--
-- Name: collectionexercisejob; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE collectionexercisejob (
    collectionexercisejobpk bigint NOT NULL,
    collectionexerciseid uuid,
    surveyref character varying(100),
    exercisedatetime timestamp with time zone,
    createddatetime timestamp with time zone,
    samplesummaryid uuid
);


ALTER TABLE collectionexercisejob OWNER TO samplesvc;

--
-- Name: collectionexercisejobseq; Type: SEQUENCE; Schema: sample; Owner: samplesvc
--

CREATE SEQUENCE collectionexercisejobseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE collectionexercisejobseq OWNER TO samplesvc;

--
-- Name: databasechangelog; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


ALTER TABLE databasechangelog OWNER TO samplesvc;

--
-- Name: databasechangeloglock; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


ALTER TABLE databasechangeloglock OWNER TO samplesvc;

--
-- Name: messagelogseq; Type: SEQUENCE; Schema: sample; Owner: samplesvc
--

CREATE SEQUENCE messagelogseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE messagelogseq OWNER TO samplesvc;

--
-- Name: messagelog; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE messagelog (
    messagelogpk bigint DEFAULT nextval('messagelogseq'::regclass) NOT NULL,
    messagetext character varying,
    jobid numeric,
    messagelevel character varying,
    functionname character varying,
    createddatetime timestamp with time zone
);


ALTER TABLE messagelog OWNER TO samplesvc;

--
-- Name: report; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE report (
    id uuid NOT NULL,
    reportpk bigint NOT NULL,
    reporttypefk character varying(20),
    contents text,
    createddatetime timestamp with time zone
);


ALTER TABLE report OWNER TO samplesvc;

--
-- Name: reportpkseq; Type: SEQUENCE; Schema: sample; Owner: samplesvc
--

CREATE SEQUENCE reportpkseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE reportpkseq OWNER TO samplesvc;

--
-- Name: reporttype; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE reporttype (
    reporttypepk character varying(20) NOT NULL,
    displayorder integer,
    displayname character varying(40)
);


ALTER TABLE reporttype OWNER TO samplesvc;

--
-- Name: samplesummary; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE samplesummary (
    samplesummarypk bigint NOT NULL,
    statefk character varying(20) NOT NULL,
    ingestdatetime timestamp with time zone,
    id uuid NOT NULL,
    description character varying(250)
);


ALTER TABLE samplesummary OWNER TO samplesvc;

--
-- Name: samplesummaryseq; Type: SEQUENCE; Schema: sample; Owner: samplesvc
--

CREATE SEQUENCE samplesummaryseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE samplesummaryseq OWNER TO samplesvc;

--
-- Name: samplesummarystate; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE samplesummarystate (
    statepk character varying(20) NOT NULL
);


ALTER TABLE samplesummarystate OWNER TO samplesvc;

--
-- Name: sampleunit; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE sampleunit (
    sampleunitpk bigint NOT NULL,
    samplesummaryfk bigint NOT NULL,
    sampleunitref character varying(20),
    sampleunittype character varying(2),
    formtype character varying(10),
    statefk character varying(20) NOT NULL,
    id uuid NOT NULL
);


ALTER TABLE sampleunit OWNER TO samplesvc;

--
-- Name: sampleunitseq; Type: SEQUENCE; Schema: sample; Owner: samplesvc
--

CREATE SEQUENCE sampleunitseq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999999999
    CACHE 1;


ALTER TABLE sampleunitseq OWNER TO samplesvc;

--
-- Name: sampleunitstate; Type: TABLE; Schema: sample; Owner: samplesvc
--

CREATE TABLE sampleunitstate (
    statepk character varying(20) NOT NULL
);


ALTER TABLE sampleunitstate OWNER TO samplesvc;

SET search_path = survey, pg_catalog;

--
-- Name: classifiertype; Type: TABLE; Schema: survey; Owner: postgres
--

CREATE TABLE classifiertype (
    classifiertypepk integer NOT NULL,
    classifiertypeselectorfk integer NOT NULL,
    classifiertype character varying(50) NOT NULL
);


ALTER TABLE classifiertype OWNER TO postgres;

--
-- Name: classifiertype_classifiertypepk_seq; Type: SEQUENCE; Schema: survey; Owner: postgres
--

CREATE SEQUENCE classifiertype_classifiertypepk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE classifiertype_classifiertypepk_seq OWNER TO postgres;

--
-- Name: classifiertype_classifiertypepk_seq; Type: SEQUENCE OWNED BY; Schema: survey; Owner: postgres
--

ALTER SEQUENCE classifiertype_classifiertypepk_seq OWNED BY classifiertype.classifiertypepk;


--
-- Name: classifiertypeselector; Type: TABLE; Schema: survey; Owner: postgres
--

CREATE TABLE classifiertypeselector (
    classifiertypeselectorpk integer NOT NULL,
    id uuid NOT NULL,
    surveyfk integer NOT NULL,
    classifiertypeselector character varying(50) NOT NULL
);


ALTER TABLE classifiertypeselector OWNER TO postgres;

--
-- Name: classifiertypeselector_classifiertypeselectorpk_seq; Type: SEQUENCE; Schema: survey; Owner: postgres
--

CREATE SEQUENCE classifiertypeselector_classifiertypeselectorpk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE classifiertypeselector_classifiertypeselectorpk_seq OWNER TO postgres;

--
-- Name: classifiertypeselector_classifiertypeselectorpk_seq; Type: SEQUENCE OWNED BY; Schema: survey; Owner: postgres
--

ALTER SEQUENCE classifiertypeselector_classifiertypeselectorpk_seq OWNED BY classifiertypeselector.classifiertypeselectorpk;


--
-- Name: survey; Type: TABLE; Schema: survey; Owner: postgres
--

CREATE TABLE survey (
    surveypk integer NOT NULL,
    id uuid NOT NULL,
    shortname character varying(20) NOT NULL,
    longname character varying(100) NOT NULL,
    surveyref character varying(20) NOT NULL
);


ALTER TABLE survey OWNER TO postgres;

--
-- Name: survey_surveypk_seq; Type: SEQUENCE; Schema: survey; Owner: postgres
--

CREATE SEQUENCE survey_surveypk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE survey_surveypk_seq OWNER TO postgres;

--
-- Name: survey_surveypk_seq; Type: SEQUENCE OWNED BY; Schema: survey; Owner: postgres
--

ALTER SEQUENCE survey_surveypk_seq OWNED BY survey.surveypk;


SET search_path = partysvc, pg_catalog;

--
-- Name: pending_enrolment id; Type: DEFAULT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY pending_enrolment ALTER COLUMN id SET DEFAULT nextval('pending_enrolment_id_seq'::regclass);


--
-- Name: respondent id; Type: DEFAULT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY respondent ALTER COLUMN id SET DEFAULT nextval('respondent_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: auth_group id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group ALTER COLUMN id SET DEFAULT nextval('auth_group_id_seq'::regclass);


--
-- Name: auth_group_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('auth_group_permissions_id_seq'::regclass);


--
-- Name: auth_permission id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission ALTER COLUMN id SET DEFAULT nextval('auth_permission_id_seq'::regclass);


--
-- Name: auth_user id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user ALTER COLUMN id SET DEFAULT nextval('auth_user_id_seq'::regclass);


--
-- Name: auth_user_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups ALTER COLUMN id SET DEFAULT nextval('auth_user_groups_id_seq'::regclass);


--
-- Name: auth_user_user_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('auth_user_user_permissions_id_seq'::regclass);


--
-- Name: credentials_oauthclient id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY credentials_oauthclient ALTER COLUMN id SET DEFAULT nextval('credentials_oauthclient_id_seq'::regclass);


--
-- Name: credentials_oauthuser id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY credentials_oauthuser ALTER COLUMN id SET DEFAULT nextval('credentials_oauthuser_id_seq'::regclass);


--
-- Name: django_admin_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_admin_log ALTER COLUMN id SET DEFAULT nextval('django_admin_log_id_seq'::regclass);


--
-- Name: django_content_type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_content_type ALTER COLUMN id SET DEFAULT nextval('django_content_type_id_seq'::regclass);


--
-- Name: django_migrations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_migrations ALTER COLUMN id SET DEFAULT nextval('django_migrations_id_seq'::regclass);


--
-- Name: tokens_oauthaccesstoken id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken ALTER COLUMN id SET DEFAULT nextval('tokens_oauthaccesstoken_id_seq'::regclass);


--
-- Name: tokens_oauthaccesstoken_scopes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken_scopes ALTER COLUMN id SET DEFAULT nextval('tokens_oauthaccesstoken_scopes_id_seq'::regclass);


--
-- Name: tokens_oauthauthorizationcode id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode ALTER COLUMN id SET DEFAULT nextval('tokens_oauthauthorizationcode_id_seq'::regclass);


--
-- Name: tokens_oauthauthorizationcode_scopes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode_scopes ALTER COLUMN id SET DEFAULT nextval('tokens_oauthauthorizationcode_scopes_id_seq'::regclass);


--
-- Name: tokens_oauthrefreshtoken id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthrefreshtoken ALTER COLUMN id SET DEFAULT nextval('tokens_oauthrefreshtoken_id_seq'::regclass);


--
-- Name: tokens_oauthscope id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthscope ALTER COLUMN id SET DEFAULT nextval('tokens_oauthscope_id_seq'::regclass);


SET search_path = ras_ci, pg_catalog;

--
-- Name: business id; Type: DEFAULT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY business ALTER COLUMN id SET DEFAULT nextval('business_id_seq'::regclass);


--
-- Name: classification id; Type: DEFAULT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY classification ALTER COLUMN id SET DEFAULT nextval('classification_id_seq'::regclass);


--
-- Name: exercise id; Type: DEFAULT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY exercise ALTER COLUMN id SET DEFAULT nextval('exercise_id_seq'::regclass);


--
-- Name: instrument id; Type: DEFAULT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument ALTER COLUMN id SET DEFAULT nextval('instrument_id_seq'::regclass);


--
-- Name: survey id; Type: DEFAULT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY survey ALTER COLUMN id SET DEFAULT nextval('survey_id_seq'::regclass);


SET search_path = survey, pg_catalog;

--
-- Name: classifiertype classifiertypepk; Type: DEFAULT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertype ALTER COLUMN classifiertypepk SET DEFAULT nextval('classifiertype_classifiertypepk_seq'::regclass);


--
-- Name: classifiertypeselector classifiertypeselectorpk; Type: DEFAULT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertypeselector ALTER COLUMN classifiertypeselectorpk SET DEFAULT nextval('classifiertypeselector_classifiertypeselectorpk_seq'::regclass);


--
-- Name: survey surveypk; Type: DEFAULT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY survey ALTER COLUMN surveypk SET DEFAULT nextval('survey_surveypk_seq'::regclass);


SET search_path = action, pg_catalog;

--
-- Data for Name: action; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY action (id, actionpk, caseid, casefk, actionplanfk, actionrulefk, actiontypefk, createdby, manuallycreated, priority, situation, statefk, createddatetime, updateddatetime, optlockversion) FROM stdin;
\.


--
-- Name: actionpkseq; Type: SEQUENCE SET; Schema: action; Owner: actionsvc
--

SELECT pg_catalog.setval('actionpkseq', 1, false);


--
-- Data for Name: actionplan; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY actionplan (id, actionplanpk, name, description, createdby, lastrundatetime) FROM stdin;
e71002ac-3575-47eb-b87f-cd9db92bf9a7	1	Enrolment	BRES Enrolment	SYSTEM	\N
0009e978-0932-463b-a2a1-b45cb3ffcb2a	2	BRES	BRES	SYSTEM	\N
\.


--
-- Data for Name: actionplanjob; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY actionplanjob (id, actionplanjobpk, actionplanfk, createdby, statefk, createddatetime, updateddatetime) FROM stdin;
\.


--
-- Name: actionplanjobseq; Type: SEQUENCE SET; Schema: action; Owner: actionsvc
--

SELECT pg_catalog.setval('actionplanjobseq', 1, false);


--
-- Data for Name: actionplanjobstate; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY actionplanjobstate (statepk) FROM stdin;
SUBMITTED
STARTED
COMPLETED
FAILED
\.


--
-- Data for Name: actionrule; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY actionrule (actionrulepk, actionplanfk, actiontypefk, name, description, daysoffset, priority) FROM stdin;
2	1	2	BSREM+45	Enrolment Reminder Letter(+45 days)	45	3
3	1	2	BSREM+73	Enrolment Reminder Letter(+73 days)	73	3
4	2	3	BSSNE+45	Survey Reminder Notification(+45 days)	45	3
5	2	3	BSSNE+73	Survey Reminder Notification(+73 days)	73	3
1	1	1	BSNOT+0	Enrolment Invitation Letter(+0 days)	0	3
\.


--
-- Data for Name: actionstate; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY actionstate (statepk) FROM stdin;
SUBMITTED
PENDING
ACTIVE
COMPLETED
CANCEL_SUBMITTED
CANCELLED
CANCEL_PENDING
CANCELLING
ABORTED
\.


--
-- Data for Name: actiontype; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY actiontype (actiontypepk, name, description, handler, cancancel, responserequired) FROM stdin;
1	BSNOT	Enrolment Invitation Letter	Printer	f	f
2	BSREM	Enrolment Reminder Letter	Printer	f	f
3	BSSNE	Survey Reminder Notification	Notify	f	f
\.


--
-- Data for Name: case; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY "case" (actionplanid, id, casepk, actionplanfk, actionplanstartdate, actionplanenddate) FROM stdin;
\.


--
-- Name: casepkseq; Type: SEQUENCE SET; Schema: action; Owner: actionsvc
--

SELECT pg_catalog.setval('casepkseq', 1, false);


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
10.37.0-1	Sarah Radford	database/changes/release-10.37.0/changelog.yml	2017-12-01 11:40:01.777865	1	EXECUTED	7:0e71e8d5f1af547c54ea8a21cebb00a1	sqlFile		\N	3.5.3	\N	\N	2128401255
10.37.0-2	Sarah Radford	database/changes/release-10.37.0/changelog.yml	2017-12-01 11:40:01.871193	2	EXECUTED	7:0cf5d77081b31f353e16b69b644fea25	sqlFile		\N	3.5.3	\N	\N	2128401255
10.43.0-1	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:40:01.893972	3	EXECUTED	7:6956f3628325483fbbebbb3f21316c9a	sqlFile		\N	3.5.3	\N	\N	2128401255
10.43.0-2	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:40:02.165101	4	EXECUTED	7:85891b5dabf7d7a8568036a380196ba8	sqlFile		\N	3.5.3	\N	\N	2128401255
10.45.0-1	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:40:02.29843	5	EXECUTED	7:975a9ad06bb1327ca0a7c7597fce13e5	sqlFile		\N	3.5.3	\N	\N	2128401255
10.46.0-1	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:40:02.364889	6	EXECUTED	7:80e723c587adb6612b6a8c73f4f2d88a	sqlFile		\N	3.5.3	\N	\N	2128401255
10.46.0-2	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:40:02.42192	7	EXECUTED	7:a56dffa5ccfc08188c90e103c9f38020	sqlFile		\N	3.5.3	\N	\N	2128401255
10.46.0-3	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:40:02.487458	8	EXECUTED	7:3cf299ad6c4949aaa578788ce17c1608	sqlFile		\N	3.5.3	\N	\N	2128401255
10.46.0-4	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:40:02.53421	9	EXECUTED	7:2197f7c617038235be1c575fcdf2268e	sqlFile		\N	3.5.3	\N	\N	2128401255
10.47.0-1	Sarah Radford	database/changes/release-10.47.0/changelog.yml	2017-12-01 11:40:02.583126	10	EXECUTED	7:954ae53fc16c2226221fbdaffbd52416	sqlFile		\N	3.5.3	\N	\N	2128401255
10.47.0-2	Sarah Radford	database/changes/release-10.47.0/changelog.yml	2017-12-01 11:40:02.61171	11	EXECUTED	7:860a5372283b07eae1199d50ad526fdc	sqlFile		\N	3.5.3	\N	\N	2128401255
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: messagelog; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY messagelog (messagepk, messagetext, jobid, messagelevel, functionname, createddatetime) FROM stdin;
1	GENERATING ACTION MI REPORT	0	INFO	action.generate_action_mi	2017-12-01 11:41:00.211419+00
2	GENERATING ACTIONS MI REPORT COMPLETED ROWS WRIITEN = 5	0	INFO	action.generate_action_mi	2017-12-01 11:41:00.211419+00
3	ACTIONS MI REPORT GENERATED	0	INFO	action.generate_action_mi	2017-12-01 11:41:00.211419+00
\.


--
-- Name: messageseq; Type: SEQUENCE SET; Schema: action; Owner: actionsvc
--

SELECT pg_catalog.setval('messageseq', 3, true);


--
-- Data for Name: outcomecategory; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY outcomecategory (handlerpk, actionoutcomepk, eventcategory) FROM stdin;
Field	REQUEST_COMPLETED	ACTION_COMPLETED
Field	REQUEST_COMPLETED_DEACTIVATE	ACTION_COMPLETED_DEACTIVATED
Field	REQUEST_COMPLETED_DISABLE	ACTION_COMPLETED_DISABLED
Notify	REQUEST_COMPLETED	ACTION_COMPLETED
Notify	REQUEST_COMPLETED_DEACTIVATE	ACTION_COMPLETED_DEACTIVATED
Notify	REQUEST_COMPLETED_DISABLE	ACTION_COMPLETED_DISABLED
Printer	REQUEST_COMPLETED	ACTION_COMPLETED
Printer	REQUEST_COMPLETED_DEACTIVATE	ACTION_COMPLETED_DEACTIVATED
Printer	REQUEST_COMPLETED_DISABLE	ACTION_COMPLETED_DISABLED
\.


--
-- Data for Name: report; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY report (id, reportpk, reporttypefk, contents, createddatetime) FROM stdin;
ac18a5ec-c94d-4edf-8e5c-fc15e1d77355	1	ACTIONS	Action Plan No,Action Plan Name,Action Type,Action Plan Start Date,Days Offset,Handler,Count,State\n1,BRES Enrolment,Enrolment Invitation Letter,,0,Printer,0,\n1,BRES Enrolment,Enrolment Reminder Letter,,45,Printer,0,\n1,BRES Enrolment,Enrolment Reminder Letter,,73,Printer,0,\n2,BRES,Survey Reminder Notification,,45,Notify,0,\n2,BRES,Survey Reminder Notification,,73,Notify,0,	2017-12-01 11:41:00.211419+00
\.


--
-- Name: reportpkseq; Type: SEQUENCE SET; Schema: action; Owner: actionsvc
--

SELECT pg_catalog.setval('reportpkseq', 1, true);


--
-- Data for Name: reporttype; Type: TABLE DATA; Schema: action; Owner: actionsvc
--

COPY reporttype (reporttypepk, displayorder, displayname) FROM stdin;
ACTIONS	10	Action Status
\.


SET search_path = actionexporter, pg_catalog;

--
-- Data for Name: actionrequest; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY actionrequest (actionrequestpk, actionid, responserequired, actionplanname, actiontypename, questionset, contactfk, sampleunitreffk, caseid, priority, caseref, iac, datestored, datesent, exerciseref) FROM stdin;
\.


--
-- Name: actionrequestpkseq; Type: SEQUENCE SET; Schema: actionexporter; Owner: actionexportersvc
--

SELECT pg_catalog.setval('actionrequestpkseq', 1, false);


--
-- Data for Name: address; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY address (sampleunitrefpk, addresstype, estabtype, category, organisation_name, address_line1, address_line2, locality, town_name, postcode, lad, latitude, longitude) FROM stdin;
\.


--
-- Data for Name: contact; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY contact (contactpk, forename, surname, phonenumber, emailaddress, title) FROM stdin;
\.


--
-- Name: contactpkseq; Type: SEQUENCE SET; Schema: actionexporter; Owner: actionexportersvc
--

SELECT pg_catalog.setval('contactpkseq', 1, false);


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
10.40.0-1	Sarah Radford	database/changes/release-10.40.0/changelog.yml	2017-12-01 11:40:22.043814	1	EXECUTED	7:4011253ef9c5f1bcda7b26e8eec00c93	sqlFile		\N	3.5.3	\N	\N	2128421839
10.40.0-2	Sarah Radford	database/changes/release-10.40.0/changelog.yml	2017-12-01 11:40:22.099155	2	EXECUTED	7:2d95c060681c9dbf5bd070606ce25c13	sqlFile		\N	3.5.3	\N	\N	2128421839
10.43.0-1	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:40:22.126694	3	EXECUTED	7:a664ae020b2cee750a63c94ff09de3e5	sqlFile		\N	3.5.3	\N	\N	2128421839
10.43.0-2	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:40:22.229661	4	EXECUTED	7:cdf416190829d7d6f55e35fdf876624c	sqlFile		\N	3.5.3	\N	\N	2128421839
10.43.0-3	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:40:22.242007	5	EXECUTED	7:096deb4597fd60aaa2fca5c33e5eb596	sqlFile		\N	3.5.3	\N	\N	2128421839
10.43.0-4	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:40:22.256586	6	EXECUTED	7:9eed897d2d3d734f419c711fef9e4e5b	sqlFile		\N	3.5.3	\N	\N	2128421839
10.44.0-1	Gareth Turner	database/changes/release-10.44.0/changelog.yml	2017-12-01 11:40:22.277559	7	EXECUTED	7:9eed897d2d3d734f419c711fef9e4e5b	sqlFile		\N	3.5.3	\N	\N	2128421839
10.44.0-2	Chris Hardman	database/changes/release-10.44.0/changelog.yml	2017-12-01 11:40:22.3045	8	EXECUTED	7:31f1f65436cbcdd41fdb34b406bcdadc	sqlFile		\N	3.5.3	\N	\N	2128421839
10.44.0-3	Kieran Wardle	database/changes/release-10.44.0/changelog.yml	2017-12-01 11:40:22.332698	9	EXECUTED	7:e310a673b006a9c85a1b1d5bc7bfbfb8	sqlFile		\N	3.5.3	\N	\N	2128421839
10.45.0-1	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:40:22.383762	10	EXECUTED	7:b68536b0d7a018c9062198d600568d1e	sqlFile		\N	3.5.3	\N	\N	2128421839
10.45.0-2	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:40:22.423986	11	EXECUTED	7:35b6de9efbf79615f1165c68068c449b	sqlFile		\N	3.5.3	\N	\N	2128421839
10.47.0-1	Edward Stevens	database/changes/release-10.47.0/changelog.yml	2017-12-01 11:40:22.444769	12	EXECUTED	7:f8d92d734264ccacef0f6e681d9b592b	sqlFile		\N	3.5.3	\N	\N	2128421839
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: filerowcount; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY filerowcount (filename, rowcount, datesent, reported, sendresult) FROM stdin;
\.


--
-- Data for Name: messagelog; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY messagelog (messagepk, messagetext, jobid, messagelevel, functionname, createddatetime) FROM stdin;
\.


--
-- Name: messageseq; Type: SEQUENCE SET; Schema: actionexporter; Owner: actionexportersvc
--

SELECT pg_catalog.setval('messageseq', 1, false);


--
-- Data for Name: report; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY report (id, reportpk, reporttypefk, contents, createddatetime) FROM stdin;
\.


--
-- Name: reportpkseq; Type: SEQUENCE SET; Schema: actionexporter; Owner: actionexportersvc
--

SELECT pg_catalog.setval('reportpkseq', 1, false);


--
-- Data for Name: reporttype; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY reporttype (reporttypepk, displayorder, displayname) FROM stdin;
PRINT_VOLUMES	10	Print Volumes
\.


--
-- Data for Name: template; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY template (templatenamepk, content, datemodified) FROM stdin;
initialPrint	<#list actionRequests as actionRequest>\n${(actionRequest.address.sampleUnitRef?trim)!}:${actionRequest.iac?trim}:${(actionRequest.contact.forename?trim)!"null"}:${(actionRequest.contact.emailAddress)!"null"}\n  </#list>	2017-12-01 11:40:22.080972+00
\.


--
-- Data for Name: templatemapping; Type: TABLE DATA; Schema: actionexporter; Owner: actionexportersvc
--

COPY templatemapping (actiontypenamepk, templatenamefk, filenameprefix, datemodified) FROM stdin;
BSNOT	initialPrint	BSNOT	2017-12-01 11:40:22.080972+00
BSREM	initialPrint	BSREM	2017-12-01 11:40:22.080972+00
\.


SET search_path = casesvc, pg_catalog;

--
-- Data for Name: case; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY "case" (casepk, id, caseref, casegroupfk, casegroupid, partyid, sampleunittype, collectioninstrumentid, statefk, actionplanid, createddatetime, createdby, iac, sourcecase, optlockversion) FROM stdin;
\.


--
-- Data for Name: caseevent; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY caseevent (caseeventpk, casefk, description, createdby, createddatetime, categoryfk, subcategory) FROM stdin;
\.


--
-- Name: caseeventseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('caseeventseq', 1, false);


--
-- Data for Name: casegroup; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY casegroup (casegrouppk, id, partyid, collectionexerciseid, sampleunitref, sampleunittype) FROM stdin;
\.


--
-- Name: casegroupseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('casegroupseq', 1, false);


--
-- Name: caserefseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('caserefseq', 1000000000000001, false);


--
-- Name: caseseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('caseseq', 1, false);


--
-- Data for Name: casestate; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY casestate (statepk) FROM stdin;
ACTIONABLE
INACTIONABLE
REPLACEMENT_INIT
SAMPLED_INIT
\.


--
-- Data for Name: category; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY category (categorypk, shortdescription, longdescription, eventtype, role, generatedactiontype, "group", oldcasesampleunittypes, newcasesampleunittype, recalccollectioninstrument) FROM stdin;
ACTION_CREATED	Action Created	Action Created	\N	\N	\N	\N	B,BI	\N	\N
ACTION_COMPLETED	Action Completed	Action Completed	\N	\N	\N	\N	B,BI	\N	\N
ACTION_UPDATED	Action Updated	Action Updated	\N	\N	\N	\N	B,BI	\N	\N
CASE_CREATED	Case Created	Case Created	\N	\N	\N	\N	B,BI	\N	\N
RESPONDENT_ACCOUNT_CREATED	Account created for respondent	Account created for respondent	ACCOUNT_CREATED	\N	\N	\N	B	\N	\N
ACCESS_CODE_AUTHENTICATION_ATTEMPT	Access Code authentication attempted	Access Code authentication attempted	\N	\N	\N	\N	B	\N	\N
COLLECTION_INSTRUMENT_DOWNLOADED	Collection Instrument Downloaded	Collection Instrument Downloaded	\N	\N	\N	\N	BI	\N	\N
ACTION_CANCELLATION_COMPLETED	Action Cancellation Completed	Action Cancellation Completed	\N	\N	\N	\N	B,BI	\N	\N
ACTION_CANCELLATION_CREATED	Action Cancellation Created	Action Cancellation Created	\N	\N	\N	\N	B,BI	\N	\N
UNSUCCESSFUL_RESPONSE_UPLOAD	Unsuccessful Response Upload	Unsuccessful Response Upload	\N	\N	\N	\N	BI	\N	\N
SUCCESSFUL_RESPONSE_UPLOAD	Successful Response Upload	Successful Response Upload	DISABLED	\N	\N	\N	BI	\N	\N
RESPONDENT_ENROLED	Respondent Enroled	Respondent Enroled	DEACTIVATED	\N	\N	\N	B	BI	\N
SECURE_MESSAGE_SENT	Secure Message Sent	Secure Message Sent	\N	\N	\N	\N	BI	\N	\N
COLLECTION_INSTRUMENT_ERROR	Collection Instrument Error	Collection Instrument Error	\N	\N	\N	\N	BI	\N	\N
VERIFICATION_CODE_SENT	Verification Code Sent	Verification Code Sent	\N	\N	\N	\N	B	\N	\N
RESPONDENT_EMAIL_AMENDED	Respondent Email Amended	Respondent Email Amended	\N	\N	\N	\N	BI	\N	\N
OFFLINE_RESPONSE_PROCESSED	Offline Response Processed	Offline Response Processed	DISABLED	\N	\N	\N	BI	\N	\N
\.


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
10.39.0-1	Narinder Birk	database/changes/release-10.39.0/changelog.yml	2017-12-01 11:39:54.988225	1	EXECUTED	7:7f8e03d0f3252510f904d7444bfeebd0	sqlFile		\N	3.5.3	\N	\N	2128394478
10.39.0-2	Narinder Birk	database/changes/release-10.39.0/changelog.yml	2017-12-01 11:39:55.099488	2	EXECUTED	7:13ccf33122d43460953e0cdfce0d9eec	sqlFile		\N	3.5.3	\N	\N	2128394478
10.39.0-3	Narinder Birk	database/changes/release-10.39.0/changelog.yml	2017-12-01 11:39:55.171742	3	EXECUTED	7:df584fd38c4d8a1f568a6fb5fceddecd	sqlFile		\N	3.5.3	\N	\N	2128394478
10.40.0-1	Narinder Birk	database/changes/release-10.40.0/changelog.yml	2017-12-01 11:39:55.209593	4	EXECUTED	7:f4ccba8089aa4311c5999d0fcbf91be2	sqlFile		\N	3.5.3	\N	\N	2128394478
10.41.0-1	Narinder Birk	database/changes/release-10.41.0/changelog.yml	2017-12-01 11:39:55.373284	5	EXECUTED	7:1b04d959836a5717d06113ed862cae98	sqlFile		\N	3.5.3	\N	\N	2128394478
10.43.0-1	Narinder Birk	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:39:55.618113	6	EXECUTED	7:8be3cf75eb8e0005dcaf8fb17b16a574	sqlFile		\N	3.5.3	\N	\N	2128394478
10.43.0-2	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:39:55.720424	7	EXECUTED	7:8ac8601c02c9167ddb06b02ba7a3715e	sqlFile		\N	3.5.3	\N	\N	2128394478
10.44.0-1	Sarah Radford	database/changes/release-10.44.0/changelog.yml	2017-12-01 11:39:55.771259	8	EXECUTED	7:edf90b6d72362e083f6f9a16c822a31d	sqlFile		\N	3.5.3	\N	\N	2128394478
10.44.0-2	John Topley	database/changes/release-10.44.0/changelog.yml	2017-12-01 11:39:55.824572	9	EXECUTED	7:6dbbfb7d1a01a64f38a57946c6f985a6	sqlFile		\N	3.5.3	\N	\N	2128394478
10.44.0-3	Edward Stevens	database/changes/release-10.44.0/changelog.yml	2017-12-01 11:39:55.832077	10	EXECUTED	7:8c967460d5ca726f76da82dcd267419d	sqlFile		\N	3.5.3	\N	\N	2128394478
10.45.0-1	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:55.859943	11	EXECUTED	7:07e819834538fc465127f6fb5bfa1943	sqlFile		\N	3.5.3	\N	\N	2128394478
10.45.0-2	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:56.023721	12	EXECUTED	7:f5adf13c866a3d60b58bedbb2eafdcff	sqlFile		\N	3.5.3	\N	\N	2128394478
10.45.0-3	Edward Stevens	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:56.111128	13	EXECUTED	7:e51ec38d701d3e31ccf3ff49d7862cb5	sqlFile		\N	3.5.3	\N	\N	2128394478
10.45.0-4	Edward Stevens	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:56.161015	14	EXECUTED	7:35ca614d15a2a1a72d4c465af77c3379	sqlFile		\N	3.5.3	\N	\N	2128394478
10.46.0-1	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:39:56.463661	15	EXECUTED	7:4544b25cc9744c7a628293367b66e7f7	sqlFile		\N	3.5.3	\N	\N	2128394478
10.46.0-2	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:39:56.845489	16	EXECUTED	7:5cfcd1a95b4b207490198ccad042385a	sqlFile		\N	3.5.3	\N	\N	2128394478
10.46.0-3	Chris Hardman	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:39:56.921352	17	EXECUTED	7:203a13a8a0dbd0cf735e4a83503d95ba	sqlFile		\N	3.5.3	\N	\N	2128394478
10.47.0-1	Narinder Birk	database/changes/release-10.47.0/changelog.yml	2017-12-01 11:39:57.061059	18	EXECUTED	7:c19a17686ea126affe7c93d7a74e1a10	sqlFile		\N	3.5.3	\N	\N	2128394478
10.47.0-2	Narinder Birk	database/changes/release-10.47.0/changelog.yml	2017-12-01 11:39:57.29187	19	EXECUTED	7:8d3b3a72f681d130ca09f097fe6c9e0f	sqlFile		\N	3.5.3	\N	\N	2128394478
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: messagelog; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY messagelog (messagelogpk, messagetext, jobid, messagelevel, functionname, createddatetime) FROM stdin;
1	GENERATING RESPONSE CHASING REPORT	0	INFO	casesvc.generate_response_chasing_report	2017-12-01 11:42:00.313386+00
2	GENERATING RESPONSE CHASING REPORT COMPLETED ROWS WRIITEN = 0	0	INFO	casesvc.generate_response_chasing_report	2017-12-01 11:42:00.313386+00
3	RESPONSE CHASING REPORT GENERATED	0	INFO	casesvc.generate_response_chasing_report	2017-12-01 11:42:00.313386+00
4	GENERATING CASE EVENTS REPORT	0	INFO	casesvc.generate_case_events_report	2017-12-01 11:42:00.346174+00
5	GENERATING CASE EVENTS REPORT COMPLETED ROWS WRIITEN = 0	0	INFO	casesvc.generate_case_events_report	2017-12-01 11:42:00.346174+00
6	CASE EVENTS REPORT GENERATED	0	INFO	casesvc.generate_case_events_report	2017-12-01 11:42:00.346174+00
\.


--
-- Name: messagelogseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('messagelogseq', 6, true);


--
-- Data for Name: report; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY report (id, reportpk, reporttypefk, contents, createddatetime) FROM stdin;
\.


--
-- Name: reportpkseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('reportpkseq', 1, false);


--
-- Data for Name: reporttype; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY reporttype (reporttypepk, displayorder, displayname) FROM stdin;
CASE_EVENTS	1	Case Events
RESPONSE_CHASING	2	Response Chasing
\.


--
-- Data for Name: response; Type: TABLE DATA; Schema: casesvc; Owner: casesvc
--

COPY response (responsepk, casefk, inboundchannel, responsedatetime) FROM stdin;
\.


--
-- Name: responseseq; Type: SEQUENCE SET; Schema: casesvc; Owner: casesvc
--

SELECT pg_catalog.setval('responseseq', 1, false);


SET search_path = collectionexercise, pg_catalog;

--
-- Data for Name: casetypedefault; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY casetypedefault (casetypedefaultpk, surveyfk, sampleunittypefk, actionplanid) FROM stdin;
1	1	B	e71002ac-3575-47eb-b87f-cd9db92bf9a7
2	1	BI	0009e978-0932-463b-a2a1-b45cb3ffcb2a
\.


--
-- Data for Name: casetypeoverride; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY casetypeoverride (casetypeoverridepk, exercisefk, sampleunittypefk, actionplanid) FROM stdin;
\.


--
-- Data for Name: collectionexercise; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY collectionexercise (id, exercisepk, surveyfk, name, scheduledstartdatetime, scheduledexecutiondatetime, scheduledreturndatetime, scheduledenddatetime, periodstartdatetime, periodenddatetime, actualexecutiondatetime, actualpublishdatetime, executedby, statefk, samplesize, exerciseref) FROM stdin;
14fb3e68-4dca-46db-bf49-04b84e07e77c	1	1	BRES_2017	2017-09-11 23:00:00+00	2017-09-10 23:00:00+00	2017-10-06 00:00:00+00	2018-06-29 23:00:00+00	2017-09-14 23:00:00+00	2017-09-15 22:59:59+00	\N	\N	\N	INIT	\N	221_201712
\.


--
-- Data for Name: collectionexercisestate; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY collectionexercisestate (statepk) FROM stdin;
INIT
PENDING
EXECUTED
VALIDATED
PUBLISHED
FAILEDVALIDATION
\.


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
10.37.0-1	Sarah Radford	database/changes/release-10.37.0/changelog.yml	2017-12-01 11:39:40.666329	1	EXECUTED	7:4ac699ca18a5b1d347bdeb46b0a0c651	sqlFile		\N	3.5.3	\N	\N	2128380190
10.37.0-2	Sarah Radford	database/changes/release-10.37.0/changelog.yml	2017-12-01 11:39:40.741177	2	EXECUTED	7:3bfc1e2399f2c7ef12769fdd64dc2dcb	sqlFile		\N	3.5.3	\N	\N	2128380190
10.43.0-1	Sarah Radford	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:39:40.762736	3	EXECUTED	7:b804f90e987fa3a94420a9b576d6bc28	sqlFile		\N	3.5.3	\N	\N	2128380190
10.45.0-1	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:40.800339	4	EXECUTED	7:23ed22bfb3addaac8dcee120fef357d3	sqlFile		\N	3.5.3	\N	\N	2128380190
10.45.0-2	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:40.848434	5	EXECUTED	7:350228b97709e691eb2b6a9b82d5a70a	sqlFile		\N	3.5.3	\N	\N	2128380190
10.46.0-1	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:39:41.050858	6	EXECUTED	7:84602ef424c9e68227a7f844ff851923	sqlFile		\N	3.5.3	\N	\N	2128380190
10.46.0-2	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:39:41.079315	7	EXECUTED	7:62e9f91262ba368e00141464c0f68ffd	sqlFile		\N	3.5.3	\N	\N	2128380190
10.47.0-1	Sarah Radford	database/changes/release-10.47.0/changelog.yml	2017-12-01 11:39:41.116445	8	EXECUTED	7:559b09db76c3cf619829b2742dbcc924	sqlFile		\N	3.5.3	\N	\N	2128380190
10.49.0-1	Sarah Radford	database/changes/release-10.49.0/changelog.yml	2017-12-01 11:39:41.151667	9	EXECUTED	7:edbfc38b1a5692428c929fc1f6a0bf7c	sqlFile		\N	3.5.3	\N	\N	2128380190
10.49.0-2	Sarah Radford	database/changes/release-10.49.0/changelog.yml	2017-12-01 11:39:41.24099	10	EXECUTED	7:bbc7191cfc976e0c5f0f1445b2617c9a	sqlFile		\N	3.5.3	\N	\N	2128380190
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Name: exercisepkseq; Type: SEQUENCE SET; Schema: collectionexercise; Owner: collectionexercisesvc
--

SELECT pg_catalog.setval('exercisepkseq', 1, false);


--
-- Data for Name: messagelog; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY messagelog (messagelogpk, messagetext, jobid, messagelevel, functionname, createddatetime) FROM stdin;
\.


--
-- Name: messagelogseq; Type: SEQUENCE SET; Schema: collectionexercise; Owner: collectionexercisesvc
--

SELECT pg_catalog.setval('messagelogseq', 1, false);


--
-- Data for Name: report; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY report (id, reportpk, reporttypefk, contents, createddatetime) FROM stdin;
\.


--
-- Name: reportpkseq; Type: SEQUENCE SET; Schema: collectionexercise; Owner: collectionexercisesvc
--

SELECT pg_catalog.setval('reportpkseq', 1, false);


--
-- Data for Name: reporttype; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY reporttype (reporttypepk, displayorder, displayname) FROM stdin;
COLLECTIONEXERCISE	30	Collection Exercise
\.


--
-- Data for Name: samplelink; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY samplelink (collectionexerciseid, samplesummaryid, samplelinkpk) FROM stdin;
\.


--
-- Name: samplelinkpkseq; Type: SEQUENCE SET; Schema: collectionexercise; Owner: collectionexercisesvc
--

SELECT pg_catalog.setval('samplelinkpkseq', 1, false);


--
-- Data for Name: sampleunit; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY sampleunit (sampleunitpk, sampleunitgroupfk, collectioninstrumentid, partyid, sampleunitref, sampleunittypefk) FROM stdin;
\.


--
-- Data for Name: sampleunitgroup; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY sampleunitgroup (sampleunitgrouppk, exercisefk, formtype, statefk, createddatetime, modifieddatetime) FROM stdin;
\.


--
-- Name: sampleunitgrouppkseq; Type: SEQUENCE SET; Schema: collectionexercise; Owner: collectionexercisesvc
--

SELECT pg_catalog.setval('sampleunitgrouppkseq', 1, false);


--
-- Data for Name: sampleunitgroupstate; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY sampleunitgroupstate (statepk) FROM stdin;
INIT
EXECUTED
VALIDATED
PUBLISHED
FAILEDVALIDATION
\.


--
-- Name: sampleunitpkseq; Type: SEQUENCE SET; Schema: collectionexercise; Owner: collectionexercisesvc
--

SELECT pg_catalog.setval('sampleunitpkseq', 1, false);


--
-- Data for Name: sampleunittype; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY sampleunittype (sampleunittypepk) FROM stdin;
B
BI
\.


--
-- Data for Name: survey; Type: TABLE DATA; Schema: collectionexercise; Owner: collectionexercisesvc
--

COPY survey (id, surveypk, surveyref) FROM stdin;
cb0711c3-0ac8-41d3-ae0e-567e5ea1ef87	1	221
\.


SET search_path = iac, pg_catalog;

--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: iac; Owner: postgres
--

COPY databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
9.23.0-1	John Topley	database/changes/release-9.23.0/changelog.yml	2017-12-01 11:39:32.89971	1	EXECUTED	7:8aed45266de0f94932cdd9006defdd9f	sqlFile		\N	3.5.3	\N	\N	2128372810
9.30.0-1	John Topley	database/changes/release-9.30.1/changelog.yml	2017-12-01 11:39:33.066263	2	EXECUTED	7:c74d320bcd79ec9971836f7e0a5315e2	sqlFile		\N	3.5.3	\N	\N	2128372810
9.31.0-1	Chris Hardman, Edward Stevens	database/changes/release-9.31.0/changelog.yml	2017-12-01 11:39:33.095383	3	EXECUTED	7:ad49eb823e17bae300f0c60e5945f6b6	sqlFile		\N	3.5.3	\N	\N	2128372810
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: iac; Owner: postgres
--

COPY databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: iac; Type: TABLE DATA; Schema: iac; Owner: postgres
--

COPY iac (code, active, createddatetime, createdby, updateddatetime, updatedby, lastuseddatetime) FROM stdin;
fb747cq725lj	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
wsycyxw9kn5g	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
h479nl7yx9w2	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
ssn4bqkgn7gl	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
b55swlzgw778	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
4kyznty4fw3s	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
5p9y7rdc3t3q	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
wn9kbtypzth8	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
xmyvjwjvt5yc	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
yr9473tyn7qk	f	2017-12-01 11:39:33.015187+00	Changeset 9.30.1	\N	\N	\N
\.


SET search_path = partysvc, pg_catalog;

--
-- Data for Name: business; Type: TABLE DATA; Schema: partysvc; Owner: postgres
--

COPY business (party_uuid, business_ref, attributes, created_on) FROM stdin;
\.


--
-- Data for Name: business_respondent; Type: TABLE DATA; Schema: partysvc; Owner: postgres
--

COPY business_respondent (business_id, respondent_id, status, effective_from, effective_to, created_on) FROM stdin;
\.


--
-- Data for Name: enrolment; Type: TABLE DATA; Schema: partysvc; Owner: postgres
--

COPY enrolment (business_id, respondent_id, survey_id, survey_name, status, created_on) FROM stdin;
\.


--
-- Data for Name: pending_enrolment; Type: TABLE DATA; Schema: partysvc; Owner: postgres
--

COPY pending_enrolment (id, case_id, respondent_id, business_id, survey_id, created_on) FROM stdin;
\.


--
-- Name: pending_enrolment_id_seq; Type: SEQUENCE SET; Schema: partysvc; Owner: postgres
--

SELECT pg_catalog.setval('pending_enrolment_id_seq', 1, false);


--
-- Data for Name: respondent; Type: TABLE DATA; Schema: partysvc; Owner: postgres
--

COPY respondent (id, party_uuid, status, email_address, first_name, last_name, telephone, created_on) FROM stdin;
\.


--
-- Name: respondent_id_seq; Type: SEQUENCE SET; Schema: partysvc; Owner: postgres
--

SELECT pg_catalog.setval('respondent_id_seq', 1, false);


SET search_path = public, pg_catalog;

--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_group (id, name) FROM stdin;
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_group_id_seq', 1, false);


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_group_permissions_id_seq', 1, false);


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can add permission	2	add_permission
5	Can change permission	2	change_permission
6	Can delete permission	2	delete_permission
7	Can add group	3	add_group
8	Can change group	3	change_group
9	Can delete group	3	delete_group
10	Can add user	4	add_user
11	Can change user	4	change_user
12	Can delete user	4	delete_user
13	Can add content type	5	add_contenttype
14	Can change content type	5	change_contenttype
15	Can delete content type	5	delete_contenttype
16	Can add session	6	add_session
17	Can change session	6	change_session
18	Can delete session	6	delete_session
19	Can add o auth user	7	add_oauthuser
20	Can change o auth user	7	change_oauthuser
21	Can delete o auth user	7	delete_oauthuser
22	Can add o auth client	8	add_oauthclient
23	Can change o auth client	8	change_oauthclient
24	Can delete o auth client	8	delete_oauthclient
25	Can add o auth scope	9	add_oauthscope
26	Can change o auth scope	9	change_oauthscope
27	Can delete o auth scope	9	delete_oauthscope
28	Can add o auth refresh token	10	add_oauthrefreshtoken
29	Can change o auth refresh token	10	change_oauthrefreshtoken
30	Can delete o auth refresh token	10	delete_oauthrefreshtoken
31	Can add o auth access token	11	add_oauthaccesstoken
32	Can change o auth access token	11	change_oauthaccesstoken
33	Can delete o auth access token	11	delete_oauthaccesstoken
34	Can add o auth authorization code	12	add_oauthauthorizationcode
35	Can change o auth authorization code	12	change_oauthauthorizationcode
36	Can delete o auth authorization code	12	delete_oauthauthorizationcode
\.


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_permission_id_seq', 36, true);


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
1	pbkdf2_sha256$24000$vZSUMt7MFzyW$2Wv7VKggLJ/G7N+i+gkgvyIfEy4atRlay9FTNrOs6c0=	\N	f	ons@ons.gov			ons@ons.gov	f	t	2017-12-01 11:38:39.207867+00
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_user_id_seq', 1, true);


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auth_user_user_permissions_id_seq', 1, false);


--
-- Data for Name: credentials_oauthclient; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY credentials_oauthclient (id, password, client_id, redirect_uri) FROM stdin;
1	$2a$12$An0d09N/ZFL3LR1khGNtYOFNlBQy7nlzaB9fi9R8rA4u1IkFvzImK	ons@ons.gov	https://www.ons.gov.uk/
\.


--
-- Name: credentials_oauthclient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('credentials_oauthclient_id_seq', 1, true);


--
-- Data for Name: credentials_oauthuser; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY credentials_oauthuser (id, password, email, failed_logins, account_is_locked, account_is_verified) FROM stdin;
1	$2a$12$xf7ghr2LDskaBBvBrvH1euK83/Qls2TAx49hQpHtfzhayHGHDOCke	testuser@email.com	0	f	t
\.


--
-- Name: credentials_oauthuser_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('credentials_oauthuser_id_seq', 1, true);


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('django_admin_log_id_seq', 1, false);


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	auth	user
5	contenttypes	contenttype
6	sessions	session
7	credentials	oauthuser
8	credentials	oauthclient
9	tokens	oauthscope
10	tokens	oauthrefreshtoken
11	tokens	oauthaccesstoken
12	tokens	oauthauthorizationcode
\.


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('django_content_type_id_seq', 12, true);


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2017-12-01 11:38:35.977121+00
2	auth	0001_initial	2017-12-01 11:38:36.087371+00
3	admin	0001_initial	2017-12-01 11:38:36.129086+00
4	admin	0002_logentry_remove_auto_add	2017-12-01 11:38:36.157465+00
5	contenttypes	0002_remove_content_type_name	2017-12-01 11:38:36.212989+00
6	auth	0002_alter_permission_name_max_length	2017-12-01 11:38:36.234466+00
7	auth	0003_alter_user_email_max_length	2017-12-01 11:38:36.265942+00
8	auth	0004_alter_user_username_opts	2017-12-01 11:38:36.289576+00
9	auth	0005_alter_user_last_login_null	2017-12-01 11:38:36.329006+00
10	auth	0006_require_contenttypes_0002	2017-12-01 11:38:36.332043+00
11	auth	0007_alter_validators_add_error_messages	2017-12-01 11:38:36.349337+00
12	credentials	0001_initial	2017-12-01 11:38:36.404653+00
13	credentials	0002_auto_20170330_1354	2017-12-01 11:38:36.436075+00
14	credentials	0003_oauthuser_failed_logins	2017-12-01 11:38:36.461038+00
15	credentials	0004_oauthuser_account_is_locked	2017-12-01 11:38:36.487522+00
16	credentials	0005_auto_20170407_1111	2017-12-01 11:38:36.565066+00
17	sessions	0001_initial	2017-12-01 11:38:36.602418+00
18	tokens	0001_initial	2017-12-01 11:38:36.850454+00
19	tokens	0002_auto_20170407_1111	2017-12-01 11:38:36.967751+00
\.


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('django_migrations_id_seq', 19, true);


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: tokens_oauthaccesstoken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tokens_oauthaccesstoken (id, expires_at, access_token, client_id, refresh_token_id, user_id) FROM stdin;
\.


--
-- Name: tokens_oauthaccesstoken_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tokens_oauthaccesstoken_id_seq', 1, false);


--
-- Data for Name: tokens_oauthaccesstoken_scopes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tokens_oauthaccesstoken_scopes (id, oauthaccesstoken_id, oauthscope_id) FROM stdin;
\.


--
-- Name: tokens_oauthaccesstoken_scopes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tokens_oauthaccesstoken_scopes_id_seq', 1, false);


--
-- Data for Name: tokens_oauthauthorizationcode; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tokens_oauthauthorizationcode (id, expires_at, code, redirect_uri, client_id, user_id) FROM stdin;
\.


--
-- Name: tokens_oauthauthorizationcode_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tokens_oauthauthorizationcode_id_seq', 1, false);


--
-- Data for Name: tokens_oauthauthorizationcode_scopes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tokens_oauthauthorizationcode_scopes (id, oauthauthorizationcode_id, oauthscope_id) FROM stdin;
\.


--
-- Name: tokens_oauthauthorizationcode_scopes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tokens_oauthauthorizationcode_scopes_id_seq', 1, false);


--
-- Data for Name: tokens_oauthrefreshtoken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tokens_oauthrefreshtoken (id, expires_at, refresh_token) FROM stdin;
\.


--
-- Name: tokens_oauthrefreshtoken_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tokens_oauthrefreshtoken_id_seq', 1, false);


--
-- Data for Name: tokens_oauthscope; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tokens_oauthscope (id, scope, description, is_default) FROM stdin;
\.


--
-- Name: tokens_oauthscope_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tokens_oauthscope_id_seq', 1, false);


SET search_path = ras_ci, pg_catalog;

--
-- Data for Name: business; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY business (id, ru_ref) FROM stdin;
\.


--
-- Name: business_id_seq; Type: SEQUENCE SET; Schema: ras_ci; Owner: postgres
--

SELECT pg_catalog.setval('business_id_seq', 1, false);


--
-- Data for Name: classification; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY classification (id, instrument_id, kind, value) FROM stdin;
\.


--
-- Name: classification_id_seq; Type: SEQUENCE SET; Schema: ras_ci; Owner: postgres
--

SELECT pg_catalog.setval('classification_id_seq', 1, false);


--
-- Data for Name: exercise; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY exercise (id, exercise_id, items, status) FROM stdin;
\.


--
-- Name: exercise_id_seq; Type: SEQUENCE SET; Schema: ras_ci; Owner: postgres
--

SELECT pg_catalog.setval('exercise_id_seq', 1, false);


--
-- Data for Name: instrument; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY instrument (id, instrument_id, data, len, stamp, survey_id) FROM stdin;
\.


--
-- Data for Name: instrument_business; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY instrument_business (instrument_id, business_id) FROM stdin;
\.


--
-- Data for Name: instrument_exercise; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY instrument_exercise (instrument_id, exercise_id) FROM stdin;
\.


--
-- Name: instrument_id_seq; Type: SEQUENCE SET; Schema: ras_ci; Owner: postgres
--

SELECT pg_catalog.setval('instrument_id_seq', 1, false);


--
-- Data for Name: survey; Type: TABLE DATA; Schema: ras_ci; Owner: postgres
--

COPY survey (id, survey_id) FROM stdin;
\.


--
-- Name: survey_id_seq; Type: SEQUENCE SET; Schema: ras_ci; Owner: postgres
--

SELECT pg_catalog.setval('survey_id_seq', 1, false);


SET search_path = sample, pg_catalog;

--
-- Data for Name: collectionexercisejob; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY collectionexercisejob (collectionexercisejobpk, collectionexerciseid, surveyref, exercisedatetime, createddatetime, samplesummaryid) FROM stdin;
\.


--
-- Name: collectionexercisejobseq; Type: SEQUENCE SET; Schema: sample; Owner: samplesvc
--

SELECT pg_catalog.setval('collectionexercisejobseq', 1, false);


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
9.39.0-1	Narinder Birk	database/changes/release-9.39.0/changelog.yml	2017-12-01 11:39:55.382105	1	EXECUTED	7:6afa162d0070b88dadc35457136e9e83	sqlFile		\N	3.5.3	\N	\N	2128395170
9.39.0-2	Narinder Birk	database/changes/release-9.39.0/changelog.yml	2017-12-01 11:39:55.439687	2	EXECUTED	7:4ad80928e62a5579cf15e2f2dfba9940	sqlFile		\N	3.5.3	\N	\N	2128395170
10.43.1	Kieran Wardle	database/changes/release-10.43.0/changelog.yml	2017-12-01 11:39:55.454954	3	EXECUTED	7:8c4084e8becbc263e346e86be6094098	sqlFile		\N	3.5.3	\N	\N	2128395170
10.45.0-1	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:55.510339	4	EXECUTED	7:058cea246265e1cc252fb1b539211646	sqlFile		\N	3.5.3	\N	\N	2128395170
10.45.0-2	Sarah Radford	database/changes/release-10.45.0/changelog.yml	2017-12-01 11:39:55.529891	5	EXECUTED	7:5a68c24a9ed96183a06c3b71e41c8bab	sqlFile		\N	3.5.3	\N	\N	2128395170
10.46.0-1	Sarah Radford	database/changes/release-10.46.0/changelog.yml	2017-12-01 11:39:55.662009	6	EXECUTED	7:cd0f431997b6531bc49f5ca7bb4e871c	sqlFile		\N	3.5.3	\N	\N	2128395170
10.49.0-1	Sarah Radford	database/changes/release-10.49.0/changelog.yml	2017-12-01 11:41:54.190897	7	EXECUTED	7:b8f0c2df73584e8ed4e5bda477f592af	sqlFile		\N	3.5.3	\N	\N	2128514130
10.49.0-2	Kieran Wardle	database/changes/release-10.49.0/changelog.yml	2017-12-01 11:41:54.207267	8	EXECUTED	7:8f841cf4bdfcefb9ae76c037c11e1893	sqlFile		\N	3.5.3	\N	\N	2128514130
10.49.0-3	Edward Stevens	database/changes/release-10.49.0/changelog.yml	2017-12-01 11:41:54.224386	9	EXECUTED	7:ce49882d69211ef1bac74ac847d62e35	sqlFile		\N	3.5.3	\N	\N	2128514130
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: messagelog; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY messagelog (messagelogpk, messagetext, jobid, messagelevel, functionname, createddatetime) FROM stdin;
\.


--
-- Name: messagelogseq; Type: SEQUENCE SET; Schema: sample; Owner: samplesvc
--

SELECT pg_catalog.setval('messagelogseq', 1, false);


--
-- Data for Name: report; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY report (id, reportpk, reporttypefk, contents, createddatetime) FROM stdin;
\.


--
-- Name: reportpkseq; Type: SEQUENCE SET; Schema: sample; Owner: samplesvc
--

SELECT pg_catalog.setval('reportpkseq', 1, false);


--
-- Data for Name: reporttype; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY reporttype (reporttypepk, displayorder, displayname) FROM stdin;
SAMPLE	20	Sample Units
\.


--
-- Data for Name: samplesummary; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY samplesummary (samplesummarypk, statefk, ingestdatetime, id, description) FROM stdin;
\.


--
-- Name: samplesummaryseq; Type: SEQUENCE SET; Schema: sample; Owner: samplesvc
--

SELECT pg_catalog.setval('samplesummaryseq', 1, false);


--
-- Data for Name: samplesummarystate; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY samplesummarystate (statepk) FROM stdin;
INIT
ACTIVE
\.


--
-- Data for Name: sampleunit; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY sampleunit (sampleunitpk, samplesummaryfk, sampleunitref, sampleunittype, formtype, statefk, id) FROM stdin;
\.


--
-- Name: sampleunitseq; Type: SEQUENCE SET; Schema: sample; Owner: samplesvc
--

SELECT pg_catalog.setval('sampleunitseq', 1, false);


--
-- Data for Name: sampleunitstate; Type: TABLE DATA; Schema: sample; Owner: samplesvc
--

COPY sampleunitstate (statepk) FROM stdin;
INIT
DELIVERED
PERSISTED
\.


SET search_path = survey, pg_catalog;

--
-- Data for Name: classifiertype; Type: TABLE DATA; Schema: survey; Owner: postgres
--

COPY classifiertype (classifiertypepk, classifiertypeselectorfk, classifiertype) FROM stdin;
1	1	COLLECTION_EXERCISE
2	1	RU_REF
3	2	LEGAL_BASIS
\.


--
-- Name: classifiertype_classifiertypepk_seq; Type: SEQUENCE SET; Schema: survey; Owner: postgres
--

SELECT pg_catalog.setval('classifiertype_classifiertypepk_seq', 1, false);


--
-- Data for Name: classifiertypeselector; Type: TABLE DATA; Schema: survey; Owner: postgres
--

COPY classifiertypeselector (classifiertypeselectorpk, id, surveyfk, classifiertypeselector) FROM stdin;
1	efa868fb-fb80-44c7-9f33-d6800a17c4da	1	COLLECTION_INSTRUMENT
2	e119ffd6-6fc1-426c-ae81-67a96f9a71ba	1	COMMUNICATION_TEMPLATE
\.


--
-- Name: classifiertypeselector_classifiertypeselectorpk_seq; Type: SEQUENCE SET; Schema: survey; Owner: postgres
--

SELECT pg_catalog.setval('classifiertypeselector_classifiertypeselectorpk_seq', 1, false);


--
-- Data for Name: survey; Type: TABLE DATA; Schema: survey; Owner: postgres
--

COPY survey (surveypk, id, shortname, longname, surveyref) FROM stdin;
1	cb0711c3-0ac8-41d3-ae0e-567e5ea1ef87	BRES	Business Register and Employment Survey	221
\.


--
-- Name: survey_surveypk_seq; Type: SEQUENCE SET; Schema: survey; Owner: postgres
--

SELECT pg_catalog.setval('survey_surveypk_seq', 1, false);


SET search_path = action, pg_catalog;

--
-- Name: action actionid_uuid_key; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY action
    ADD CONSTRAINT actionid_uuid_key UNIQUE (id);


--
-- Name: action actionpk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY action
    ADD CONSTRAINT actionpk_pkey PRIMARY KEY (actionpk);


--
-- Name: actionplan actionplanid_uuid_key; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplan
    ADD CONSTRAINT actionplanid_uuid_key UNIQUE (id);


--
-- Name: actionplanjob actionplanjobid_uuid_key; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplanjob
    ADD CONSTRAINT actionplanjobid_uuid_key UNIQUE (id);


--
-- Name: actionplanjob actionplanjobpk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplanjob
    ADD CONSTRAINT actionplanjobpk_pkey PRIMARY KEY (actionplanjobpk);


--
-- Name: actionplan actionplanpk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplan
    ADD CONSTRAINT actionplanpk_pkey PRIMARY KEY (actionplanpk);


--
-- Name: actionrule actionrulepk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionrule
    ADD CONSTRAINT actionrulepk_pkey PRIMARY KEY (actionrulepk);


--
-- Name: actionstate actionstatepk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionstate
    ADD CONSTRAINT actionstatepk_pkey PRIMARY KEY (statepk);


--
-- Name: actiontype actiontypepk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actiontype
    ADD CONSTRAINT actiontypepk_pkey PRIMARY KEY (actiontypepk);


--
-- Name: case caseid_uuid_key; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT caseid_uuid_key UNIQUE (id);


--
-- Name: case casepk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT casepk_pkey PRIMARY KEY (casepk);


--
-- Name: messagelog messagepk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY messagelog
    ADD CONSTRAINT messagepk_pkey PRIMARY KEY (messagepk);


--
-- Name: actionplan name_key; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplan
    ADD CONSTRAINT name_key UNIQUE (name);


--
-- Name: outcomecategory outcomecategory_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY outcomecategory
    ADD CONSTRAINT outcomecategory_pkey PRIMARY KEY (handlerpk, actionoutcomepk);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_pkey PRIMARY KEY (reportpk);


--
-- Name: report report_uuid_key; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_uuid_key UNIQUE (id);


--
-- Name: reporttype reporttype_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY reporttype
    ADD CONSTRAINT reporttype_pkey PRIMARY KEY (reporttypepk);


--
-- Name: actionplanjobstate statepk_pkey; Type: CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplanjobstate
    ADD CONSTRAINT statepk_pkey PRIMARY KEY (statepk);


SET search_path = actionexporter, pg_catalog;

--
-- Name: actionrequest actionrequestpk_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY actionrequest
    ADD CONSTRAINT actionrequestpk_pkey PRIMARY KEY (actionrequestpk);


--
-- Name: templatemapping actiontypenamepk_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY templatemapping
    ADD CONSTRAINT actiontypenamepk_pkey PRIMARY KEY (actiontypenamepk);


--
-- Name: contact contactpk_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY contact
    ADD CONSTRAINT contactpk_pkey PRIMARY KEY (contactpk);


--
-- Name: messagelog messagepk_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY messagelog
    ADD CONSTRAINT messagepk_pkey PRIMARY KEY (messagepk);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_pkey PRIMARY KEY (reportpk);


--
-- Name: report report_uuid_key; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_uuid_key UNIQUE (id);


--
-- Name: reporttype reporttype_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY reporttype
    ADD CONSTRAINT reporttype_pkey PRIMARY KEY (reporttypepk);


--
-- Name: address sampleunitrefpk_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY address
    ADD CONSTRAINT sampleunitrefpk_pkey PRIMARY KEY (sampleunitrefpk);


--
-- Name: template templetenamepk_pkey; Type: CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY template
    ADD CONSTRAINT templetenamepk_pkey PRIMARY KEY (templatenamepk);


SET search_path = casesvc, pg_catalog;

--
-- Name: case case_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT case_pkey PRIMARY KEY (casepk);


--
-- Name: case case_uuid_key; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT case_uuid_key UNIQUE (id);


--
-- Name: caseevent caseevent_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY caseevent
    ADD CONSTRAINT caseevent_pkey PRIMARY KEY (caseeventpk);


--
-- Name: casegroup casegroup_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY casegroup
    ADD CONSTRAINT casegroup_pkey PRIMARY KEY (casegrouppk);


--
-- Name: casegroup casegroup_uuid_key; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY casegroup
    ADD CONSTRAINT casegroup_uuid_key UNIQUE (id);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY category
    ADD CONSTRAINT category_pkey PRIMARY KEY (categorypk);


--
-- Name: messagelog messagelogpk_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY messagelog
    ADD CONSTRAINT messagelogpk_pkey PRIMARY KEY (messagelogpk);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_pkey PRIMARY KEY (reportpk);


--
-- Name: report report_uuid_key; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_uuid_key UNIQUE (id);


--
-- Name: reporttype reporttype_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY reporttype
    ADD CONSTRAINT reporttype_pkey PRIMARY KEY (reporttypepk);


--
-- Name: response response_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY response
    ADD CONSTRAINT response_pkey PRIMARY KEY (responsepk);


--
-- Name: casestate state_pkey; Type: CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY casestate
    ADD CONSTRAINT state_pkey PRIMARY KEY (statepk);


SET search_path = collectionexercise, pg_catalog;

--
-- Name: casetypedefault casetypedefaultpk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY casetypedefault
    ADD CONSTRAINT casetypedefaultpk_pkey PRIMARY KEY (casetypedefaultpk);


--
-- Name: casetypeoverride casetypeoverridepk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY casetypeoverride
    ADD CONSTRAINT casetypeoverridepk_pkey PRIMARY KEY (casetypeoverridepk);


--
-- Name: collectionexercise ce_id_uuid_key; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY collectionexercise
    ADD CONSTRAINT ce_id_uuid_key UNIQUE (id);


--
-- Name: collectionexercisestate collectionexercise_statepk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY collectionexercisestate
    ADD CONSTRAINT collectionexercise_statepk_pkey PRIMARY KEY (statepk);


--
-- Name: collectionexercise exercisepk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY collectionexercise
    ADD CONSTRAINT exercisepk_pkey PRIMARY KEY (exercisepk);


--
-- Name: messagelog messagelogpk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY messagelog
    ADD CONSTRAINT messagelogpk_pkey PRIMARY KEY (messagelogpk);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_pkey PRIMARY KEY (reportpk);


--
-- Name: report report_uuid_key; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_uuid_key UNIQUE (id);


--
-- Name: reporttype reporttype_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY reporttype
    ADD CONSTRAINT reporttype_pkey PRIMARY KEY (reporttypepk);


--
-- Name: samplelink samplelinkpk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY samplelink
    ADD CONSTRAINT samplelinkpk_pkey PRIMARY KEY (samplelinkpk);


--
-- Name: sampleunitgroupstate sampleunitgroup_statepk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunitgroupstate
    ADD CONSTRAINT sampleunitgroup_statepk_pkey PRIMARY KEY (statepk);


--
-- Name: sampleunitgroup sampleunitgrouppk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunitgroup
    ADD CONSTRAINT sampleunitgrouppk_pkey PRIMARY KEY (sampleunitgrouppk);


--
-- Name: sampleunit sampleunitpk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT sampleunitpk_pkey PRIMARY KEY (sampleunitpk);


--
-- Name: sampleunittype sampleunittypepk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunittype
    ADD CONSTRAINT sampleunittypepk_pkey PRIMARY KEY (sampleunittypepk);


--
-- Name: survey survey_id_uuid_key; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY survey
    ADD CONSTRAINT survey_id_uuid_key UNIQUE (id);


--
-- Name: survey surveypk_pkey; Type: CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY survey
    ADD CONSTRAINT surveypk_pkey PRIMARY KEY (surveypk);


SET search_path = iac, pg_catalog;

--
-- Name: iac code_pkey; Type: CONSTRAINT; Schema: iac; Owner: postgres
--

ALTER TABLE ONLY iac
    ADD CONSTRAINT code_pkey PRIMARY KEY (code);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: iac; Owner: postgres
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


SET search_path = partysvc, pg_catalog;

--
-- Name: business business_business_ref_key; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY business
    ADD CONSTRAINT business_business_ref_key UNIQUE (business_ref);


--
-- Name: business business_pkey; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY business
    ADD CONSTRAINT business_pkey PRIMARY KEY (party_uuid);


--
-- Name: business_respondent business_respondent_pkey; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY business_respondent
    ADD CONSTRAINT business_respondent_pkey PRIMARY KEY (business_id, respondent_id);


--
-- Name: enrolment enrolment_pkey; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY enrolment
    ADD CONSTRAINT enrolment_pkey PRIMARY KEY (business_id, respondent_id, survey_id);


--
-- Name: pending_enrolment pending_enrolment_pkey; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY pending_enrolment
    ADD CONSTRAINT pending_enrolment_pkey PRIMARY KEY (id);


--
-- Name: respondent respondent_email_address_key; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY respondent
    ADD CONSTRAINT respondent_email_address_key UNIQUE (email_address);


--
-- Name: respondent respondent_party_uuid_key; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY respondent
    ADD CONSTRAINT respondent_party_uuid_key UNIQUE (party_uuid);


--
-- Name: respondent respondent_pkey; Type: CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY respondent
    ADD CONSTRAINT respondent_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_user_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: credentials_oauthclient credentials_oauthclient_client_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY credentials_oauthclient
    ADD CONSTRAINT credentials_oauthclient_client_id_key UNIQUE (client_id);


--
-- Name: credentials_oauthclient credentials_oauthclient_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY credentials_oauthclient
    ADD CONSTRAINT credentials_oauthclient_pkey PRIMARY KEY (id);


--
-- Name: credentials_oauthuser credentials_oauthuser_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY credentials_oauthuser
    ADD CONSTRAINT credentials_oauthuser_email_key UNIQUE (email);


--
-- Name: credentials_oauthuser credentials_oauthuser_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY credentials_oauthuser
    ADD CONSTRAINT credentials_oauthuser_pkey PRIMARY KEY (id);


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_app_label_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: tokens_oauthaccesstoken tokens_oauthaccesstoken_access_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken
    ADD CONSTRAINT tokens_oauthaccesstoken_access_token_key UNIQUE (access_token);


--
-- Name: tokens_oauthaccesstoken tokens_oauthaccesstoken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken
    ADD CONSTRAINT tokens_oauthaccesstoken_pkey PRIMARY KEY (id);


--
-- Name: tokens_oauthaccesstoken tokens_oauthaccesstoken_refresh_token_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken
    ADD CONSTRAINT tokens_oauthaccesstoken_refresh_token_id_key UNIQUE (refresh_token_id);


--
-- Name: tokens_oauthaccesstoken_scopes tokens_oauthaccesstoken_scope_oauthaccesstoken_id_1497353e_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken_scopes
    ADD CONSTRAINT tokens_oauthaccesstoken_scope_oauthaccesstoken_id_1497353e_uniq UNIQUE (oauthaccesstoken_id, oauthscope_id);


--
-- Name: tokens_oauthaccesstoken_scopes tokens_oauthaccesstoken_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken_scopes
    ADD CONSTRAINT tokens_oauthaccesstoken_scopes_pkey PRIMARY KEY (id);


--
-- Name: tokens_oauthauthorizationcode_scopes tokens_oauthauthorizati_oauthauthorizationcode_id_28200133_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode_scopes
    ADD CONSTRAINT tokens_oauthauthorizati_oauthauthorizationcode_id_28200133_uniq UNIQUE (oauthauthorizationcode_id, oauthscope_id);


--
-- Name: tokens_oauthauthorizationcode tokens_oauthauthorizationcode_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode
    ADD CONSTRAINT tokens_oauthauthorizationcode_code_key UNIQUE (code);


--
-- Name: tokens_oauthauthorizationcode tokens_oauthauthorizationcode_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode
    ADD CONSTRAINT tokens_oauthauthorizationcode_pkey PRIMARY KEY (id);


--
-- Name: tokens_oauthauthorizationcode_scopes tokens_oauthauthorizationcode_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode_scopes
    ADD CONSTRAINT tokens_oauthauthorizationcode_scopes_pkey PRIMARY KEY (id);


--
-- Name: tokens_oauthrefreshtoken tokens_oauthrefreshtoken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthrefreshtoken
    ADD CONSTRAINT tokens_oauthrefreshtoken_pkey PRIMARY KEY (id);


--
-- Name: tokens_oauthrefreshtoken tokens_oauthrefreshtoken_refresh_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthrefreshtoken
    ADD CONSTRAINT tokens_oauthrefreshtoken_refresh_token_key UNIQUE (refresh_token);


--
-- Name: tokens_oauthscope tokens_oauthscope_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthscope
    ADD CONSTRAINT tokens_oauthscope_pkey PRIMARY KEY (id);


--
-- Name: tokens_oauthscope tokens_oauthscope_scope_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthscope
    ADD CONSTRAINT tokens_oauthscope_scope_key UNIQUE (scope);


SET search_path = ras_ci, pg_catalog;

--
-- Name: business business_pkey; Type: CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY business
    ADD CONSTRAINT business_pkey PRIMARY KEY (id);


--
-- Name: classification classification_pkey; Type: CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY classification
    ADD CONSTRAINT classification_pkey PRIMARY KEY (id);


--
-- Name: exercise exercise_pkey; Type: CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY exercise
    ADD CONSTRAINT exercise_pkey PRIMARY KEY (id);


--
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (id);


--
-- Name: survey survey_pkey; Type: CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY survey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (id);


SET search_path = sample, pg_catalog;

--
-- Name: collectionexercisejob collectionexercisejob_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY collectionexercisejob
    ADD CONSTRAINT collectionexercisejob_pkey PRIMARY KEY (collectionexercisejobpk);


--
-- Name: messagelog messagelogpk_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY messagelog
    ADD CONSTRAINT messagelogpk_pkey PRIMARY KEY (messagelogpk);


--
-- Name: databasechangeloglock pk_databasechangeloglock; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY databasechangeloglock
    ADD CONSTRAINT pk_databasechangeloglock PRIMARY KEY (id);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_pkey PRIMARY KEY (reportpk);


--
-- Name: report report_uuid_key; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT report_uuid_key UNIQUE (id);


--
-- Name: reporttype reporttype_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY reporttype
    ADD CONSTRAINT reporttype_pkey PRIMARY KEY (reporttypepk);


--
-- Name: samplesummary samplesummary_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY samplesummary
    ADD CONSTRAINT samplesummary_pkey PRIMARY KEY (samplesummarypk);


--
-- Name: samplesummary samplesummary_uuid_key; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY samplesummary
    ADD CONSTRAINT samplesummary_uuid_key UNIQUE (id);


--
-- Name: samplesummarystate samplesummarystate_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY samplesummarystate
    ADD CONSTRAINT samplesummarystate_pkey PRIMARY KEY (statepk);


--
-- Name: sampleunit sampleunit_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT sampleunit_pkey PRIMARY KEY (sampleunitpk);


--
-- Name: sampleunit sampleunit_uuid_key; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT sampleunit_uuid_key UNIQUE (id);


--
-- Name: sampleunitstate sampleunitstate_pkey; Type: CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY sampleunitstate
    ADD CONSTRAINT sampleunitstate_pkey PRIMARY KEY (statepk);


SET search_path = survey, pg_catalog;

--
-- Name: classifiertype classifiertype_pkey; Type: CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertype
    ADD CONSTRAINT classifiertype_pkey PRIMARY KEY (classifiertypepk);


--
-- Name: classifiertypeselector classifiertypeselector_id_key; Type: CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertypeselector
    ADD CONSTRAINT classifiertypeselector_id_key UNIQUE (id);


--
-- Name: classifiertypeselector classifiertypeselector_pkey; Type: CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertypeselector
    ADD CONSTRAINT classifiertypeselector_pkey PRIMARY KEY (classifiertypeselectorpk);


--
-- Name: survey survey_id_key; Type: CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY survey
    ADD CONSTRAINT survey_id_key UNIQUE (id);


--
-- Name: survey survey_pkey; Type: CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY survey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (surveypk);


SET search_path = action, pg_catalog;

--
-- Name: action_actionplanfk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX action_actionplanfk_index ON action USING btree (actionplanfk);


--
-- Name: action_actionrulefk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX action_actionrulefk_index ON action USING btree (actionrulefk);


--
-- Name: action_actiontypefk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX action_actiontypefk_index ON action USING btree (actiontypefk);


--
-- Name: action_optlockversion_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX action_optlockversion_index ON action USING btree (optlockversion);


--
-- Name: action_statefk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX action_statefk_index ON action USING btree (statefk);


--
-- Name: actionplanjob_actionplanfk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX actionplanjob_actionplanfk_index ON actionplanjob USING btree (actionplanfk);


--
-- Name: actionplanjob_statefk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX actionplanjob_statefk_index ON actionplanjob USING btree (statefk);


--
-- Name: actionrule_actionplanfk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX actionrule_actionplanfk_index ON actionrule USING btree (actionplanfk);


--
-- Name: actionrule_actiontypefk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX actionrule_actiontypefk_index ON actionrule USING btree (actiontypefk);


--
-- Name: actiontype_name_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX actiontype_name_index ON actiontype USING btree (name);


--
-- Name: case_actionplanfk_index; Type: INDEX; Schema: action; Owner: actionsvc
--

CREATE INDEX case_actionplanfk_index ON "case" USING btree (actionplanfk);


SET search_path = actionexporter, pg_catalog;

--
-- Name: actionrequest_contactfk_index; Type: INDEX; Schema: actionexporter; Owner: actionexportersvc
--

CREATE INDEX actionrequest_contactfk_index ON actionrequest USING btree (contactfk);


--
-- Name: actionrequest_sampleunitreffk_index; Type: INDEX; Schema: actionexporter; Owner: actionexportersvc
--

CREATE INDEX actionrequest_sampleunitreffk_index ON actionrequest USING btree (sampleunitreffk);


--
-- Name: templatemapping_templatenamefk_index; Type: INDEX; Schema: actionexporter; Owner: actionexportersvc
--

CREATE INDEX templatemapping_templatenamefk_index ON templatemapping USING btree (templatenamefk);


SET search_path = casesvc, pg_catalog;

--
-- Name: case_casegroupfk_index; Type: INDEX; Schema: casesvc; Owner: casesvc
--

CREATE INDEX case_casegroupfk_index ON "case" USING btree (casegroupfk);


--
-- Name: case_state_index; Type: INDEX; Schema: casesvc; Owner: casesvc
--

CREATE INDEX case_state_index ON "case" USING btree (statefk);


--
-- Name: caseevent_casefk_index; Type: INDEX; Schema: casesvc; Owner: casesvc
--

CREATE INDEX caseevent_casefk_index ON caseevent USING btree (casefk);


--
-- Name: caseevent_categoryfk_index; Type: INDEX; Schema: casesvc; Owner: casesvc
--

CREATE INDEX caseevent_categoryfk_index ON caseevent USING btree (categoryfk);


--
-- Name: response_casefk_index; Type: INDEX; Schema: casesvc; Owner: casesvc
--

CREATE INDEX response_casefk_index ON response USING btree (casefk);


SET search_path = collectionexercise, pg_catalog;

--
-- Name: collectionexercise_statefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX collectionexercise_statefk_index ON collectionexercise USING btree (statefk);


--
-- Name: collectionexercise_surveyfk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX collectionexercise_surveyfk_index ON collectionexercise USING btree (surveyfk);


--
-- Name: ctd_sampleunittypefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX ctd_sampleunittypefk_index ON casetypedefault USING btree (sampleunittypefk);


--
-- Name: ctd_surveyfk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX ctd_surveyfk_index ON casetypedefault USING btree (surveyfk);


--
-- Name: cto_exercisefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX cto_exercisefk_index ON casetypeoverride USING btree (exercisefk);


--
-- Name: cto_sampleunittypefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX cto_sampleunittypefk_index ON casetypeoverride USING btree (sampleunittypefk);


--
-- Name: sampleunit_sampleunitgroupfk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX sampleunit_sampleunitgroupfk_index ON sampleunit USING btree (sampleunitgroupfk);


--
-- Name: sampleunit_sampleunittypefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX sampleunit_sampleunittypefk_index ON sampleunit USING btree (sampleunittypefk);


--
-- Name: sampleunitgroup_exercisefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX sampleunitgroup_exercisefk_index ON sampleunitgroup USING btree (exercisefk);


--
-- Name: sampleunitgroup_statefk_index; Type: INDEX; Schema: collectionexercise; Owner: collectionexercisesvc
--

CREATE INDEX sampleunitgroup_statefk_index ON sampleunitgroup USING btree (statefk);


SET search_path = public, pg_catalog;

--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_name_a6ea08ec_like ON auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_0e939a4f ON auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_8373b171; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_8373b171 ON auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_417f1b1c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_permission_417f1b1c ON auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_0e939a4f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_groups_0e939a4f ON auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_groups_e8701ad4 ON auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_8373b171; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_8373b171 ON auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_e8701ad4 ON auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_username_6821ab7c_like ON auth_user USING btree (username varchar_pattern_ops);


--
-- Name: credentials_oauthclient_client_id_270ae079_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX credentials_oauthclient_client_id_270ae079_like ON credentials_oauthclient USING btree (client_id varchar_pattern_ops);


--
-- Name: credentials_oauthuser_email_3d9493c5_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX credentials_oauthuser_email_3d9493c5_like ON credentials_oauthuser USING btree (email varchar_pattern_ops);


--
-- Name: django_admin_log_417f1b1c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_admin_log_417f1b1c ON django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_admin_log_e8701ad4 ON django_admin_log USING btree (user_id);


--
-- Name: django_session_de54fa62; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_de54fa62 ON django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_session_key_c0390e0f_like ON django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: tokens_oauthaccesstoken_2bfe9d72; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthaccesstoken_2bfe9d72 ON tokens_oauthaccesstoken USING btree (client_id);


--
-- Name: tokens_oauthaccesstoken_access_token_0ca96316_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthaccesstoken_access_token_0ca96316_like ON tokens_oauthaccesstoken USING btree (access_token varchar_pattern_ops);


--
-- Name: tokens_oauthaccesstoken_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthaccesstoken_e8701ad4 ON tokens_oauthaccesstoken USING btree (user_id);


--
-- Name: tokens_oauthaccesstoken_scopes_6e643d1e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthaccesstoken_scopes_6e643d1e ON tokens_oauthaccesstoken_scopes USING btree (oauthscope_id);


--
-- Name: tokens_oauthaccesstoken_scopes_713369b6; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthaccesstoken_scopes_713369b6 ON tokens_oauthaccesstoken_scopes USING btree (oauthaccesstoken_id);


--
-- Name: tokens_oauthauthorizationcode_2bfe9d72; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthauthorizationcode_2bfe9d72 ON tokens_oauthauthorizationcode USING btree (client_id);


--
-- Name: tokens_oauthauthorizationcode_code_36706cec_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthauthorizationcode_code_36706cec_like ON tokens_oauthauthorizationcode USING btree (code varchar_pattern_ops);


--
-- Name: tokens_oauthauthorizationcode_e8701ad4; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthauthorizationcode_e8701ad4 ON tokens_oauthauthorizationcode USING btree (user_id);


--
-- Name: tokens_oauthauthorizationcode_scopes_6e643d1e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthauthorizationcode_scopes_6e643d1e ON tokens_oauthauthorizationcode_scopes USING btree (oauthscope_id);


--
-- Name: tokens_oauthauthorizationcode_scopes_9050429e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthauthorizationcode_scopes_9050429e ON tokens_oauthauthorizationcode_scopes USING btree (oauthauthorizationcode_id);


--
-- Name: tokens_oauthrefreshtoken_refresh_token_c8ea33b6_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthrefreshtoken_refresh_token_c8ea33b6_like ON tokens_oauthrefreshtoken USING btree (refresh_token varchar_pattern_ops);


--
-- Name: tokens_oauthscope_scope_3bf35d98_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tokens_oauthscope_scope_3bf35d98_like ON tokens_oauthscope USING btree (scope varchar_pattern_ops);


SET search_path = ras_ci, pg_catalog;

--
-- Name: ix_business_ru_ref; Type: INDEX; Schema: ras_ci; Owner: postgres
--

CREATE INDEX ix_business_ru_ref ON business USING btree (ru_ref);


--
-- Name: ix_exercise_exercise_id; Type: INDEX; Schema: ras_ci; Owner: postgres
--

CREATE INDEX ix_exercise_exercise_id ON exercise USING btree (exercise_id);


--
-- Name: ix_instrument_instrument_id; Type: INDEX; Schema: ras_ci; Owner: postgres
--

CREATE INDEX ix_instrument_instrument_id ON instrument USING btree (instrument_id);


--
-- Name: ix_survey_survey_id; Type: INDEX; Schema: ras_ci; Owner: postgres
--

CREATE INDEX ix_survey_survey_id ON survey USING btree (survey_id);


SET search_path = sample, pg_catalog;

--
-- Name: samplesummary_statefk_index; Type: INDEX; Schema: sample; Owner: samplesvc
--

CREATE INDEX samplesummary_statefk_index ON samplesummary USING btree (statefk);


--
-- Name: sampleunit_samplesummaryfk_index; Type: INDEX; Schema: sample; Owner: samplesvc
--

CREATE INDEX sampleunit_samplesummaryfk_index ON sampleunit USING btree (samplesummaryfk);


--
-- Name: sampleunit_statefk_index; Type: INDEX; Schema: sample; Owner: samplesvc
--

CREATE INDEX sampleunit_statefk_index ON sampleunit USING btree (statefk);


SET search_path = action, pg_catalog;

--
-- Name: actionplanjob actionplanfk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplanjob
    ADD CONSTRAINT actionplanfk_fkey FOREIGN KEY (actionplanfk) REFERENCES actionplan(actionplanpk);


--
-- Name: action actionplanfk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY action
    ADD CONSTRAINT actionplanfk_fkey FOREIGN KEY (actionplanfk) REFERENCES actionplan(actionplanpk);


--
-- Name: actionrule actionplanfk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionrule
    ADD CONSTRAINT actionplanfk_fkey FOREIGN KEY (actionplanfk) REFERENCES actionplan(actionplanpk);


--
-- Name: case actionplanfk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT actionplanfk_fkey FOREIGN KEY (actionplanfk) REFERENCES actionplan(actionplanpk);


--
-- Name: actionplanjob actionplanjobstate_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionplanjob
    ADD CONSTRAINT actionplanjobstate_fkey FOREIGN KEY (statefk) REFERENCES actionplanjobstate(statepk);


--
-- Name: action actionrulefk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY action
    ADD CONSTRAINT actionrulefk_fkey FOREIGN KEY (actionrulefk) REFERENCES actionrule(actionrulepk);


--
-- Name: action actionstatefk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY action
    ADD CONSTRAINT actionstatefk_fkey FOREIGN KEY (statefk) REFERENCES actionstate(statepk);


--
-- Name: action actiontypefk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY action
    ADD CONSTRAINT actiontypefk_fkey FOREIGN KEY (actiontypefk) REFERENCES actiontype(actiontypepk);


--
-- Name: actionrule actiontypefk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY actionrule
    ADD CONSTRAINT actiontypefk_fkey FOREIGN KEY (actiontypefk) REFERENCES actiontype(actiontypepk);


--
-- Name: report reporttypefk_fkey; Type: FK CONSTRAINT; Schema: action; Owner: actionsvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT reporttypefk_fkey FOREIGN KEY (reporttypefk) REFERENCES reporttype(reporttypepk);


SET search_path = actionexporter, pg_catalog;

--
-- Name: actionrequest contactfk_fkey; Type: FK CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY actionrequest
    ADD CONSTRAINT contactfk_fkey FOREIGN KEY (contactfk) REFERENCES contact(contactpk);


--
-- Name: report reporttypefk_fkey; Type: FK CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT reporttypefk_fkey FOREIGN KEY (reporttypefk) REFERENCES reporttype(reporttypepk);


--
-- Name: actionrequest sampleunitreffk_fkey; Type: FK CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY actionrequest
    ADD CONSTRAINT sampleunitreffk_fkey FOREIGN KEY (sampleunitreffk) REFERENCES address(sampleunitrefpk);


--
-- Name: templatemapping templatenamefk_fkey; Type: FK CONSTRAINT; Schema: actionexporter; Owner: actionexportersvc
--

ALTER TABLE ONLY templatemapping
    ADD CONSTRAINT templatenamefk_fkey FOREIGN KEY (templatenamefk) REFERENCES template(templatenamepk);


SET search_path = casesvc, pg_catalog;

--
-- Name: caseevent case_fkey; Type: FK CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY caseevent
    ADD CONSTRAINT case_fkey FOREIGN KEY (casefk) REFERENCES "case"(casepk);


--
-- Name: response case_fkey; Type: FK CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY response
    ADD CONSTRAINT case_fkey FOREIGN KEY (casefk) REFERENCES "case"(casepk);


--
-- Name: case casegroup_fkey; Type: FK CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT casegroup_fkey FOREIGN KEY (casegroupfk) REFERENCES casegroup(casegrouppk);


--
-- Name: caseevent category_fkey; Type: FK CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY caseevent
    ADD CONSTRAINT category_fkey FOREIGN KEY (categoryfk) REFERENCES category(categorypk);


--
-- Name: report reporttypefk_fkey; Type: FK CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT reporttypefk_fkey FOREIGN KEY (reporttypefk) REFERENCES reporttype(reporttypepk);


--
-- Name: case state_fkey; Type: FK CONSTRAINT; Schema: casesvc; Owner: casesvc
--

ALTER TABLE ONLY "case"
    ADD CONSTRAINT state_fkey FOREIGN KEY (statefk) REFERENCES casestate(statepk);


SET search_path = collectionexercise, pg_catalog;

--
-- Name: casetypedefault ctd_surveyfk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY casetypedefault
    ADD CONSTRAINT ctd_surveyfk_fkey FOREIGN KEY (surveyfk) REFERENCES survey(surveypk);


--
-- Name: casetypeoverride exercisefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY casetypeoverride
    ADD CONSTRAINT exercisefk_fkey FOREIGN KEY (exercisefk) REFERENCES collectionexercise(exercisepk);


--
-- Name: sampleunitgroup exercisefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunitgroup
    ADD CONSTRAINT exercisefk_fkey FOREIGN KEY (exercisefk) REFERENCES collectionexercise(exercisepk);


--
-- Name: report reporttypefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT reporttypefk_fkey FOREIGN KEY (reporttypefk) REFERENCES reporttype(reporttypepk);


--
-- Name: sampleunit sampleunitgroupfk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT sampleunitgroupfk_fkey FOREIGN KEY (sampleunitgroupfk) REFERENCES sampleunitgroup(sampleunitgrouppk);


--
-- Name: casetypedefault sampleunittype_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY casetypedefault
    ADD CONSTRAINT sampleunittype_fkey FOREIGN KEY (sampleunittypefk) REFERENCES sampleunittype(sampleunittypepk);


--
-- Name: casetypeoverride sampleunittypefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY casetypeoverride
    ADD CONSTRAINT sampleunittypefk_fkey FOREIGN KEY (sampleunittypefk) REFERENCES sampleunittype(sampleunittypepk);


--
-- Name: sampleunit sampleunittypefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT sampleunittypefk_fkey FOREIGN KEY (sampleunittypefk) REFERENCES sampleunittype(sampleunittypepk);


--
-- Name: collectionexercise statefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY collectionexercise
    ADD CONSTRAINT statefk_fkey FOREIGN KEY (statefk) REFERENCES collectionexercisestate(statepk);


--
-- Name: sampleunitgroup statefk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY sampleunitgroup
    ADD CONSTRAINT statefk_fkey FOREIGN KEY (statefk) REFERENCES sampleunitgroupstate(statepk);


--
-- Name: collectionexercise surveyfk_fkey; Type: FK CONSTRAINT; Schema: collectionexercise; Owner: collectionexercisesvc
--

ALTER TABLE ONLY collectionexercise
    ADD CONSTRAINT surveyfk_fkey FOREIGN KEY (surveyfk) REFERENCES survey(surveypk);


SET search_path = partysvc, pg_catalog;

--
-- Name: business_respondent business_respondent_business_id_fkey; Type: FK CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY business_respondent
    ADD CONSTRAINT business_respondent_business_id_fkey FOREIGN KEY (business_id) REFERENCES business(party_uuid);


--
-- Name: business_respondent business_respondent_respondent_id_fkey; Type: FK CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY business_respondent
    ADD CONSTRAINT business_respondent_respondent_id_fkey FOREIGN KEY (respondent_id) REFERENCES respondent(id);


--
-- Name: enrolment enrolment_business_id_fkey; Type: FK CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY enrolment
    ADD CONSTRAINT enrolment_business_id_fkey FOREIGN KEY (business_id, respondent_id) REFERENCES business_respondent(business_id, respondent_id);


--
-- Name: pending_enrolment pending_enrolment_respondent_id_fkey; Type: FK CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY pending_enrolment
    ADD CONSTRAINT pending_enrolment_respondent_id_fkey FOREIGN KEY (respondent_id) REFERENCES respondent(id);


--
-- Name: pending_enrolment pending_enrolment_respondent_id_fkey1; Type: FK CONSTRAINT; Schema: partysvc; Owner: postgres
--

ALTER TABLE ONLY pending_enrolment
    ADD CONSTRAINT pending_enrolment_respondent_id_fkey1 FOREIGN KEY (respondent_id) REFERENCES respondent(id);


SET search_path = public, pg_catalog;

--
-- Name: auth_group_permissions auth_group_permiss_permission_id_84c5c92e_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permiss_permission_id_84c5c92e_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permiss_content_type_id_2f476e4b_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permiss_content_type_id_2f476e4b_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_per_permission_id_1fbb5f2c_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_per_permission_id_1fbb5f2c_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_content_type_id_c4bce8eb_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_content_type_id_c4bce8eb_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthauthorizationcode_scopes e087e784de108b1bb0f263df6a6ee307; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode_scopes
    ADD CONSTRAINT e087e784de108b1bb0f263df6a6ee307 FOREIGN KEY (oauthauthorizationcode_id) REFERENCES tokens_oauthauthorizationcode(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthaccesstoken_scopes toke_oauthaccesstoken_id_9f8ce9f3_fk_tokens_oauthaccesstoken_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken_scopes
    ADD CONSTRAINT toke_oauthaccesstoken_id_9f8ce9f3_fk_tokens_oauthaccesstoken_id FOREIGN KEY (oauthaccesstoken_id) REFERENCES tokens_oauthaccesstoken(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthaccesstoken tokens_oauthac_client_id_0b06e756_fk_credentials_oauthclient_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken
    ADD CONSTRAINT tokens_oauthac_client_id_0b06e756_fk_credentials_oauthclient_id FOREIGN KEY (client_id) REFERENCES credentials_oauthclient(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthaccesstoken_scopes tokens_oauthacce_oauthscope_id_75cbc0c6_fk_tokens_oauthscope_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken_scopes
    ADD CONSTRAINT tokens_oauthacce_oauthscope_id_75cbc0c6_fk_tokens_oauthscope_id FOREIGN KEY (oauthscope_id) REFERENCES tokens_oauthscope(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthaccesstoken tokens_oauthaccess_user_id_e5dc07c6_fk_credentials_oauthuser_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken
    ADD CONSTRAINT tokens_oauthaccess_user_id_e5dc07c6_fk_credentials_oauthuser_id FOREIGN KEY (user_id) REFERENCES credentials_oauthuser(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthauthorizationcode tokens_oauthau_client_id_a3a1bf9a_fk_credentials_oauthclient_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode
    ADD CONSTRAINT tokens_oauthau_client_id_a3a1bf9a_fk_credentials_oauthclient_id FOREIGN KEY (client_id) REFERENCES credentials_oauthclient(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthauthorizationcode_scopes tokens_oauthauth_oauthscope_id_fa96eff3_fk_tokens_oauthscope_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode_scopes
    ADD CONSTRAINT tokens_oauthauth_oauthscope_id_fa96eff3_fk_tokens_oauthscope_id FOREIGN KEY (oauthscope_id) REFERENCES tokens_oauthscope(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthauthorizationcode tokens_oauthauthor_user_id_4921b0a3_fk_credentials_oauthuser_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthauthorizationcode
    ADD CONSTRAINT tokens_oauthauthor_user_id_4921b0a3_fk_credentials_oauthuser_id FOREIGN KEY (user_id) REFERENCES credentials_oauthuser(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tokens_oauthaccesstoken tokens_refresh_token_id_73966741_fk_tokens_oauthrefreshtoken_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tokens_oauthaccesstoken
    ADD CONSTRAINT tokens_refresh_token_id_73966741_fk_tokens_oauthrefreshtoken_id FOREIGN KEY (refresh_token_id) REFERENCES tokens_oauthrefreshtoken(id) DEFERRABLE INITIALLY DEFERRED;


SET search_path = ras_ci, pg_catalog;

--
-- Name: classification classification_instrument_id_fkey; Type: FK CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY classification
    ADD CONSTRAINT classification_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES instrument(id);


--
-- Name: instrument_business instrument_business_business_id_fkey; Type: FK CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument_business
    ADD CONSTRAINT instrument_business_business_id_fkey FOREIGN KEY (business_id) REFERENCES business(id);


--
-- Name: instrument_business instrument_business_instrument_id_fkey; Type: FK CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument_business
    ADD CONSTRAINT instrument_business_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES instrument(id);


--
-- Name: instrument_exercise instrument_exercise_exercise_id_fkey; Type: FK CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument_exercise
    ADD CONSTRAINT instrument_exercise_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES exercise(id);


--
-- Name: instrument_exercise instrument_exercise_instrument_id_fkey; Type: FK CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument_exercise
    ADD CONSTRAINT instrument_exercise_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES instrument(id);


--
-- Name: instrument instrument_survey_id_fkey; Type: FK CONSTRAINT; Schema: ras_ci; Owner: postgres
--

ALTER TABLE ONLY instrument
    ADD CONSTRAINT instrument_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES survey(id);


SET search_path = sample, pg_catalog;

--
-- Name: report reporttypefk_fkey; Type: FK CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY report
    ADD CONSTRAINT reporttypefk_fkey FOREIGN KEY (reporttypefk) REFERENCES reporttype(reporttypepk);


--
-- Name: sampleunit samplesummary_fkey; Type: FK CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT samplesummary_fkey FOREIGN KEY (samplesummaryfk) REFERENCES samplesummary(samplesummarypk);


--
-- Name: samplesummary statefk_fkey; Type: FK CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY samplesummary
    ADD CONSTRAINT statefk_fkey FOREIGN KEY (statefk) REFERENCES samplesummarystate(statepk);


--
-- Name: sampleunit statefk_fkey; Type: FK CONSTRAINT; Schema: sample; Owner: samplesvc
--

ALTER TABLE ONLY sampleunit
    ADD CONSTRAINT statefk_fkey FOREIGN KEY (statefk) REFERENCES sampleunitstate(statepk);


SET search_path = survey, pg_catalog;

--
-- Name: classifiertype classifiertypeselectorfk_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertype
    ADD CONSTRAINT classifiertypeselectorfk_fkey FOREIGN KEY (classifiertypeselectorfk) REFERENCES classifiertypeselector(classifiertypeselectorpk);


--
-- Name: classifiertypeselector surveyfk_fkey; Type: FK CONSTRAINT; Schema: survey; Owner: postgres
--

ALTER TABLE ONLY classifiertypeselector
    ADD CONSTRAINT surveyfk_fkey FOREIGN KEY (surveyfk) REFERENCES survey(surveypk);


--
-- PostgreSQL database dump complete
--

