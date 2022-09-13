CREATE SCHEMA IF NOT EXISTS replsupport;

--
-- TOC entry 283 (class 1259 OID 16884)
-- Name: excluded_from_replication_relations; Type: TABLE; Schema: ea; Owner: postgres
--

CREATE TABLE replsupport.excluded_from_replication_relations (
    schemaname character varying NOT NULL,
    tablename character varying
);


ALTER TABLE replsupport.excluded_from_replication_relations OWNER TO postgres;

--
-- TOC entry 284 (class 1259 OID 16890)
-- Name: included_schemas; Type: TABLE; Schema: ea; Owner: postgres
--

CREATE TABLE replsupport.included_schemas (
    slot_name character varying(64) DEFAULT 'dev_log_slot'::character varying,
    schema_name character varying(64)
);


ALTER TABLE replsupport.included_schemas OWNER TO postgres;

--
-- TOC entry 285 (class 1259 OID 16894)
-- Name: non_ea_tables; Type: TABLE; Schema: ea; Owner: postgres
--

CREATE TABLE replsupport.non_ea_tables (
    slot_name character varying(64) DEFAULT 'dev_log_slot'::character varying NOT NULL,
    table_name character varying(129) NOT NULL
);


ALTER TABLE replsupport.non_ea_tables OWNER TO postgres;

--
-- TOC entry 4358 (class 0 OID 0)
-- Dependencies: 285
-- Name: TABLE non_ea_tables; Type: COMMENT; Schema: ea; Owner: postgres
--

COMMENT ON TABLE replsupport.non_ea_tables IS 'Tables, which are not been extracted and applied to the mirror database';


--
-- TOC entry 4359 (class 0 OID 0)
-- Dependencies: 285
-- Name: COLUMN non_ea_tables.table_name; Type: COMMENT; Schema: ea; Owner: postgres
--

COMMENT ON COLUMN replsupport.non_ea_tables.table_name IS 'Restrictred for extract/apply table name formatted "schemaname.tablename"';


--
-- TOC entry 286 (class 1259 OID 16898)
-- Name: schema_changes; Type: TABLE; Schema: ea; Owner: postgres
--

CREATE TABLE replsupport.schema_changes (
    lsn pg_lsn,
    slot_name character varying(64),
    tx_id bigint,
    query_text text,
    row_nm integer NOT NULL
);


ALTER TABLE replsupport.schema_changes OWNER TO postgres;

--
-- TOC entry 4360 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE schema_changes; Type: COMMENT; Schema: ea; Owner: postgres
--

COMMENT ON TABLE replsupport.schema_changes IS 'schema changes for tables which are monitored';


--
-- TOC entry 287 (class 1259 OID 16904)
-- Name: schema_changes_row_nm_seq; Type: SEQUENCE; Schema: ea; Owner: postgres
--

CREATE SEQUENCE replsupport.schema_changes_row_nm_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE replsupport.schema_changes_row_nm_seq OWNER TO postgres;

--
-- TOC entry 4361 (class 0 OID 0)
-- Dependencies: 287
-- Name: schema_changes_row_nm_seq; Type: SEQUENCE OWNED BY; Schema: ea; Owner: postgres
--

ALTER SEQUENCE replsupport.schema_changes_row_nm_seq OWNED BY replsupport.schema_changes.row_nm;


--
-- TOC entry 288 (class 1259 OID 16906)
-- Name: table_check_replication; Type: TABLE; Schema: ea; Owner: postgres
--

CREATE TABLE replsupport.table_check_replication (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    server_name character varying,
    dbname character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE replsupport.table_check_replication OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 16914)
-- Name: tx_id; Type: TABLE; Schema: ea; Owner: postgres
--

CREATE TABLE replsupport.tx_id (
    slot_name character varying(64) NOT NULL,
    tx_id bigint
);


ALTER TABLE replsupport.tx_id OWNER TO postgres;

--
-- TOC entry 4362 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE tx_id; Type: COMMENT; Schema: ea; Owner: postgres
--

COMMENT ON TABLE replsupport.tx_id IS 'Last sent from slot tx_id';


--
-- TOC entry 4189 (class 2604 OID 18358)
-- Name: schema_changes row_nm; Type: DEFAULT; Schema: ea; Owner: postgres
--

ALTER TABLE ONLY replsupport.schema_changes ALTER COLUMN row_nm SET DEFAULT nextval('replsupport.schema_changes_row_nm_seq'::regclass);


--
-- TOC entry 4334 (class 0 OID 16884)
-- Dependencies: 283
-- Data for Name: excluded_from_replication_relations; Type: TABLE DATA; Schema: ea; Owner: postgres
--

INSERT INTO replsupport.excluded_from_replication_relations VALUES ('staging', NULL);
INSERT INTO replsupport.excluded_from_replication_relations VALUES ('upload', NULL);
INSERT INTO replsupport.excluded_from_replication_relations VALUES ('ea', NULL);


--
-- TOC entry 4335 (class 0 OID 16890)
-- Dependencies: 284
-- Data for Name: included_schemas; Type: TABLE DATA; Schema: ea; Owner: postgres
--

INSERT INTO replsupport.included_schemas VALUES ('dev_log_slot', 'dbo');
INSERT INTO replsupport.included_schemas VALUES ('dev_log_slot', 'meta');


--
-- TOC entry 4336 (class 0 OID 16894)
-- Dependencies: 285
-- Data for Name: non_ea_tables; Type: TABLE DATA; Schema: ea; Owner: postgres
--

INSERT INTO replsupport.non_ea_tables VALUES ('dev_log_slot', 'dbo."__EFMigrationsHistory"');



-- FUNCTION: replsupport.uf_create_dlink(character varying, character varying, character varying, character varying)
-- select replsupport.uf_create_dlink('Myserver_self','172.30.10.*','iss_dev','postgres_fdw')
-- DROP FUNCTION replsupport.uf_create_dlink(character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION replsupport.uf_create_dlink(
	dlink_name character varying,
	p_host character varying,
	p_db_name character varying,
	p_user character varying)
    RETURNS boolean
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
DECLARE 
	v_pub varchar;
	v_user varchar;
	v_counter int;
	v_port int;
	v_connection varchar;
begin
   v_user := 'postgres_fdw';
   v_port := 5432;
   dlink_name := lower(dlink_name);
   if not p_user is null then
    	v_user := p_user;
   end if;
   raise notice 'Create dlink: (%)',dlink_name;
	if ( exists(select * from information_schema._pg_foreign_servers where foreign_server_name = dlink_name) ) then
         raise notice 'Drop user mapping';
		if (exists(select 1 from information_schema.user_mappings where foreign_server_name = dlink_name and authorization_identifier = 'postgres' )) then
			v_pub := 'drop user mapping for postgres server '||dlink_name;
			execute v_pub;
		end if;
		if (exists(select 1 from information_schema.user_mappings where foreign_server_name = dlink_name and authorization_identifier = 'special_dw_dev_app')) then
			v_pub := 'drop user mapping for special_dw_dev_app server '||dlink_name;
			execute v_pub;
		end if;
		
		if (exists(select 1 from information_schema.user_mappings where foreign_server_name = dlink_name)) then
			v_pub := 'drop user mapping for special_dw_dev_app server '||dlink_name;
			raise notice 'Too manty user mapping for (%)',dlink_name ;
		end if;
		
		v_pub := 'drop server '||dlink_name;
		execute v_pub;
		
	    if not exists(select * from information_schema._pg_foreign_servers where foreign_data_wrapper_name = v_user)  then
    	  v_pub := 'drop foreign data wrapper if exists '|| v_user ;
	      execute v_pub;
   		end if;
	end if;

    --if not v_user = 'postgres_fdw' then
	if not exists(select * from information_schema._pg_foreign_servers where foreign_data_wrapper_name = v_user) then
		  
		v_pub := 'create foreign data wrapper '|| v_user ||' validator '|| v_user ||'_fdw_validator;';
		execute v_pub;
		
	end if;

  
    v_pub := 'create server '|| dlink_name ||' foreign data wrapper '|| v_user ||' OPTIONS(host '''|| p_host ||''',dbname '''||p_db_name||''',port '''||v_port||''')';
	raise notice 'command: (%)', v_pub;
	if not v_pub is null then 
		execute v_pub;
	end if;
    v_pub := 'create user mapping for postgres server '|| dlink_name ||' options (user ''postgres'', password ''postgres'')';

    if not v_pub is null then 
		execute v_pub;
	end if;

    v_connection := dblink_connect(dlink_name);
	v_counter := 0;
	v_connection := false;

	while Not v_connection = 'OK'
	loop
		perform pg_sleep(1);
		v_connection := dblink_connect(dlink_name);
		raise notice 'Wait res =(%)', v_connection;
		v_counter := v_counter + 1;
		raise notice 'Wait for connection seconds =(%)', v_counter ;
		if v_counter > 20 then
			return false;
		end if;
	end loop;
	return true;
end;
$BODY$;

ALTER FUNCTION replsupport.uf_create_dlink(character varying, character varying, character varying, character varying)
    OWNER TO postgres;

--
-- Name: uf_create_refresh_subscription(character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: ea; Owner: postgres
--

CREATE OR REPLACE FUNCTION replsupport.uf_create_refresh_subscription(p_publication_name character varying, p_host character varying, p_port character varying, p_db_name character varying, p_user character varying, p_password character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE 
v_sub_name varchar = 'sub_'||p_publication_name;
v_port varchar;
v_command varchar;
var1 int;
v_result boolean;
BEGIN
	if p_port is null or trim(p_port) = '' Then 
		v_port = '5432';
	else
		v_port = p_port;
	end if;
		
	IF (select 	count(*) from pg_foreign_server where srvname = v_sub_name) = 0 THEN 
		v_command:='CREATE SERVER  '||v_sub_name||'
			FOREIGN DATA WRAPPER postgres_fdw
			OPTIONS (host '''||p_host||''', port '''||v_port||''', dbname '''||p_db_name||'''); '
		||' CREATE USER MAPPING  FOR special_dw_dev_app
			SERVER '||v_sub_name||' 
			OPTIONS (user '''||p_user||''', password '''||p_password||''' ); '||
		'select  from replsupport.refresh_foreign_schema('''||v_sub_name||'''); '||		
		'select from replsupport.uf_create_foreign_server_tables('''||v_sub_name||'''); 
		 do $st$ BEGIN END;$st$';
		
		raise notice '%',v_command;
		
		--perform dblink_exec('server_self',v_command);
		
		--perform dblink_exec(v_sub_name,'delete from replsupport.schema_changes');
	
	else 
	
		v_command:='ALTER SERVER  '||v_sub_name||'
			OPTIONS (set host '''||p_host||''', set port '''||v_port||''',set dbname '''||p_db_name||'''); '
		||' ALTER USER MAPPING  FOR special_dw_dev_app
			SERVER '||v_sub_name||' 
			OPTIONS (set user '''||p_user||''', set password '''||p_password||''' ); '||
		'select  from replsupport.refresh_foreign_schema('''||v_sub_name||''');  
		 do $st$ BEGIN END;$st$';
		raise notice '%',v_command;
		
		--perform dblink_exec('server_self',v_command);
		
	end if;
	
	--perform dblink_exec(v_sub_name,'select from replsupport.uf_apply_tbl_permissions_sa_user(); do $st$ BEGIN END;$st$');
	
	perform dblink_exec(v_sub_name,'select from replsupport.uf_create_refresh_publication('''||p_publication_name||'''); do $st$ BEGIN END;$st$');
	
	perform dblink_exec('server_self','select from replsupport.update_ddl('''||v_sub_name||'''); do $st$ BEGIN END;$st$');
	
	perform dblink_exec(v_sub_name,'delete from replsupport.schema_changes');
	
	v_result := (select * from dblink('server_self', 'select * from replsupport.uf_pg_create_alter_subscription('''||v_sub_name ||''','''||p_publication_name||''','''||p_host||''','''||v_port||''','''||p_db_name||''','''||p_user||''','''|| p_password||''')') t1 (res boolean));
	
	perform replsupport.refresh_ea_triggers();
	
	return true;
	
END;
$_$;


ALTER FUNCTION replsupport.uf_create_refresh_subscription(p_publication_name character varying, p_host character varying, p_port character varying, p_db_name character varying, p_user character varying, p_password character varying) OWNER TO postgres;

--
-- Name: refresh_foreign_schema(character varying); Type: FUNCTION; Schema: ea; Owner: postgres
--

CREATE OR REPLACE FUNCTION replsupport.refresh_foreign_schema(p_server_name character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	schema_cursor cursor for 
	select t1.nspname from dblink(p_server_name,'select n.nspname from pg_catalog.pg_namespace n where not exists (
	select from replsupport.excluded_from_replication_relations e where 
	e.schemaname = n.nspname and e.tablename is null 
	) and left(n.nspname::varchar,3) !=''pg_'' and not n.nspname = ''information_schema''
	 
	') t1(nspname varchar) left join pg_catalog.pg_namespace n on t1.nspname = n.nspname where n.nspname is null; 
	schema_name varchar;
begin

	OPEN schema_cursor;
	
    LOOP
		fetch schema_cursor into schema_name;
		EXIT WHEN NOT FOUND;
	
		execute  'CREATE SCHEMA '||schema_name;
		execute  'grant all on schema '||schema_name||' to special_dw_dev_app';
		execute  'grant all on all tables in schema '||schema_name||' to special_dw_dev_app';
		execute  'grant all on all sequences in schema '||schema_name||' to special_dw_dev_app';
		execute  'grant all on all functions in schema '||schema_name||' to special_dw_dev_app';
		execute  'ALTER DEFAULT PRIVILEGES in schema  '||schema_name||' grant all on tables to special_dw_dev_app'; 
		execute  'ALTER DEFAULT PRIVILEGES in schema  '||schema_name||' grant all on sequences to special_dw_dev_app'; 
		execute  'ALTER DEFAULT PRIVILEGES in schema  '||schema_name||' grant all on FUNCTIONS to special_dw_dev_app'; 



		execute  'grant all on schema '||schema_name||' to dbdwuser';
		execute  'grant all on all tables in schema '||schema_name||' to dbdwuser';
		execute  'grant all on all sequences in schema '||schema_name||' to dbdwuser';
		execute  'grant all on all functions in schema '||schema_name||' to dbdwuser';
		execute  'ALTER DEFAULT PRIVILEGES in schema  '||schema_name||' grant all on tables to dbdwuser'; 
		execute  'ALTER DEFAULT PRIVILEGES in schema  '||schema_name||' grant all on sequences to dbdwuser'; 
		execute  'ALTER DEFAULT PRIVILEGES in schema  '||schema_name||' grant all on FUNCTIONS to dbdwuser';		
    END LOOP;
    
	close schema_cursor; 

	return true;	
	

end;
$$;


ALTER FUNCTION replsupport.refresh_foreign_schema(p_server_name character varying) OWNER TO postgres;

