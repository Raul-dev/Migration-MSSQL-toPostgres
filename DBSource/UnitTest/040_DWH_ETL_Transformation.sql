
CREATE OR REPLACE PROCEDURE uts.DWH_ETL_Transformation(INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
DECLARE 
    var_TestName VARCHAR(100);
    var_sql TEXT;
    var_res INTEGER;
    error_catch$ERROR_NUMBER TEXT;
    error_catch$ERROR_SEVERITY TEXT;
    error_catch$ERROR_STATE TEXT;
    error_catch$ERROR_LINE TEXT;
    error_catch$ERROR_PROCEDURE TEXT;
    error_catch$ERROR_MESSAGE TEXT;
    var_ErrMessage VARCHAR;
    var_incvaluesum NUMERIC(19,4);
    var_AuditMessage TEXT;
    var_OverridePrintEnabling INTEGER;
    sp_print$ReturnCode INTEGER;
BEGIN
        var_OverridePrintEnabling :=0;

        var_TestName := 'DWH_ETL_Transformation';
        CALL dbo.sp_runbatch(par_ErrMessage => var_ErrMessage, return_code => var_res);
        var_sql := '
		INSERT uts.ResultUnitTest( TestName, StepID, Error)
		SELECT TestName = ''' || var_TestName || ''', StepID = 1, Error =  ' || COALESCE(var_ErrMessage, '') || '
		';

        IF var_res != 0 THEN
            EXECUTE var_sql; 
			return_code := -2;
            RETURN ;
        END IF;

        CALL dbo.sp_runtransform(par_ErrMessage => var_ErrMessage, return_code => var_res);
        var_sql := '
		INSERT uts.ResultUnitTest( TestName, StepID, Error)
		SELECT TestName = ''' || var_TestName || ''', StepID = 2, Error =  ' || COALESCE(var_ErrMessage, '') || '
		';

        IF var_res != 0 THEN
            EXECUTE var_sql; 
			return_code := -3;
            RETURN ;
        END IF;

        CALL dbo.sp_fillfactincome(par_ErrMessage => var_ErrMessage, return_code => var_res);
        var_sql := '
		INSERT uts.ResultUnitTest( TestName, StepID, Error)
		SELECT TestName = ''' || var_TestName || ''', StepID = 3, Error =  ' || COALESCE(var_ErrMessage, '') || '
		';

        IF var_res != 0 THEN
            EXECUTE var_sql; 
			return_code := -4;
            RETURN ;
        END IF;
        
        SELECT SUM(incomevalue) AS incomevalue INTO var_incvaluesum FROM dbo.factincome;
        var_AuditMessage := 'Summary income = ' || LTRIM(to_char(COALESCE(var_incvaluesum ,0)::DOUBLE PRECISION, '9999999999.9999')) ;
        CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);
	
        IF COALESCE(var_incvaluesum ,0) = 0 THEN
            INSERT INTO uts.resultunittest (testname, error)
            VALUES (var_TestName, 'Empty dbo.factincome table.');
            --RETURN false;
            return_code :=-5;
        ELSE
            IF NOT EXISTS (SELECT * FROM uts.resultunittest WHERE LOWER(testname) = LOWER(var_TestName)) THEN
                INSERT INTO uts.resultunittest (testname, error)
                VALUES (var_TestName, '');
            END IF;
            return_code :=0;
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
            
			--INSERT INTO uts.resultunittest (testname, error)
            --VALUES ('[' + current_schema || '].[' + 'usp_unittest' || '].' || COALESCE(var_TestName, 'NULL'), var_ErrorMessage);
            par_errmessage := error_catch$ERROR_MESSAGE;
            return_code :=-1;
        RETURN ;
END;
$BODY$
LANGUAGE plpgsql;

