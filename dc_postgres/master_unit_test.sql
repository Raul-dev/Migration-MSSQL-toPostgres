CREATE OR REPLACE PROCEDURE uts.ut_unitest(p_onerrorstop boolean DEFAULT true::boolean, INOUT par_errmessage VARCHAR DEFAULT NULL, INOUT return_code int DEFAULT 0)
AS 
$BODY$
DECLARE 
	v_counter integer;
	v_res_test boolean;
    v_onerrorstop  boolean;
	var_ErrMessage VARCHAR;
	var_res INTEGER;
begin
    
	v_counter := 1;
	v_onerrorstop := true;
	
	if p_onerrorstop is null then
		v_onerrorstop := true;
	else 
		v_onerrorstop := p_onerrorstop;
	end if;

	v_res_test := uts.RESTapi_and_Python ();
	if not v_res_test then
		raise notice 'RESTapi_and_Python failed';
		return_code = v_counter;
		return ;
	else 
		raise notice 'RESTapi_and_Python Successfully completed!!';
	end if;
	v_counter := v_counter + 1;
	
	v_res_test := uts.ExcelFile_Upload();
	if not v_res_test then
		raise notice 'ExcelFile_Upload failed';
		return_code = v_counter;
		return ;
	else 
		raise notice 'ExcelFile_Upload Successfully completed!!';
	end if;
	v_counter := v_counter + 1;

	CALL dbo.sp_filldimdate(par_FromDate := '20190101', par_ToDate := '20221231');

	v_counter := v_counter + 1;

	CALL uts.DWH_ETL_Transformation( par_ErrMessage => var_ErrMessage, return_code => var_res );
	if var_res != 0 then
		raise notice 'DWH_ETL_Transformation failed';
		return_code = v_counter;
		return ;
	else 
		raise notice 'DWH_ETL_Transformation Successfully completed!!';
	end if;
	v_counter := v_counter + 1;

	return;
end;
$BODY$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION uts.RESTapi_and_Python()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE 
var_fromdate TIMESTAMP;
var_todate TIMESTAMP;
var_errmessage VARCHAR;
return_code int;
var_OverridePrintEnabling NUMERIC(1, 0);
var_AuditMessage VARCHAR;
sp_print$ReturnCode INTEGER;
var_AVGUSD double precision;
BEGIN
	var_OverridePrintEnabling := 0;
    var_AuditMessage := '### Test uts.RESTapi_and_Python Test started.';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

	var_fromdate = '20220801';
    var_todate = '20220901';
    TRUNCATE TABLE upload.cbrusdrate;
	CALL upload.upl_cbrusdrate(var_fromdate, var_todate,var_errmessage,return_code);
    var_AVGUSD := 0;
	SELECT AVG(exchangerates)::double precision into var_AVGUSD FROM upload.cbrusdrate;

	var_AuditMessage := 'Average USD/RUR for 2022 august =' ||	var_AVGUSD || ' numeric convertation '  || var_AVGUSD::numeric || ' - ' || 60.385252173913045::numeric || ' -'  || 60.385252173913045::double precision;
	CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);

	If(var_AVGUSD::numeric =60.385252173913::numeric) THEN
		return true;
	END IF;

	return false;
END;
$function$
;

CREATE OR REPLACE FUNCTION uts.ExcelFile_Upload()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE 
var_ExcelFile VARCHAR;
var_errmessage VARCHAR;
return_code INT;
var_RowCount INT;
var_OverridePrintEnabling NUMERIC(1, 0);
var_AuditMessage TEXT;
sp_print$ReturnCode INTEGER;
BEGIN
	var_OverridePrintEnabling := 0;
    var_AuditMessage := '### Test uts.ExcelFile_Upload Test started.';
    CALL audit.sp_print(var_AuditMessage, var_OverridePrintEnabling, return_code => sp_print$ReturnCode);

    IF var_ExcelFile IS NULL THEN
        SELECT
            meta.ufn_getconfigvalue('ExcelFileIncomeBook')
            INTO var_ExcelFile;
    END IF;
   
    TRUNCATE TABLE upload.IncomeBook;
   
	CALL upload.upl_incomebook(var_ExcelFile::VARCHAR, NULL, var_errmessage, return_code => sp_print$ReturnCode);
   
	SELECT COUNT(*) INTO var_RowCount FROM upload.IncomeBook;
	var_AuditMessage := 'Upload RowCount=' || LTRIM(to_char(var_RowCount::DOUBLE PRECISION, '9999999999')) || ' from file ' || var_ExcelFile;
	
	CALL audit.sp_print(var_AuditMessage, 2, return_code => sp_print$ReturnCode);

	If(COALESCE(var_RowCount,0) > 0) THEN
		return true;
	END IF;

	return false;
END;
$function$
;

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

