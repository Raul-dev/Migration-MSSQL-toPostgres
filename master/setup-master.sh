#!/bin/bash
echo 'SETUP MASTER'

echo $PGDATA

rm -rf /prj/masterfinished.txt

echo "host all all 172.30.10.0/28 trust" >> "$PGDATA/pg_hba.conf"

cp /dbsetup/master_postgresql.conf $PGDATA/postgresql.conf

set -e

## CREZTE DB
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE $DB_NAME;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -l



psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d $DB_NAME < /prj/db_dump.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d $DB_NAME < /prj/replication_support.sql



#-v ON_ERROR_STOP=1
#check user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "SELECT * FROM pg_user;"

ls /dbsetup




#cp $PGDATA/postgresql.conf /prj/org_postgresql.conf
#cp $PGDATA/pg_hba.conf /prj/org_pg_hba.conf

#cp /dbsetup/master_pg_hba.conf  $PGDATA/pg_hba.conf

#gosu postgres pg_ctl -D $PGDATA reload

echo "ok"  > /prj/masterfinished.txt