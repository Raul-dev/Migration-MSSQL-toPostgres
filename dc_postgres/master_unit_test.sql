﻿CREATE OR REPLACE FUNCTION uts.ut_unitest(p_onerrorstop boolean DEFAULT true::boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE 
	v_counter integer;
	v_res_test boolean;
    v_onerrorstop  boolean;
begin
    
	v_counter := 0;
	v_onerrorstop := true;
	
	
	if p_onerrorstop is null then
		v_onerrorstop := true;
	else 
		v_onerrorstop := p_onerrorstop;
	end if;
	

	v_res_test := uts.RESTapi_and_Python ();
	if not v_res_test then
		raise notice 'RESTapi_and_Python failed';
		return false;
	else 
		raise notice 'RESTapi_and_Python Successfully completed!!';
	end if;
	v_counter := v_counter + 1;

	return true;
end;
$function$
;

CREATE OR REPLACE FUNCTION uts.RESTapi_and_Python()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE 
DECLARE
var_fromdate TIMESTAMP;
var_todate TIMESTAMP;
var_errmessage text;
return_code int;
var_OverridePrintEnabling NUMERIC(1, 0);
var_AuditMessage TEXT;
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