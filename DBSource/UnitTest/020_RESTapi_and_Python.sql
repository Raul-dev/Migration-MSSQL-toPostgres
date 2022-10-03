
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