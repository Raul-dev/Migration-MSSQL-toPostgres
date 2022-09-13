-- ------------ Write DROP-TRIGGER-stage scripts -----------
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

-- ------------ Write DROP-CONSTRAINT-stage scripts -----------

ALTER TABLE audit.logprocedures DROP CONSTRAINT pk_audit_logprocedures_677577452;

ALTER TABLE dbo.dimbatch DROP CONSTRAINT pk_dimbatch_789577851;

ALTER TABLE dbo.dimdate DROP CONSTRAINT pk_dimdate_613577224;

ALTER TABLE dbo.dimexchrateusd DROP CONSTRAINT pk_dimexchrateusd_821577965;

ALTER TABLE dbo.factincome DROP CONSTRAINT pk_factincome_885578193;

ALTER TABLE dbo.factincomehistory DROP CONSTRAINT pk_factincomehistory_853578079;

ALTER TABLE meta.configapp DROP CONSTRAINT pk_audit_logprocedures_917578307;

ALTER TABLE upload.currencyperiod DROP CONSTRAINT pk_currencyperiod_645577338;

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

CREATE TABLE audit.logprocedures(
    logid BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
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
    batchid INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.dimdate(
    dateid INTEGER NOT NULL,
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
    dateid INTEGER NOT NULL,
    batchid INTEGER,
    exchangerates NUMERIC(19,4) NOT NULL,
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.factincome(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    batchid INTEGER,
    incomevalue NUMERIC(19,4),
    createdate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE dbo.factincomehistory(
    id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY,
    dateid INTEGER,
    batchid INTEGER,
    incomeusd NUMERIC(19,4),
    naturalkey UUID,
    versionkey UUID,
    exchangedateid INTEGER,
    exchangevalue NUMERIC(19,4),
    exchangerate NUMERIC(19,4),
    endbatchid INTEGER,
    createdate TIMESTAMP WITHOUT TIME ZONE,
    changedate TIMESTAMP WITHOUT TIME ZONE
)
        WITH (
        OIDS=FALSE
        );

CREATE TABLE meta.configapp(
    parameter VARCHAR(128) NOT NULL,
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
    endbatchid INTEGER
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
    exchangedata TIMESTAMP WITHOUT TIME ZONE,
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

CREATE PROCEDURE audit.sp_auditerror(IN par_logid INTEGER DEFAULT NULL, IN par_errormessage VARCHAR DEFAULT NULL, IN par_isfinish NUMERIC DEFAULT 0)
AS 
$BODY$
DECLARE
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    UPDATE audit.logprocedures
    SET errormessage = LEFT(COALESCE(errormessage, '') || COALESCE(par_ErrorMessage, 'Error') || '; ', 2048)
        WHERE logid = par_LogID;

    IF par_isFinish = 1 THEN
        CALL audit.sp_auditfinish(par_LogID := par_LogID, return_code => sp_auditfinish$ReturnCode);
    END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE audit.sp_auditfinish(IN par_logid INTEGER DEFAULT NULL, IN par_recordcount INTEGER DEFAULT NULL, IN par_spinfo TEXT DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
DECLARE
    var_AuditProcEnable VARCHAR(128);
    var_TranCount INTEGER;
BEGIN
    SELECT
        meta.ufn_getconfigvalue('AuditProcAll')
        INTO var_AuditProcEnable;

    IF var_AuditProcEnable IS NULL THEN
        return_code := 0;
        RETURN;
    END IF;

    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    /*
    [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
    SET @TranCount = @@TRANCOUNT
    */
    UPDATE audit.logprocedures
    SET endtime = clock_timestamp(), duration = aws_sqlserver_ext.datediff('millisecond', starttime::TIMESTAMP, clock_timestamp()::TIMESTAMP), rowcount = par_RecordCount, spinfo = COALESCE(spinfo, '') ||
    CASE
        WHEN transactioncount = var_TranCount THEN ''
        ELSE 'Tran count changed to ' || COALESCE(LTRIM(to_char(var_TranCount::DOUBLE PRECISION, '9999999999')), 'NULL') || ';'
    END ||
    CASE
        WHEN par_SPInfo IS NULL THEN ''
        ELSE 'Finish:' || aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(19)', 'DATETIME', clock_timestamp(), 120) || ':' || par_SPInfo || ';'
    END
        WHERE logid = par_LogID;
    DELETE FROM t$auditproc
        WHERE logid >= par_LogID;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE audit.sp_auditstart(IN par_spname VARCHAR DEFAULT NULL, IN par_spparams TEXT DEFAULT NULL, IN par_spsub VARCHAR DEFAULT NULL, INOUT par_logid INTEGER DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
DECLARE @ID int
EXEC audit.sp_AuditStart @ID = @ID output
SELECT @ID
SELECT [meta].[ufn_GetConfigValue]('AuditProcAll')
*/
DECLARE
    var_AuditProcEnable VARCHAR(128);
    var_ParentID INTEGER;
    var_MainID INTEGER;
    var_CountIds INTEGER;
    var_TranCount INTEGER;
    SCOPE_IDENTITY BIGINT;
BEGIN
    SELECT
        meta.ufn_getconfigvalue('AuditProcAll')
        INTO var_AuditProcEnable;

    IF var_AuditProcEnable IS NULL THEN
        return_code := 0;
        RETURN;
    END IF;

    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    /*
    [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
    SET @TranCount = @@TRANCOUNT
    */
    SELECT
        MIN(logid), MAX(logid), COUNT(logid)
        INTO var_MainID, var_ParentID, var_CountIds
        FROM t$auditproc;
    par_SPName := LEFT(REPEAT('    ',
    CASE
        WHEN var_CountIds < 0 THEN NULL::INT
        ELSE var_CountIds
    END) || LTRIM(RTRIM(par_SPName)), 512) || COALESCE(': ' || par_SPSub, '');
    INSERT INTO audit.logprocedures (mainid, parentid, spname, spparams, transactioncount)
    VALUES (var_MainID, var_ParentID, par_SPName, par_SPParams, var_TranCount);
    par_LogID := SCOPE_IDENTITY;

    IF var_MainID IS NULL THEN
        UPDATE audit.logprocedures
        SET mainid = par_LogID
            WHERE logid = par_LogID;
    END IF;

    IF var_ParentID IS NULL OR var_ParentID < par_LogID THEN
        INSERT INTO t$auditproc (logid)
        VALUES (par_LogID);
    END IF;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE audit.sp_print(IN par_string TEXT, IN par_overrideconfig NUMERIC DEFAULT 0, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/* [audit].[sp_Print] @string = ' SELECT * FROM Security ' */
DECLARE
    var_str VARCHAR(4000);
    var_part INTEGER;
    var_len INTEGER;
    var_AuditPrintEnable VARCHAR(128);
BEGIN
    var_part := 4000;
    var_len := LENGTH(par_string);
    SELECT
        meta.ufn_getconfigvalue('AuditPrintAll')
        INTO var_AuditPrintEnable;

    IF COALESCE(var_AuditPrintEnable, 0) = 2 OR (par_OverrideConfig = 0 AND COALESCE(var_AuditPrintEnable, 0) = 0) THEN
        return_code := 0;
        RETURN;
    END IF;

    WHILE var_len > 0 LOOP
        IF var_len <= var_part THEN
            RAISE NOTICE '%', par_string;
            EXIT;
        END IF;
        var_str := LEFT(par_string, var_part);
        /* SET @str = LEFT(@str, LEN(@str ) - CHARINDEX(CHAR(13), REVERSE(@str)) + 1) */
        RAISE NOTICE '%', var_str;
        par_string := RIGHT(par_string, var_len - LENGTH(var_str));
        var_len := LENGTH(par_string);
    END LOOP;
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE dbo.sp_filldimdate(IN par_fromdate TIMESTAMP WITHOUT TIME ZONE, IN par_todate TIMESTAMP WITHOUT TIME ZONE, IN par_culture VARCHAR, IN par_tablename VARCHAR DEFAULT NULL, IN par_isoutput NUMERIC DEFAULT 1, INOUT p_refcur refcursor DEFAULT NULL, INOUT p_refcur_2 refcursor DEFAULT NULL)
AS 
$BODY$
/* EXEC [meta].[sp_FillDimDate] @FromDate = '20180101', @ToDate = '20251231', @Culture = 'ru-ru', @TableName = '#Result_Test1', @IsOutput = 1 */
/* EXEC [meta].[sp_FillDimDate] @FromDate = '20180101', @ToDate = '20251231', @Culture = 'ru-ru', @IsOutput = 1 */
/* SET LANGUAGE English --  Russian */
/* SELECT [meta].[ufn_GetTableColumns]( 'dbo', 'DimDate') */
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    sp_auditstart$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'sp_filldimdate' || ']';
    var_SPParams := '';
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /* Debug */
    /* SET @Culture='ru-ru'; -- 'en-US' */
    /* SELECT @FromDate = '20060101', @ToDate = '20061231'; */
    
    /*
    [7811 - Severity CRITICAL - PostgreSQL doesn't support the FORMAT(VARCHAR,VARCHAR) function. Review the converted code to make sure that the user-defined function produces the same results as the source code., 7811 - Severity CRITICAL - PostgreSQL doesn't support the FORMAT(VARCHAR,VARCHAR) function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
    WITH Days(DateCalendarValue, ID) AS
    (
     SELECT @FromDate, 1 WHERE @FromDate <= @ToDate
     UNION ALL
     SELECT DATEADD(DAY,1,DateCalendarValue), ID+1  FROM Days WHERE DateCalendarValue < @ToDate
    )
    
    SELECT
    	[DateID] = CAST(CONVERT(varchar(25), DateCalendarValue, 112) as int) ,
    	[FullDateAlternateKey] = CAST(DateCalendarValue as date),
    	[DayNumberOfYear]      = DATEPART(dayofyear, DateCalendarValue),
    	[DayNumberOfMonth]     = DATEPART(day, DateCalendarValue),
    	[DayNumberOfQuarter]   = DATEDIFF(dd,DATEADD(qq, DATEDIFF(qq, 0, DateCalendarValue), 0), DateCalendarValue) + 1,
    	[MonthNumberOfYear]    = DATEPART(month, DateCalendarValue),
    	[MonthNumberOfQuarter] = MONTH(DateCalendarValue) - MONTH(DATEADD(qq, DATEDIFF(qq, 0, DateCalendarValue), 0)) + 1,
    	[CalendarQuarter]      = DATEPART(quarter, DateCalendarValue),
    	[CalendarYear]         = DATEPART(year, DateCalendarValue),
    	[DayName]              = FORMAT(DateCalendarValue, 'dddd', @Culture),
    	[MonthName]            = FORMAT(DateCalendarValue, 'MMMM', @Culture),
    	LastOfMonth            = EOMONTH(DateCalendarValue) ,
    	FirstOfQuarter         = CONVERT(nvarchar(10),DATEADD(qq, DATEDIFF(qq, 0, DateCalendarValue), 0), 23),
    	LastOfQuarter          = CONVERT(nvarchar(10), DATEADD (dd, -1, DATEADD(qq, DATEDIFF(qq, 0, DateCalendarValue) +1, 0)), 23)
    
    	into #NewDate
    FROM [Days]
    ORDER BY DateCalendarValue
    OPTION (MAXRECURSION 0);
    */
    
    /*
    [7833 - Severity CRITICAL - AWS SCT can't convert the @@rowcount function in the current context. Convert your source code manually.]
    SET @RowCount = @@ROWCOUNT
    */
    IF (par_TableName IS NULL) THEN
        INSERT INTO dbo.dimdate (dateid, fulldatealternatekey, daynumberofyear, daynumberofmonth, daynumberofquarter, monthnumberofyear, monthnumberofquarter, calendarquarter, calendaryear, dayname, monthname, lastofmonth, firstofquarter, lastofquarter)
        SELECT
            new.dateid, new.fulldatealternatekey, new.daynumberofyear, new.daynumberofmonth, new.daynumberofquarter, new.monthnumberofyear, new.monthnumberofquarter, new.calendarquarter, new.calendaryear, new.dayname, new.monthname, new.lastofmonth, new.firstofquarter, new.lastofquarter
            FROM t$newdate AS new
            LEFT OUTER JOIN dbo.dimdate AS d
                ON new.dateid = d.dateid
            WHERE d.dateid IS NULL;
    END IF;

    IF (NOT par_TableName IS NULL) THEN
        OPEN p_refcur FOR
        EXECUTE 'CREATE TABLE  ' || par_TableName || '
			AS SELECT dateid, new.fulldatealternatekey, new.daynumberofyear, new.daynumberofmonth, new.daynumberofquarter, new.monthnumberofyear, new.monthnumberofquarter, new.calendarquarter, new.calendaryear, new.dayname, new.monthname, new.lastofmonth, new.firstofquarter, new.lastofquarter FROM t$newdate AS new
			';
    END IF;
    CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);

    IF par_IsOutput = 1 THEN
        OPEN p_refcur_2 FOR
        SELECT
            *
            FROM t$newdate;
    END IF;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$newdate;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE dbo.sp_fillfactincome(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
[dbo].[sp_FillFactIncome]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_Trancnt INTEGER;
    var_AuditMessage TEXT;
    var_ExecStr TEXT;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_Res INTEGER;
    var_RowCounttmp INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'sp_fillfactincome' || ']';
    var_SPParams := '@ErrMessage=' || COALESCE('''' || par_ErrMessage || '''', 'NULL');
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the XACT_ABORT clause of the SET statement. Convert your source code manually.]
    SET XACT_ABORT OFF
    */
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[dbo].[sp_FillFactIncome]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
        /*
        [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
        SET @Trancnt = @@TRANCOUNT
        */
        IF var_Trancnt > 0 THEN
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            SAVE TRAN tr_FillFactIncome
            */
            BEGIN
            END;
        ELSE
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            BEGIN TRAN
            */
            BEGIN
            END;
        END IF;
        TRUNCATE TABLE dbo.factincome;
        INSERT INTO dbo.factincome (dateid, batchid, incomevalue, createdate)
        SELECT
            fih.dateid, fih.batchid, (fih.incomeusd) * der.exchangerates AS incomevalue, clock_timestamp() AS createdate
            FROM dbo.factincomehistory AS fih
            INNER JOIN dbo.dimexchrateusd AS der
                ON fih.dateid = der.dateid
            WHERE fih.endbatchid IS NULL;
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;
        INSERT INTO dbo.factincome (dateid, batchid, incomevalue, createdate)
        SELECT
            dateid, ex.batchid, ex.incomevalue - base.incomevalue AS incomevalue, clock_timestamp() AS createdate
            FROM (SELECT
                fih.id, fih.dateid, (fih.exchangevalue) * der.exchangerates AS incomevalue, der.exchangerates AS der_exchangerates
                FROM dbo.factincomehistory AS fih
                INNER JOIN dbo.dimexchrateusd AS der
                    ON fih.dateid = der.dateid
                WHERE fih.endbatchid IS NULL) AS base
            INNER JOIN (SELECT
                fih.id, fih.exchangedateid, fih.batchid, (fih.exchangevalue) * der.exchangerates AS incomevalue, der.exchangerates AS der_exchangerates
                FROM dbo.factincomehistory AS fih
                LEFT OUTER JOIN dbo.dimexchrateusd AS der
                    ON fih.exchangedateid = der.dateid
                WHERE fih.endbatchid IS NULL AND NOT fih.exchangevalue IS NULL) AS ex
                ON base.id = ex.id
            WHERE base.incomevalue < ex.incomevalue;
        GET DIAGNOSTICS var_RowCounttmp = ROW_COUNT;
        var_RowCount := var_RowCount + var_RowCounttmp;

        IF var_Trancnt = 0 THEN
            COMMIT;
        END IF;
        var_AuditMessage := '[dbo].[sp_FillFactIncome] Inserted FactIncome @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'SP_FILLFACTINCOME';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                IF var_Trancnt = 0 THEN
                    ROLLBACK;
                ELSE
                    IF xact_state() != - 1 THEN
                        ROLLBACK;
                    END IF;
                END IF;

                IF xact_state() != - 1 THEN
                    var_AuditMessage := '[dbo].[sp_FillFactIncome]; error=''' || par_ErrMessage || '''';
                    CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                    CALL audit.sp_auditerror(par_LogID := var_LogID, par_ErrorMessage := par_ErrMessage);
                END IF;
                CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE dbo.sp_runbatch(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
[dbo].[sp_RunBatch]
TRUNCATE TABLE [audit].[LogProcedures]
SELECT * FROM [audit].[LogProcedures]
SELECT 'ExcelFileIncomeBookCmd',''
INSERT [meta].[ConfigApp] (Parameter, StrValue) VALUES( 'ExcelFileIncomeBook','E:\Work\SQL\IndividualEntrepreneur\IncomeBook.xlsx')
UPDATE [meta].[ConfigApp] SET StrValue = 'E:\Work\SQL\IndividualEntrepreneur\Declaration.xlsm'
WHERE Parameter = 'ExcelFileIncomeBook'
	EXEC [dbo].[sp_RunBatch]
	EXEC [dbo].[sp_RunTransform]
	EXEC [dbo].[sp_FillFactIncome]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_Trancnt INTEGER;
    var_AuditMessage TEXT;
    var_ExecStr TEXT;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_Res INTEGER;
    var_BatchID INTEGER;
    var_FromDate INTEGER;
    var_ToDate INTEGER;
    var_CreateDate TIMESTAMP WITHOUT TIME ZONE;
    var_StartDate INTEGER;
    var_ID INTEGER;
    var_EndDate INTEGER;
    /*
    [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
    PeriodsTable CURSOR LOCAL STATIC FOR
    		SELECT
    			r.ID,
    			StartDate = s.FullDateAlternateKey,
    			EndDate = DATEADD(mm,1 ,e.FullDateAlternateKey)
    		FROM (
    		SELECT sr.ID,
    				StartDate = CAST(sr.DateID / 100 AS int) * 100 + 1,
    				EndDate = CAST(ed.DateID / 100 AS int) * 100 + 1
    
    			FROM (
    				SELECT ID =ROW_NUMBER() OVER (ORDER BY DateID),
    				DateID = CASE WHEN dLag is Null THEN DateID
    					ELSE (
    						CASE WHEN IsNull(dDiff,1) <> 1 THEN idLead
    						ELSE NULL
    						END
    					)
    					END
    			FROM #tmp1
    			WHERE dLag is Null or IsNull(dDiff,1) <> 1
    			) sr INNER JOIN (
    				SELECT ID = ROW_NUMBER() OVER (ORDER BY DateID), DateID
    				FROM #tmp1
    				WHERE IsNULL(dDiff,2) <> 1
    				) ed ON sr.ID = ed.ID
    			) r INNER JOIN DimDate s ON s.DateID = r.StartDate
    			INNER JOIN DimDate e ON e.DateID = r.EndDate
    		ORDER BY ID
    */
    var_Start TIMESTAMP WITHOUT TIME ZONE;
    var_End TIMESTAMP WITHOUT TIME ZONE;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'sp_runbatch' || ']';
    var_SPParams := '@ErrMessage=' || COALESCE('''' || par_ErrMessage || '''', 'NULL');
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the XACT_ABORT clause of the SET statement. Convert your source code manually.]
    SET XACT_ABORT OFF
    */
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[dbo].[sp_RunBatch]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
        /*
        [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
        SET @Trancnt = @@TRANCOUNT
        */
        IF var_Trancnt > 0 THEN
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            SAVE TRAN tr_GenerateTable
            */
            BEGIN
            END;
        ELSE
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            BEGIN TRAN
            */
            BEGIN
            END;
        END IF;
        SELECT
            clock_timestamp(), CAST (aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(25)', 'DATETIME', clock_timestamp(), 112) AS INTEGER)
            INTO var_CreateDate, var_StartDate;
        INSERT INTO dbo.dimbatch (dateid, createdate)
        SELECT
            var_StartDate, var_CreateDate;
        TRUNCATE TABLE upload.incomebook;
        CALL upload.upl_incomebook(par_ErrMessage => par_ErrMessage, return_code => var_Res);

        IF var_Res != 0 THEN
            RAISE 'Error %, severity %, state % was raised. Message: %. Argument: %', '50000', 16, 1, 'Error: [%]', par_ErrMessage USING ERRCODE = '50000';
        END IF;
        SELECT
            MIN(dateid), MAX(dateid)
            INTO var_FromDate, var_ToDate
            FROM upload.incomebook AS i
            INNER JOIN dbo.dimdate AS d
                ON i.date = d.fulldatealternatekey;

        IF EXISTS (SELECT
            *
            FROM dbo.dimdate AS d
            LEFT OUTER JOIN upload.incomebook AS i
                ON i.date = d.fulldatealternatekey
            WHERE i.date IS NULL AND (dateid >= var_FromDate OR dateid <= var_ToDate)) THEN
            TRUNCATE TABLE upload.currencyperiod;
            TRUNCATE TABLE upload.cbrusdrate;
            SELECT
                MIN(dateid), MAX(dateid)
                INTO var_FromDate, var_ToDate
                FROM upload.incomebook AS i
                INNER JOIN dbo.dimdate AS d
                    ON i.date = d.fulldatealternatekey;
            SELECT
                MAX(batchid)
                INTO var_BatchID
                FROM dbo.dimbatch;
            CREATE TEMPORARY TABLE t$tmp1
            AS
            SELECT
                d.dateid, fulldatealternatekey, lead(d.dateid, 1, 0) OVER (ORDER BY d.dateid) AS idlead, lead(d.fulldatealternatekey) OVER (ORDER BY d.dateid) AS dlead, lag(d.fulldatealternatekey) OVER (ORDER BY d.dateid) AS dlag, aws_sqlserver_ext.datediff('day', d.fulldatealternatekey::TIMESTAMP, lead(d.fulldatealternatekey) OVER (ORDER BY d.dateid)::TIMESTAMP) AS ddiff
                FROM dbo.dimdate AS d
                LEFT OUTER JOIN dbo.dimexchrateusd AS i
                    ON i.dateid = d.dateid
                WHERE i.dateid IS NULL AND (d.dateid >= var_FromDate AND d.dateid <= var_ToDate);
            /*
            [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
            OPEN PeriodsTable
            */
            /*
            [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
            FETCH NEXT FROM PeriodsTable INTO @ID, @Start, @End
            */
            WHILE (CASE FOUND::INT
                WHEN 0 THEN - 1
                ELSE 0
            END) = 0 LOOP
                INSERT INTO upload.currencyperiod (batchid, dateid_start, dateid_end, createdate)
                SELECT
                    var_BatchID, CAST (aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(25)', 'DATETIME', var_Start, 112) AS INTEGER), CAST (aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(25)', 'DATETIME', var_End, 112) AS INTEGER), var_CreateDate;
                CALL upload.upl_cbrusdrate(par_FromDate := var_Start, par_ToDate := var_End, par_ErrMessage => par_ErrMessage, return_code => var_Res);

                IF var_Res != 0 THEN
                    /*
                    [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
                    CLOSE PeriodsTable
                    */
                    RAISE 'Error %, severity %, state % was raised. Message: %. Argument: %', '50000', 16, 1, 'Error: [%]', par_ErrMessage USING ERRCODE = '50000';
                END IF;
                /*
                [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
                FETCH NEXT FROM PeriodsTable INTO @ID, @Start, @End
                */
            END LOOP;
            /*
            [7774 - Severity CRITICAL - AWS SCT can't convert arithmetic operations with mixed types of operands. Revise your code to use cast operands to the expected type, and try again.]
            CLOSE PeriodsTable
            */
        END IF;

        IF var_Trancnt = 0 THEN
            COMMIT;
        END IF;
        var_AuditMessage := '[dbo].[sp_RunBatch]; finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'SP_RUNBATCH';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                IF var_Trancnt = 0 THEN
                    ROLLBACK;
                ELSE
                    IF xact_state() != - 1 THEN
                        ROLLBACK;
                    END IF;
                END IF;

                IF xact_state() != - 1 THEN
                    var_AuditMessage := '[dbo].[sp_RunBatch]; error=''' || par_ErrMessage || '''';
                    CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                    CALL audit.sp_auditerror(par_LogID := var_LogID, par_ErrorMessage := par_ErrMessage);
                END IF;
                CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$tmp1;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE dbo.sp_runtransform(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
[dbo].[sp_RunTransform]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_Trancnt INTEGER;
    var_AuditMessage TEXT;
    var_ExecStr TEXT;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_Res INTEGER;
    var_BatchID INTEGER;
    var_FromDate INTEGER;
    var_ToDate INTEGER;
    var_CreateDate TIMESTAMP WITHOUT TIME ZONE;
    var_StartDate INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'sp_runtransform' || ']';
    var_SPParams := '@ErrMessage=' || COALESCE('''' || par_ErrMessage || '''', 'NULL');
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the XACT_ABORT clause of the SET statement. Convert your source code manually.]
    SET XACT_ABORT OFF
    */
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[dbo].[sp_RunTransform]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
        /*
        [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
        SET @Trancnt = @@TRANCOUNT
        */
        IF var_Trancnt > 0 THEN
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            SAVE TRAN tr_RunTransform
            */
            BEGIN
            END;
        ELSE
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            BEGIN TRAN
            */
            BEGIN
            END;
        END IF;
        SELECT
            clock_timestamp(), CAST (aws_sqlserver_ext.conv_datetime_to_string('VARCHAR(25)', 'DATETIME', clock_timestamp(), 112) AS INTEGER)
            INTO var_CreateDate, var_StartDate;
        SELECT
            MAX(batchid)
            INTO var_BatchID
            FROM dbo.dimbatch;

        IF EXISTS (SELECT
            *
            FROM upload.cbrusdrate) THEN
            INSERT INTO dbo.dimexchrateusd (DateID, BatchID, ExchangeRates, CreateDate)
            VALUES (dd.DateID, der.BatchID, der.ExchangeRates, der.CreateDate, der.Date, dd.FullDateAlternateKey, der.Date, dd.DateID, c.DateID_Start, dd.DateID, c.DateID_End, der.Date, [Date], var_BatchID, ExchangeRates, var_CreateDate, der.NextDate, Date, Date)
            ON CONFLICT (DateID) DO UPDATE SET BatchID = excluded.BatchID, ExchangeRates = excluded.ExchangeRates, CreateDate = excluded.CreateDate;
            /*
            [7833 - Severity CRITICAL - AWS SCT can't convert the @@rowcount function in the current context. Convert your source code manually.]
            SET @RowCount = @@ROWCOUNT
            */
            var_AuditMessage := '[dbo].[sp_RunTransform]; Merge DimExchRateUSD @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' ';
            CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        END IF;
        TRUNCATE TABLE staging.factincomehistory;
        /*
        [7708 - Severity CRITICAL - AWS SCT can't convert the usage of the unsupported VARBINARY data type. Convert your source code manually., 7708 - Severity CRITICAL - AWS SCT can't convert the usage of the unsupported VARBINARY data type. Convert your source code manually.]
        INSERT [staging].[FactIncomeHistory]([DateID], [BatchID], [IncomeUSD], [NaturalKey], [VersionKey], [ExchangeDateID], [ExchangeValue], [ExchangeRate])
        	SELECT d.[DateID],
        		BatchID = @BatchID,
        		[IncomeUSD],
        		[NaturalKey] = CAST (SUBSTRING(HASHBYTES ( 'SHA2_256', LTRIM(RTRIM(STR(d.[CalendarYear]))) + LTRIM(RTRIM(STR(d.[MonthNumberOfYear]))) ), 0,32) as uniqueidentifier),
        		[VersionKey] = CAST (SUBSTRING(HASHBYTES ( 'SHA2_256', LTRIM(RTRIM(STR(d.[DateID]))) + CAST([IncomeUSD] as varchar(30)) + LTRIM(RTRIM(IsNull(STR(d2.[DateID]),'null'))) + IsNull(CAST([ExchangeValue] as varchar(30)) ,'null') + IsNull(CAST([ExchangeRate] as varchar(30)) ,'null')  )  , 0,32) as uniqueidentifier),
        		[ExchangeDateID] = d2.[DateID],
        		i.[ExchangeValue],
        		i.[ExchangeRate]
        	FROM [upload].[IncomeBook] i INNER JOIN DimDate d ON  CAST(i.Date as date) = d.FullDateAlternateKey
        		LEFT JOIN DimDate d2 ON  CAST(i.ExchangeData as date) = d2.FullDateAlternateKey
        */
        SELECT
            MIN(dateid), MAX(dateid)
            INTO var_FromDate, var_ToDate
            FROM staging.factincomehistory;
        /* Fix deleted */
        INSERT INTO staging.factincomehistory (id, dateid, batchid, incomeusd, naturalkey, versionkey, exchangedateid, exchangevalue, exchangerate, endbatchid)
        SELECT
            source.id, source.dateid, source.batchid, source.incomeusd, source.naturalkey, source.versionkey, source.exchangedateid, source.exchangevalue, source.exchangerate, var_BatchID
            FROM dbo.factincomehistory AS source
            WHERE source.endbatchid IS NULL AND NOT EXISTS (SELECT
                1
                FROM staging.factincomehistory AS target
                WHERE source.naturalkey = target.naturalkey) AND (source.dateid >= var_FromDate OR source.dateid <= var_ToDate);
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;
        DELETE FROM staging.factincomehistory AS source
        USING dbo.factincomehistory AS source, staging.factincomehistory AS target
            WHERE source.endbatchid IS NULL AND target.id IS NULL AND (source.naturalkey = target.naturalkey AND source.versionkey = target.versionkey);
        INSERT INTO staging.factincomehistory (id, dateid, batchid, incomeusd, naturalkey, versionkey, exchangedateid, exchangevalue, exchangerate, endbatchid)
        SELECT
            source.id, source.dateid, source.batchid, source.incomeusd, source.naturalkey, source.versionkey, source.exchangedateid, source.exchangevalue, source.exchangerate, var_BatchID
            FROM dbo.factincomehistory AS source
            WHERE source.endbatchid IS NULL AND EXISTS (SELECT
                1
                FROM staging.factincomehistory AS target
                WHERE source.naturalkey = target.naturalkey AND target.id IS NULL);
        GET DIAGNOSTICS var_RowCount = ROW_COUNT;
        INSERT INTO dbo.factincomehistory ([DateID], [BatchID], [IncomeUSD], [NaturalKey], [VersionKey], [ExchangeDateID], [ExchangeValue], [ExchangeRate], CreateDate)
        VALUES (dd.DateID, der.BatchID, der.ExchangeRates, der.CreateDate, der.Date, dd.FullDateAlternateKey, der.Date, dd.DateID, c.DateID_Start, dd.DateID, c.DateID_End, der.Date, [Date], var_BatchID, ExchangeRates, var_CreateDate, der.NextDate, Date, Date)
        ON CONFLICT (ID) DO UPDATE SET EndBatchID = excluded.EndBatchID, [ChangeDate] = excluded.[ChangeDate];
        /*
        [7833 - Severity CRITICAL - AWS SCT can't convert the @@rowcount function in the current context. Convert your source code manually.]
        SET @RowCount = @@ROWCOUNT
        */
        IF var_Trancnt = 0 THEN
            COMMIT;
        END IF;
        var_AuditMessage := '[dbo].[sp_RunTransform]; Merge FactIncomeHistory @RowCount= ' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || '; finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'SP_RUNTRANSFORM';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                IF var_Trancnt = 0 THEN
                    ROLLBACK;
                ELSE
                    IF xact_state() != - 1 THEN
                        ROLLBACK;
                    END IF;
                END IF;

                IF xact_state() != - 1 THEN
                    var_AuditMessage := '[dbo].[sp_RunTransform]; error=''' || par_ErrMessage || '''';
                    CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                    CALL audit.sp_auditerror(par_LogID := var_LogID, par_ErrorMessage := par_ErrMessage);
                END IF;
                CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE meta.sp_initdatabase(IN par_isdebugmode NUMERIC DEFAULT 0)
AS 
$BODY$
/*
[meta].[sp_InitDataBase]
TRUNCATE TABLE [meta].[ConfigApp]
*/
BEGIN
    IF (NOT EXISTS (SELECT
        1
        FROM meta.configapp)) THEN
        INSERT INTO meta.configapp (parameter, strvalue)
        VALUES ('AuditProcAll', '1');
        INSERT INTO meta.configapp (parameter, strvalue)
        VALUES ('AuditPrintAll', '1');
        INSERT INTO meta.configapp (parameter, strvalue)
        SELECT
            'ExcelFileIncomeBookCmd', 'Select * from [Sheet1$]';
    END IF;
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE upload.upl_cbrusdrate(IN par_fromdate TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL, IN par_todate TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL, INOUT par_errmessage TEXT DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
EXEC [upload].[upl_CbrUsdRate] '20200101', '20201231'
EXEC [upload].[upl_CbrUsdRate] '20200101', '20200102'
DECLARE @xmlString varchar(max)
EXEC [upload].[upl_LoadXMLFromFile] 'http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=01.01.2020&date_req2=29.05.2020&VAL_NM_RQ=R01235', @xmlString output
EXEC [audit].[sp_Print] @xmlString
INSERT [meta].[ConfigApp] (Parameter, StrValue) VALUES( 'ExcelFileIncomeBook','E:\Work\SQL\IndividualEntrepreneur\IncomeBook.xlsx')

SELECT * FROM [upload].[CbrUsdRate]
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_AuditMessage TEXT;
    var_Trancnt INTEGER;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_res INTEGER;
    var_OpenRowSet TEXT;
    var_sqlcmd TEXT;
    var_NewVersionCount INTEGER;
    var_xmlString TEXT;
    var_url VARCHAR(255);
    var_h INTEGER;
    var_StartDate TIMESTAMP WITHOUT TIME ZONE;
    var_FinishDate TIMESTAMP WITHOUT TIME ZONE;
    var_RowCounttmp INTEGER;
    var_MaxCount INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'upl_cbrusdrate' || ']';

    IF par_FromDate IS NULL OR par_ToDate IS NULL THEN
        par_FromDate := make_date(date_part('year', clock_timestamp()), 1, 1);
        par_ToDate := make_date(date_part('year', clock_timestamp()), 12, 31);
    END IF;
    var_SPParams := '@FromDate=' || CAST (par_FromDate AS VARCHAR(11)) || '; @ToDate=' || CAST (par_ToDate AS VARCHAR(11)) || ';';
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the XACT_ABORT clause of the SET statement. Convert your source code manually.]
    SET XACT_ABORT OFF
    */
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    var_OverridePrintEnabling := 0;
    var_AuditMessage := '[upload].[upl_CbrUsdRate]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
        /*
        [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
        SET @Trancnt = @@TRANCOUNT
        */
        IF var_Trancnt > 0 THEN
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            SAVE TRAN tr_CbrUsdRate_Upload
            */
            BEGIN
            END;
        ELSE
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            BEGIN TRAN;
            */
            BEGIN
            END;
        END IF;
        par_FromDate := make_date(date_part('year', par_FromDate), date_part('month', par_FromDate), date_part('day', par_FromDate));

        IF (par_ToDate > clock_timestamp()) THEN
            par_ToDate := make_date(date_part('year', clock_timestamp()), date_part('month', clock_timestamp()), date_part('day', clock_timestamp()));
        ELSE
            par_ToDate := make_date(date_part('year', par_ToDate), date_part('month', par_ToDate), date_part('day', par_ToDate));
        END IF;

        IF (aws_sqlserver_ext.datediff('day', par_FromDate::TIMESTAMP, par_ToDate::TIMESTAMP) < 0) THEN
            RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, 'Error: Parameter @FromDate must be be less than @ToDate.' USING ERRCODE = '50000';
        END IF;
        var_StartDate := par_FromDate;

        IF (aws_sqlserver_ext.datediff('day', par_FromDate::TIMESTAMP, par_ToDate::TIMESTAMP) > 54) THEN
            var_FinishDate := var_StartDate + (55::NUMERIC || ' DAY')::INTERVAL - (1::NUMERIC || ' days')::INTERVAL;
        ELSE
            var_FinishDate := par_ToDate;
        END IF;
        var_MaxCount := 0;

        WHILE (var_MaxCount < 45) LOOP
            /* Maximum 5 year */
            SELECT
                'http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=' || aws_sqlserver_ext.conv_datetime_to_string('CHAR(10)', 'DATETIME', var_StartDate, 104) || '&date_req2=' || aws_sqlserver_ext.conv_datetime_to_string('CHAR(10)', 'DATETIME', var_FinishDate, 104) || '&VAL_NM_RQ=R01235'
                INTO var_url;
            RAISE NOTICE '%', var_url;
            var_xmlString := NULL;
            CALL upload.upl_loadxmlfromfile(var_url, var_xmlString);
            SELECT
                t.DocHandle
                FROM aws_sqlserver_ext.sp_xml_preparedocument(var_xmlString)
                    AS t
                INTO var_h;
            INSERT INTO upload.cbrusdrate (date, exchangerates)
            SELECT
                (make_date(CAST (SUBSTR(date, 7, 4) AS INTEGER), CAST (SUBSTR(date, 4, 2) AS INTEGER), CAST (SUBSTR(date, 1, 2) AS INTEGER))) AS date, CAST (REPLACE(value, ',', '.') AS NUMERIC(19, 4)) AS exchangerates
                FROM aws_sqlserver_ext.openxml(var_h::BIGINT), XMLTABLE('//Record'
                    PASSING (SELECT
                        XmlData)
                    COLUMNS date CHAR(10) PATH '@Date',
                    nominal INTEGER PATH './Nominal',
                    value VARCHAR(10) PATH './Value');
            GET DIAGNOSTICS var_RowCounttmp = ROW_COUNT;
            var_RowCount := (COALESCE(var_RowCount, 0) + var_RowCounttmp)::INT;
            SELECT
                var_FinishDate + (1::NUMERIC || ' days')::INTERVAL
                INTO var_StartDate;
            SELECT
                var_MaxCount + 1
                INTO var_MaxCount;
            PERFORM aws_sqlserver_ext.sp_xml_removedocument(var_h::BIGINT);

            IF (aws_sqlserver_ext.datediff('day', var_FinishDate::TIMESTAMP, par_ToDate::TIMESTAMP) <= 0) THEN
                SELECT
                    45
                    INTO var_MaxCount;
            END IF;

            IF (aws_sqlserver_ext.datediff('day', var_StartDate::TIMESTAMP, par_ToDate::TIMESTAMP) > 54) THEN
                var_FinishDate := var_StartDate + (55::NUMERIC || ' DAY')::INTERVAL - (1::NUMERIC || ' days')::INTERVAL;
            ELSE
                var_FinishDate := par_ToDate;
            END IF;
        END LOOP;

        IF var_Trancnt = 0 THEN
            COMMIT;
        END IF;
        var_AuditMessage := '[upload].[upl_CbrUsdRate];@RowCount=' || LTRIM(to_char(COALESCE(var_RowCount, 0)::DOUBLE PRECISION, '9999999999')) || ' finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'UPL_CBRUSDRATE';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                IF var_Trancnt = 0 THEN
                    ROLLBACK;
                ELSE
                    IF xact_state() != - 1 THEN
                        ROLLBACK;
                    END IF;
                END IF;

                IF xact_state() != - 1 THEN
                    var_AuditMessage := '[upload].[upl_CbrUsdRate]; error=''' || par_ErrMessage || '''';
                    CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                    CALL audit.sp_auditerror(par_LogID := var_LogID, par_ErrorMessage := par_ErrMessage);
                END IF;
                CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE upload.upl_incomebook(IN par_excelfile VARCHAR DEFAULT NULL, IN par_excelfilecmd VARCHAR DEFAULT NULL, INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
/*
Example:
EXEC [upload].[upl_IncomeBook]
SELECT * FROM [upload].[IncomeBook]
SELECT [meta].[ufn_GetConfigValue]('ExcelFileIncomeBook');
SELECT * FROM [meta].[ConfigApp]
INSERT [meta].[ConfigApp] (Parameter, StrValue)
SELECT 'ExcelFileIncomeBook',''
SELECT 'ExcelFileIncomeBookCmd',''
INSERT [meta].[ConfigApp] (Parameter, StrValue) VALUES( 'ExcelFileIncomeBook','E:\Work\SQL\IndividualEntrepreneur\IncomeBook.xlsx')
*/
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_AuditMessage TEXT;
    var_tranc INTEGER;
    var_OverridePrintEnabling NUMERIC(1, 0);
    var_res INTEGER;
    var_OpenRowSet TEXT;
    var_sqlcmd TEXT;
    var_NewVersionCount INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    sp_auditstart$ReturnCode INTEGER;
    sp_print$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'upl_incomebook' || ']';

    IF par_ExcelFile IS NULL THEN
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBook')
            INTO par_ExcelFile;
    END IF;

    IF par_ExcelFileCmd IS NULL THEN
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBookCmd')
            INTO par_ExcelFileCmd;
    END IF;
    var_SPParams := '@ExcelFile=' || par_ExcelFile || '; @ExcelFileCmd=' || par_ExcelFileCmd || ';';
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the XACT_ABORT clause of the SET statement. Convert your source code manually.]
    SET XACT_ABORT OFF
    */
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    var_OverridePrintEnabling := 1;
    var_AuditMessage := '[upload].[upl_IncomeBook]; start';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    BEGIN
        /*
        [7811 - Severity CRITICAL - PostgreSQL doesn't support the @@TRANCOUNT function. Review the converted code to make sure that the user-defined function produces the same results as the source code.]
        SET @tranc = @@TRANCOUNT
        */
        IF var_tranc > 0 THEN
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            SAVE TRAN tran_IncomeBook
            */
            BEGIN
            END;
        ELSE
            /*
            [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
            BEGIN TRAN;
            */
            BEGIN
            END;
        END IF;
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBook')
            INTO par_ExcelFile;
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBookCmd')
            INTO par_ExcelFileCmd;
        TRUNCATE TABLE upload.incomebook;

        IF par_ExcelFile IS NULL THEN
            RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, 'Error: Parameter @ExcelFile must be defined.' USING ERRCODE = '50000';
        END IF;

        IF par_ExcelFileCmd IS NULL THEN
            RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, 'Error: Parameter @ExcelFile must be defined.' USING ERRCODE = '50000';
        END IF;
        var_OpenRowSet := 'Excel 12.0;IMEX=1;HDR=YES;DATABASE=' || par_ExcelFile;
        var_sqlcmd := '
		INSERT [upload].IncomeBook (Date, IncomeUsd, ExchangeData, ExchangeValue, ExchangeRate)
		SELECT Date, IncomeUsd, ExchangeData, ExchangeValue, ExchangeRate FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'', ''' || var_OpenRowSet || ''',''' || par_ExcelFileCmd || ''' )
		';
        CALL audit.sp_print(var_sqlcmd, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        EXECUTE var_sqlcmd;
        /*
        [7833 - Severity CRITICAL - AWS SCT can't convert the @@rowcount function in the current context. Convert your source code manually.]
        SET @RowCount = @@ROWCOUNT
        */
        IF var_tranc = 0 THEN
            COMMIT;
        END IF;
        var_AuditMessage := '[upload].[upl_IncomeBook];@RowCount=' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' finish';
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
        CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
        EXCEPTION
            WHEN OTHERS THEN
                error_catch$ERROR_NUMBER := '0';
                error_catch$ERROR_SEVERITY := '0';
                error_catch$ERROR_LINE := '0';
                error_catch$ERROR_PROCEDURE := 'UPL_INCOMEBOOK';
                GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                    error_catch$ERROR_MESSAGE = MESSAGE_TEXT;
                SELECT
                    error_catch$ERROR_MESSAGE
                    INTO par_ErrMessage;

                IF var_tranc = 0 THEN
                    ROLLBACK;
                ELSE
                    IF xact_state() != - 1 THEN
                        ROLLBACK;
                    END IF;
                END IF;

                IF xact_state() != - 1 THEN
                    var_AuditMessage := '[upload].[upl_IncomeBook]; error=''' || par_ErrMessage || '''';
                    CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);
                    CALL audit.sp_auditerror(par_LogID := var_LogID, par_ErrorMessage := par_ErrMessage);
                END IF;
                CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
                return_code := - 1;
                RETURN;
    END;
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE upload.upl_loadxmlfromfile(IN par_tcfilename VARCHAR, INOUT par_tcxmlstring VARCHAR)
AS 
$BODY$
DECLARE
    var_SPName VARCHAR(510);
    var_SPParams TEXT;
    var_SPInfo TEXT;
    var_LogID INTEGER;
    var_RowCount INTEGER;
    var_retVal INTEGER;
    var_oXML INTEGER;
    var_errorSource VARCHAR(8000);
    var_errorDescription VARCHAR(8000);
    var_loadRetVal INTEGER;
    sp_auditstart$ReturnCode INTEGER;
    sp_auditfinish$ReturnCode INTEGER;
BEGIN
    /*
    [7674 - Severity CRITICAL - AWS SCT can't convert the CONCAT_NULL_YIELDS_NULL clause of the SET statement. Convert your source code manually.]
    SET CONCAT_NULL_YIELDS_NULL ON
    */
    IF NOT EXISTS (SELECT
        *
        FROM tempdb_dbo.sysobjects
        WHERE id = aws_sqlserver_ext.object_id('tempdb.dbo.#AuditProc')) THEN
        CREATE TEMPORARY TABLE t$auditproc
        (logid INTEGER PRIMARY KEY NOT NULL);
    END IF;
    var_SPName := '[' + current_schema || '].[' + 'upl_loadxmlfromfile' || ']';
    var_SPParams := '@tcFileName=' || COALESCE('''' || par_tcFileName || '''', 'NULL') || ',' || '@tcXMLString=' || COALESCE('''' || par_tcXMLString || '''', 'NULL');
    CALL audit.sp_auditstart(par_SPName := var_SPName, par_SPParams := var_SPParams, par_LogID => var_LogID, return_code => sp_auditstart$ReturnCode);
    /* Scratch variables used in the script */
    /* Initialize the XML document */
    CALL sp_OACreate('MSXML2.DOMDocument', var_oXML);

    IF (var_retVal <> 0) THEN
        /* Trap errors if any */
        CALL sp_OAGetErrorInfo(var_oXML, var_errorSource, var_errorDescription);
        RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, var_errorDescription USING ERRCODE = '50000';
        /* Release the reference to the COM object */
        CALL sp_OADestroy(var_oXML);
        RETURN;
    END IF;
    CALL sp_OASetProperty(var_oXML, 'async', 0);

    IF var_retVal <> 0 THEN
        /* Trap errors if any */
        CALL sp_OAGetErrorInfo(var_oXML, var_errorSource, var_errorDescription);
        RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, var_errorDescription USING ERRCODE = '50000';
        /* Release the reference to the COM object */
        CALL sp_OADestroy(var_oXML);
        RETURN;
    END IF;
    /* Load the XML into the document */
    CALL sp_OAMethod(var_oXML, 'load', var_loadRetVal, par_tcFileName);

    IF (var_retVal <> 0) THEN
        /* Trap errors if any */
        CALL sp_OAGetErrorInfo(var_oXML, var_errorSource, var_errorDescription);
        RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, var_errorDescription USING ERRCODE = '50000';
        /* Release the reference to the COM object */
        CALL sp_OADestroy(var_oXML);
        RETURN;
    END IF;
    /* Get the loaded XML */
    CALL sp_OAMethod(var_oXML, 'xml', par_tcXMLString);

    IF (var_retVal <> 0) THEN
        /* Trap errors if any */
        CALL sp_OAGetErrorInfo(var_oXML, var_errorSource, var_errorDescription);
        RAISE 'Error %, severity %, state % was raised. Message: %.', '50000', 16, 1, var_errorDescription USING ERRCODE = '50000';
        /* Release the reference to the COM object */
        CALL sp_OADestroy(var_oXML);
        RETURN;
    END IF;
    /* Release the reference to the COM object */
    CALL sp_OADestroy(var_oXML);
    CALL audit.sp_auditfinish(par_LogID := var_LogID, par_RecordCount := var_RowCount, return_code => sp_auditfinish$ReturnCode);
    /*
    
    DROP TABLE IF EXISTS t$auditproc;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;

CREATE PROCEDURE uts.usp_unittest(IN par_withoutput NUMERIC DEFAULT 1, IN par_withcleanup INTEGER DEFAULT 1, IN par_testslist VARCHAR DEFAULT '', INOUT p_refcur refcursor DEFAULT NULL)
AS 
$BODY$
/* EXEC [uts].[usp_UnitTest] @TestsList='2' */
/* SELECT * FROM uts.ResultUnitTest */
/* Debug */
DECLARE
    var_TotalTestCount INTEGER;
    var_TestName VARCHAR(100);
    var_sql TEXT;
    var_TableNameOut VARCHAR(255);
    var_Error VARCHAR(500);
    var_TestID INTEGER;
    var_res INTEGER;
    var_ErrMessage TEXT;
    cur CURSOR FOR
    SELECT
        testid
        FROM t$test
        ORDER BY testid ASC NULLS FIRST;
    var_ErrorMessage VARCHAR(4000);
    var_ErrorNumber INTEGER;
    var_ErrorSeverity INTEGER;
    var_ErrorState INTEGER;
    var_ErrorLine INTEGER;
    var_ErrorProcedure VARCHAR(200);
    sp_filldimdate$refcur_1 refcursor;
BEGIN
    var_TotalTestCount := 3;
    par_TestsList := COALESCE(RTRIM(LTRIM(par_TestsList)), '');

    IF EXISTS (SELECT
        *
        FROM aws_sqlserver_ext.SYS_OBJECTS
        WHERE object_id = aws_sqlserver_ext.object_id('tempdb.dbo.#Test') AND LOWER(type) IN (LOWER('U'))) THEN
        DROP TABLE ieaccountinginusd_dbo.t$Test;
    END IF;
    CREATE TEMPORARY TABLE t$test
    AS
    SELECT
        CAST (LTRIM(RTRIM(value)) AS INTEGER) AS testid
        FROM string_split(par_TestsList, ',')
        WHERE aws_sqlserver_ext.isnumeric(LTRIM(RTRIM(value))) = 1;

    WHILE var_TotalTestCount > 0 AND LOWER(par_TestsList) = LOWER('') LOOP
        INSERT INTO t$test (testid)
        VALUES (var_TotalTestCount);
        var_TotalTestCount := (var_TotalTestCount - 1)::INT;
    END LOOP;

    IF EXISTS (SELECT
        *
        FROM aws_sqlserver_ext.SYS_OBJECTS AS o
        INNER JOIN aws_sqlserver_ext.SYS_SCHEMAS AS s
            ON o.schema_id = s.schema_id
        WHERE o.name = 'ResultUnitTest' AND LOWER(o.type) = LOWER('U') AND s.name = 'uts') THEN
        DROP TABLE uts.resultunittest;
    END IF;
    CREATE TABLE uts.resultunittest
    (testname VARCHAR(200),
        stepid INTEGER,
        error TEXT,
        datestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT (clock_timestamp()));
    INSERT INTO uts.resultunittest (testname, error)
    SELECT
        '   EXEC uts.usp_UnitTest @TestsList = ''' || COALESCE(par_TestsList, '') || '''' AS testname, '' AS error;
    OPEN cur;
    FETCH NEXT FROM cur INTO var_TestID;

    WHILE (CASE FOUND::INT
        WHEN 0 THEN - 1
        ELSE 0
    END) = 0 LOOP
        DECLARE
            error_catch$ERROR_NUMBER TEXT;
            error_catch$ERROR_SEVERITY TEXT;
            error_catch$ERROR_STATE TEXT;
            error_catch$ERROR_LINE TEXT;
            error_catch$ERROR_PROCEDURE TEXT;
            error_catch$ERROR_MESSAGE TEXT;
        BEGIN
            IF var_TestID = 1 THEN
                SELECT
                    '1. Fill Dim Date'
                    INTO var_TestName;
                CALL dbo.sp_filldimdate(par_FromDate := '20190101', par_ToDate := '20221231', par_Culture := 'ru-ru', par_IsOutput := 0, p_refcur => sp_filldimdate$refcur_1);
                CLOSE sp_filldimdate$refcur_1;

                IF NOT EXISTS (SELECT
                    *
                    FROM uts.resultunittest
                    WHERE LOWER(testname) = LOWER(var_TestName)) THEN
                    INSERT INTO uts.resultunittest (testname, error)
                    VALUES (var_TestName, '');
                END IF;
            END IF;

            IF var_TestID = 2 THEN
                SELECT
                    '2. Upload IncomeBook.xlsx into DWH'
                    INTO var_TestName;
                CALL dbo.sp_runbatch(par_ErrMessage => var_ErrMessage, return_code => var_res);
                var_sql := '
		INSERT uts.ResultUnitTest( TestName, StepID, Error)
		SELECT TestName = ''' || var_TestName || ''', StepID = 1, Error =  ' || COALESCE(var_ErrMessage, '') || '
		';

                IF var_res != 0 THEN
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    EXEC( @sql)
                    */
                    BEGIN
                    END;
                END IF;
                CALL dbo.sp_runtransform(par_ErrMessage => var_ErrMessage, return_code => var_res);
                var_sql := '
		INSERT uts.ResultUnitTest( TestName, StepID, Error)
		SELECT TestName = ''' || var_TestName || ''', StepID = 2, Error =  ' || COALESCE(var_ErrMessage, '') || '
		';

                IF var_res != 0 THEN
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    EXEC( @sql)
                    */
                    BEGIN
                    END;
                END IF;
                CALL dbo.sp_fillfactincome(par_ErrMessage => var_ErrMessage, return_code => var_res);
                var_sql := '
		INSERT uts.ResultUnitTest( TestName, StepID, Error)
		SELECT TestName = ''' || var_TestName || ''', StepID = 3, Error =  ' || COALESCE(var_ErrMessage, '') || '
		';

                IF var_res != 0 THEN
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    EXEC( @sql)
                    */
                    BEGIN
                    END;
                END IF;

                IF NOT EXISTS (SELECT
                    *
                    FROM uts.resultunittest
                    WHERE LOWER(testname) = LOWER(var_TestName)) THEN
                    INSERT INTO uts.resultunittest (testname, error)
                    VALUES (var_TestName, '');
                END IF;
            END IF;
            /* --------------------------------------- */
            EXCEPTION
                WHEN OTHERS THEN
                    error_catch$ERROR_NUMBER := '0';
                    error_catch$ERROR_SEVERITY := '0';
                    error_catch$ERROR_LINE := '0';
                    error_catch$ERROR_PROCEDURE := 'USP_UNITTEST';
                    GET STACKED DIAGNOSTICS error_catch$ERROR_STATE = RETURNED_SQLSTATE,
                        error_catch$ERROR_MESSAGE = MESSAGE_TEXT;

                    IF xact_state() <> 0 THEN
                        /*
                        [7807 - Severity CRITICAL - PostgreSQL does not support explicit transaction management commands such as BEGIN TRAN, SAVE TRAN in functions. Convert your source code manually.]
                        ROLLBACK TRANSACTION
                        */
                        BEGIN
                        END;
                    END IF;
                    SELECT
                        error_catch$ERROR_NUMBER, error_catch$ERROR_SEVERITY, error_catch$ERROR_STATE, error_catch$ERROR_LINE, COALESCE(error_catch$ERROR_PROCEDURE, '-')
                        INTO var_ErrorNumber, var_ErrorSeverity, var_ErrorState, var_ErrorLine, var_ErrorProcedure;
                    var_ErrorMessage := 'Error ' || LTRIM(to_char(var_ErrorNumber::DOUBLE PRECISION, '9999999999')) || ', Level ' || LTRIM(to_char(var_ErrorSeverity::DOUBLE PRECISION, '9999999999')) || ', State ' || LTRIM(to_char(var_ErrorState::DOUBLE PRECISION, '9999999999')) || ', Procedure ' || var_ErrorProcedure || ', Line ' || LTRIM(to_char(var_ErrorLine::DOUBLE PRECISION, '9999999999')) || ', ' || 'Message: ' || error_catch$ERROR_MESSAGE;
                    INSERT INTO uts.resultunittest (testname, error)
                    VALUES ('[' + current_schema || '].[' + 'usp_unittest' || '].' || COALESCE(var_TestName, 'NULL'), var_ErrorMessage);
                    /*
                    
                    DROP TABLE IF EXISTS t$test;
                    */
                    /*
                    
                    Temporary table must be removed before end of the function.
                    */
        END;
        FETCH NEXT FROM cur INTO var_TestID;
        /* --------------------------------------- */
    END LOOP;
    CLOSE cur;
    OPEN p_refcur FOR
    SELECT
        *
        FROM uts.resultunittest;
END;
$BODY$
LANGUAGE plpgsql;

-- ------------ Write CREATE-TRIGGER-stage scripts -----------

CREATE TRIGGER tr_dimdate_biu
BEFORE INSERT OR UPDATE
ON dbo.dimdate
FOR EACH ROW
EXECUTE PROCEDURE dbo.fn_tr_dimdate_biu();

