DROP ROUTINE IF EXISTS audit.sp_auditerror(IN INTEGER, IN VARCHAR, IN NUMERIC);

DROP ROUTINE IF EXISTS audit.sp_auditfinish(IN INTEGER, IN INTEGER, IN TEXT, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_auditstart(IN VARCHAR, IN TEXT, IN VARCHAR, INOUT INTEGER, INOUT int);

DROP ROUTINE IF EXISTS audit.sp_print(IN TEXT, IN NUMERIC, INOUT int);

insert into meta.configapp(parameter,strvalue) VALUES('AuditPrintAll',1);

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
    var_AuditPrintEnable INTEGER;
BEGIN
    var_part := 4000;
    var_len := LENGTH(par_string);
    SELECT
        meta.ufn_getconfigvalue('AuditPrintAll')::INTEGER
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