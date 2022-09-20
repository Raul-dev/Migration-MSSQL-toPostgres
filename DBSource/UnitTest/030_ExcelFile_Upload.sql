
CREATE OR REPLACE FUNCTION uts.ExcelFile_Upload()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE 
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