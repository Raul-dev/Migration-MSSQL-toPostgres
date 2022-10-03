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