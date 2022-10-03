#!/bin/bash

echo 'START TEST001 file'

export POSTGRES_USER=postgres
set PGPASSWORD=postgres

#cnt=2
#until [$cnt -eq 1];
# do
#  echo "Test1: Waiting for slave finished, $((RETRIES--)) remaining attempts..."
#  sleep 500
#done
#upgrade


if [ $UPGRADEDB ]; then 
	if [ $UPGRADEDB = true ]; then

	

cat >&2 <<-'EOWARN'

******************************************
                UPGRADE DB
******************************************
EOWARN
		
		chmod +x /prj/upgradedb.sh
		/prj/upgradedb.sh
	fi
fi

echo 'Apply master test'
psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "$POSTGRES_USER" -d $DB_NAME < /prj/master_unit_test.sql

echo 'Apply mirror test'
psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "$POSTGRES_USER" -d $DB_NAME < /prj/mirror.ut_01sub001.sql


cat >&2 <<-'EOWARN'

******************************************
                SLAVE UNIT TEST
******************************************
EOWARN
		

psql -v ON_ERROR_STOP=1 -h 172.30.10.4 --username "$POSTGRES_USER" --dbname $DB_NAME  <<-EOSQL
select uts.ut_01sub001( 'masterlink' );

EOSQL


cat >&2 <<-'EOWARN'

******************************************
                MASTER UNIT TEST 
******************************************
EOWARN
		

psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "$POSTGRES_USER" --dbname $DB_NAME  <<-EOSQL
CALL uts.ut_unitest();

EOSQL


