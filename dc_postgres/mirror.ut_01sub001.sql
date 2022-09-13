CREATE SCHEMA IF NOT EXISTS uts;


CREATE OR REPLACE FUNCTION uts.ut_01sub001( p_dblink varchar)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE 
    v_dblink varchar;
	v_counter int;
	v_user varchar;
begin
    v_user := 'postgres';
	v_counter := 0;
	v_dblink := p_dblink;
	raise notice '### Test 01sub001 started at %', now();
	if exists ( select * from uts."GroupType" where "Code" = 'Mytest2' ) then 
		if exists(select * from dblink(v_dblink,'select 1 as res from uts."GroupType" where "Code" = ''Mytest2'' ')  AS result( res integer)) then
			raise notice 'Exists Mytest2. Start delete record';
			PERFORM dblink(v_dblink,'delete from uts."GroupType" where "Code" = ''Mytest2'' ') ;
		else
			delete from uts."GroupType" where "Code" = 'Mytest2';
		end if;
	end if;

	while exists ( select * from uts."GroupType" where "Code" = 'Mytest2' )
	loop
		perform pg_sleep(1);
		v_counter := v_counter + 1;
		raise notice 'Wait for delete seconds =(%)', v_counter;
		if v_counter > 5 then
			return false;
		end if;
	end loop;

	if not exists ( select * from uts."GroupType" where "Code" = 'Mytest2' ) then 
		raise notice 'Dont exists Mytest2. Start insert record';
		if exists(select * from dblink(v_dblink,'select 1 as res from uts."GroupType" where "Code" = ''Mytest2'' ')  AS result( res integer)) then
			raise notice '!!!DATABASE is not syncronizing!!!!';
			return false;
		else
			perform dblink(v_dblink,'insert into uts."GroupType" ("Code", "Name") values(''Mytest2'',''Mytest2'')');
		end if;		
	end if;
	
	while not exists ( select * from uts."GroupType" where "Code" = 'Mytest2' )
	loop
		perform pg_sleep(1);
		v_counter := v_counter + 1;
		raise notice 'Wait for insert seconds =(%)', v_counter;
		if v_counter > 5 then
			return false;
		end if;
	end loop;
    raise notice 'Successfully completed!';

	return true;
end;
$function$
;
