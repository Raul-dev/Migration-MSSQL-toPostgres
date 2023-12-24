#!/bin/bash

echo 'SETUP TEST'
echo "*:*:*:postgres:postgres" > ~/.pgpass
chmod 0600 ~/.pgpass

ls /prj


until [ -f /prj/masterfinished.txt ]
 do
  echo "Test: Waiting for master finished, $((RETRIES--)) remaining attempts..."
  sleep 5
done

until [ -f /prj/slavefinished.txt ]
 do
  echo "Test: Waiting for slave finished, $((RETRIES--)) remaining attempts..."
  sleep 5
done

set PGPASSWORD=postgres

echo 'Ping master server'

ping -c 1 -W 1 postgresone

echo 'Connect to master DB'

RETRIES=1000
sleep 5
until psql -h 172.30.10.2 -U postgres -d $DB_NAME -c "select 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "Test: Waiting SELECT from master postgres server, $((RETRIES--)) remaining attempts..."
  sleep 5
done

RETRIES=1000
sleep 5
until psql -h 172.30.10.4 -U postgres -d $DB_NAME -c "select 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "Test: Waiting SELECT from slave postgres server, $((RETRIES--)) remaining attempts..."
  sleep 5
done

echo 'Ping slave server'
ping -c 1 -W 1 postgrestwo
psql -h 172.30.10.4 -U postgres -d $DB_NAME -c "select 1" 

cat /proc/version

psql -h 172.30.10.2 -U postgres -d $DB_NAME -c "SELECT version();" 

if [ $TESTONLY ]; then 
	if [ $TESTONLY = true ]; then
		/prj/test001.sh
		exit
	fi
fi

echo '****Setup master'		
psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "postgres" --dbname $DB_NAME  <<-'EOWARN'
do
$$
BEGIN
IF ( NOT EXISTS (select r.rolname, u.usename  from  pg_auth_members as m  left join pg_roles as r on m.grantor = r.oid  left join pg_user u on m.member = u.usesysid where u.usename ='replica'	) ) THEN
	CREATE ROLE replica WITH LOGIN PASSWORD 'replica';
	ALTER ROLE replica WITH REPLICATION;
    raise notice 'Role assignment start';
	GRANT  postgres TO replica;
	
END IF;
END;
$$;

EOWARN

psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "postgres" --dbname $DB_NAME -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO replica;"

psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "postgres" --dbname $DB_NAME  <<-'EOWARN'
do
$$
BEGIN
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA uts TO replica;
IF ( NOT EXISTS (select * from pg_publication where pubname = 'application')) THEN
	CREATE PUBLICATION application WITH (publish = 'insert, update, delete');
END IF;

END;
$$;

ALTER PUBLICATION application OWNER TO postgres;
ALTER PUBLICATION application ADD TABLE uts."GroupType";

EOWARN


echo '*** Setup slave'

echo "Create dlink server_self"
psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "postgres" --dbname $DB_NAME -c "select replsupport.uf_create_dlink('server_self','172.30.10.4','$DB_NAME','postgres');"

echo "Create dlink 2 masterlink"
psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "postgres" --dbname $DB_NAME -c "select replsupport.uf_create_dlink('masterlink','172.30.10.2','$DB_NAME','postgres');"

echo 'select * from MASTER.pg_replication_slots'
psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "postgres" --dbname $DB_NAME -c "select * from pg_replication_slots"

echo 'select * FROM SLAVE.pg_catalog.pg_subscription'
psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "postgres" --dbname $DB_NAME -c "select * FROM pg_catalog.pg_subscription where subslotname = 'sub_application';"


cat >&2 <<-EOSQL

******************************************
                CREATE SUBSCRIPTION
******************************************
EOSQL

psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "postgres" --dbname $DB_NAME <<-'EOWARN'	

do
$$
declare
varr text;
BEGIN
IF ( EXISTS (select * FROM pg_catalog.pg_subscription where subslotname = 'sub_application' ) )THEN
    raise notice '####1 Prepare subscription sub_application for drop!!!';
	alter subscription sub_application disable;
	alter subscription sub_application SET (slot_name = NONE);
	raise notice  '####2 Drop subscription sub_application!!!';
    drop subscription sub_application;

END IF;

IF ( EXISTS (select * from dblink('masterlink','select 1 as res from pg_replication_slots where "slot_name" = ''sub_application'' ')  AS result( res integer) ) )then
	raise notice  '####3 Droped subscription [sub_application] sucessfully';

	varr = (select res from dblink('masterlink','select pg_drop_replication_slot(''sub_application'')') AS result( res text));
	raise notice  '####4 pg_drop_replication_slot excecution result: %', varr;
END IF;
END;
$$;

select 'Drop subscription sub_application!!!';
drop subscription if exists sub_application;

EOWARN

psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "postgres" --dbname $DB_NAME -c "CREATE SUBSCRIPTION sub_application CONNECTION 'host=172.30.10.2 user=replica password=replica dbname=$DB_NAME' PUBLICATION application WITH (copy_data = false, slot_name = 'sub_application');"


chmod +x /prj/test001.sh

/prj/test001.sh

