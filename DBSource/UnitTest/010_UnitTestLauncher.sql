CREATE OR REPLACE FUNCTION uts.ut_unitest(p_onerrorstop boolean DEFAULT true::boolean)
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
	
	v_res_test := uts.ExcelFile_Upload();
	if not v_res_test then
		raise notice 'ExcelFile_Upload failed';
		return false;
	else 
		raise notice 'ExcelFile_Upload Successfully completed!!';
	end if;
	v_counter := v_counter + 1;

	return true;
end;
$function$
;