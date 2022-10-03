

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS audit;

CREATE SCHEMA IF NOT EXISTS dbo;

CREATE SCHEMA IF NOT EXISTS meta;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE SCHEMA IF NOT EXISTS upload;

CREATE SCHEMA IF NOT EXISTS uts;

DROP TRIGGER IF EXISTS tr_dimdate_biu
ON dbo.dimdate;

-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.fn_tr_dimdate_biu();

DROP ROUTINE IF EXISTS meta.ufn_convertdectostr(IN NUMERIC);

DROP ROUTINE IF EXISTS meta.ufn_getconfigvalue(IN VARCHAR);

DROP ROUTINE IF EXISTS meta.ufn_getlastdate();

-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS audit.sp_auditerror(IN INTEGER, IN VARCHAR, IN NUMERIC);

DROP ROUTINE IF EXISTS audit.sp_auditfinish(IN INTEGER, IN INTEGER, IN TEXT, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_auditstart(IN VARCHAR, IN TEXT, IN VARCHAR, INOUT INTEGER, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_print(IN TEXT, IN NUMERIC, INOUT int);

DROP ROUTINE IF EXISTS dbo.sp_filldimdate(IN TIMESTAMP WITHOUT TIME ZONE, IN TIMESTAMP WITHOUT TIME ZONE, IN VARCHAR, IN VARCHAR, IN NUMERIC, INOUT refcursor, INOUT refcursor);

DROP ROUTINE IF EXISTS dbo.sp_fillfactincome(INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS dbo.sp_runbatch(INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS dbo.sp_runtransform(INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS meta.sp_initdatabase(IN NUMERIC);

DROP ROUTINE IF EXISTS upload.upl_cbrusdrate(IN TIMESTAMP WITHOUT TIME ZONE, IN TIMESTAMP WITHOUT TIME ZONE, INOUT TEXT, INOUT int);

DROP ROUTINE IF EXISTS upload.upl_incomebook(IN VARCHAR, IN VARCHAR, INOUT VARCHAR, INOUT int);

DROP ROUTINE IF EXISTS upload.upl_loadxmlfromfile(IN VARCHAR, INOUT VARCHAR);

DROP ROUTINE IF EXISTS uts.usp_unittest(IN NUMERIC, IN INTEGER, IN VARCHAR, INOUT refcursor);


-- ------------ Write DROP-VIEW-stage scripts -----------

DROP VIEW IF EXISTS dbo.vw_quarterincome;

-- ------------ Write DROP-TABLE-stage scripts -----------

DROP TABLE IF EXISTS audit.logprocedures;

DROP TABLE IF EXISTS dbo.dimbatch;

DROP TABLE IF EXISTS dbo.dimdate;

DROP TABLE IF EXISTS dbo.dimexchrateusd;

DROP TABLE IF EXISTS dbo.factincome;

DROP TABLE IF EXISTS dbo.factincomehistory;

DROP TABLE IF EXISTS meta.configapp;

DROP TABLE IF EXISTS staging.dimincome;

DROP TABLE IF EXISTS staging.factincomehistory;

DROP TABLE IF EXISTS upload.cbrusdrate;

DROP TABLE IF EXISTS upload.currencyperiod;

DROP TABLE IF EXISTS upload.incomebook;

DROP TABLE IF EXISTS uts.resultunittest;

-- ------------ Write DROP-DATABASE-stage scripts -----------


-- ------------ Write CREATE-TABLE-stage scripts -----------
DROP TABLE IF EXISTS uts.resultunittest;

CREATE TABLE uts."GroupType" (
    "Code" character varying(20) NOT NULL,
    "Name" character varying(100) NOT NULL
);


CREATE TABLE audit.logprocedures(
    logid BIGINT NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    mainid BIGINT,
    parentid BIGINT,
    starttime TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    endtime TIMESTAMP WITHOUT TIME ZONE,
    duration INTEGER,
    rowcount INTEGER,
    sys_user_name VARCHAR(256) NOT NULL,
    sys_host_name VARCHAR(100) NOT NULL,
    sys_app_name VARCHAR(128) NOT NULL,
    spid INTEGER NOT NULL,
    spname VARCHAR(512),
    spparams TEXT,
    spinfo TEXT,
    errormessage VARCHAR(2048),
    transactioncount INTEGER
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimbatch(
    batchid INTEGER NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimdate(
    dateid INTEGER NOT NULL PRIMARY KEY,
    fulldatealternatekey DATE NOT NULL,
    daynumberofyear SMALLINT NOT NULL,
    daynumberofmonth SMALLINT NOT NULL,
    daynumberofquarter SMALLINT NOT NULL,
    monthnumberofyear SMALLINT NOT NULL,
    monthnumberofquarter SMALLINT NOT NULL,
    calendarquarter SMALLINT NOT NULL,
    calendaryear SMALLINT NOT NULL,
    dayname VARCHAR(14) NOT NULL,
    monthname VARCHAR(14) NOT NULL,
    lastofmonth DATE NOT NULL,
    firstofquarter DATE NOT NULL,
    lastofquarter DATE NOT NULL,
    englishdayname VARCHAR(30),
    englishmonthname VARCHAR(30),
    simplerussiandate VARCHAR(4000)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimexchrateusd(
    dateid INTEGER NOT NULL PRIMARY KEY,
    batchid INTEGER,
    exchangerates NUMERIC(19,4) NOT NULL,
    createdate TIMESTAMP WITHOUT TIME ZONE,
    iscopy BOOLEAN DEFAULT true NOT NULL 
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.factincome(
    id INTEGER NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    batchid INTEGER,
    incomevalue NUMERIC(19,4),
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.factincomehistory(
    id INTEGER NOT NULL PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    versionkey UUID,
    exchangedateid INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    lotorder INTEGER,
    endbatchid INTEGER,
    createdate TIMESTAMP WITHOUT TIME ZONE,
    changedate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE meta.configapp(
    parameter VARCHAR(128) NOT NULL PRIMARY KEY,
    strvalue VARCHAR(256)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE staging.dimincome(
    id INTEGER,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    exchangedata INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    createdate TIMESTAMP WITHOUT TIME ZONE,
    changedate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE staging.factincomehistory(
    id INTEGER,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    versionkey UUID,
    exchangedateid INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    endbatchid INTEGER,
    lotorder INTEGER
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE upload.cbrusdrate(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    date TIMESTAMP WITHOUT TIME ZONE,
    exchangerates NUMERIC(19,4)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE upload.currencyperiod(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    batchid INTEGER NOT NULL,
    dateid_start INTEGER NOT NULL,
    dateid_end INTEGER NOT NULL,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE upload.incomebook(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    date TIMESTAMP WITHOUT TIME ZONE,
    incomeusd NUMERIC(19,4),
    exchangedate TIMESTAMP WITHOUT TIME ZONE,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4)
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE uts.resultunittest(
    testname VARCHAR(200),
    stepid INTEGER,
    error TEXT,
    datestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT clock_timestamp()
)
        WITH (
        OIDS=FALSE
        );

-- ------------ Write CREATE-VIEW-stage scripts -----------

CREATE OR REPLACE  VIEW dbo.vw_quarterincome (calendaryear, calendarquarter, incomevalue) AS
SELECT
    calendaryear, calendarquarter, SUM(incomevalue) AS incomevalue
    FROM dbo.factincome AS f
    INNER JOIN dbo.dimdate AS d
        ON f.dateid = d.dateid
    GROUP BY calendaryear, calendarquarter;

-- ------------ Write CREATE-CONSTRAINT-stage scripts -----------
/*
ALTER TABLE audit.logprocedures
ADD CONSTRAINT pk_audit_logprocedures_677577452 PRIMARY KEY (logid);

ALTER TABLE dbo.dimbatch
ADD CONSTRAINT pk_dimbatch_789577851 PRIMARY KEY (batchid);

ALTER TABLE dbo.dimdate
ADD CONSTRAINT pk_dimdate_613577224 PRIMARY KEY (dateid);

ALTER TABLE dbo.dimexchrateusd
ADD CONSTRAINT pk_dimexchrateusd_821577965 PRIMARY KEY (dateid);

ALTER TABLE dbo.factincome
ADD CONSTRAINT pk_factincome_885578193 PRIMARY KEY (id);

ALTER TABLE dbo.factincomehistory
ADD CONSTRAINT pk_factincomehistory_853578079 PRIMARY KEY (id);

ALTER TABLE meta.configapp
ADD CONSTRAINT pk_audit_logprocedures_917578307 PRIMARY KEY (parameter);
*/

ALTER TABLE upload.currencyperiod
ADD CONSTRAINT pk_currencyperiod_645577338 PRIMARY KEY (id);

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.fn_tr_dimdate_biu()
RETURNS trigger
AS
$BODY$
BEGIN
IF ((TG_OP = 'INSERT' AND NEW.englishdayname IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.englishdayname <> OLD.englishdayname)) THEN
    RAISE EXCEPTION ' The column "englishdayname" cannot be modified because it is a computed column ';
END IF;
IF ((TG_OP = 'INSERT' AND NEW.englishmonthname IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.englishmonthname <> OLD.englishmonthname)) THEN
    RAISE EXCEPTION ' The column "englishmonthname" cannot be modified because it is a computed column ';
END IF;
IF ((TG_OP = 'INSERT' AND NEW.simplerussiandate IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.simplerussiandate <> OLD.simplerussiandate)) THEN
    RAISE EXCEPTION ' The column "simplerussiandate" cannot be modified because it is a computed column ';
END IF;

/*
[7811 - Severity CRITICAL - PostgreSQL doesn't support the FORMAT(VARCHAR,VARCHAR) function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
(format([FullDateAlternateKey],'d','ru-ru'))
*/
NEW.englishmonthname := (to_char(NEW.fulldatealternatekey::DATE, 'Month'));
NEW.englishdayname := (CAST (date_part('week', NEW.fulldatealternatekey::DATE) AS VARCHAR(2)));
RETURN NEW;
END;
$BODY$
LANGUAGE  plpgsql;

CREATE OR REPLACE FUNCTION meta.ufn_convertdectostr(IN par_val NUMERIC)
RETURNS VARCHAR
AS
$BODY$
/* SELECT meta.ufn_ConvertDecToStr(0.00000010000), '0.0000001' */
BEGIN
    RETURN
    CASE
        WHEN aws_sqlserver_ext.ROUND3(par_val, 0, 1) = par_val THEN LTRIM(to_char(par_val::DOUBLE PRECISION, '99999999999999999999'))
        ELSE LEFT(par_val, LENGTH(par_val) - aws_sqlserver_ext.patindex('%[^0]%', REVERSE(par_val)) + 1)
    END;
END;
$BODY$
LANGUAGE  plpgsql;

CREATE OR REPLACE FUNCTION meta.ufn_getconfigvalue(IN par_parameter VARCHAR)
RETURNS VARCHAR
AS
$BODY$
/*
SELECT * FROM sys.sql_modules WHERE object_id  in (
SELECT object_id  FROM sys.objects WHERE name= 'ufn_GetConfigValue'
)
*/
DECLARE
    var_Value VARCHAR(256);
BEGIN
    var_Value := (SELECT
        strvalue
        FROM meta.configapp
        WHERE LOWER(parameter) = LOWER(par_Parameter));
    RETURN var_Value;
END;
$BODY$
LANGUAGE  plpgsql;

CREATE OR REPLACE FUNCTION meta.ufn_getlastdate()
RETURNS TIMESTAMP WITHOUT TIME ZONE
AS
$BODY$
/* SELECT [meta].[ufn_GetLastDate]() */
BEGIN
    RETURN make_date(2100, 12, 31);
END;
$BODY$
LANGUAGE  plpgsql;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------
