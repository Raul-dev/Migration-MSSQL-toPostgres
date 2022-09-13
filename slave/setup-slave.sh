#!/bin/bash
echo 'SETUP SLAVE'

echo $PGDATA
rm -rf /prj/slavefinished.txt
echo "host all all 172.30.10.0/28 trust" >> "$PGDATA/pg_hba.conf"


echo "*:*:*:postgres:postgres" > ~/.pgpass
chmod 0600 ~/.pgpass

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE $DB_NAME;"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d $DB_NAME < /prj/db_dump_mirror.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d $DB_NAME < /prj/replication_support.sql



psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "SELECT * FROM pg_user;"

ls /dbsetup


RETRIES=10

until psql -h 172.30.10.4 -U $POSTGRES_USER -d $DB_NAME -c "select 1" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "Waiting for postgres server 172.30.10.4, $((RETRIES--)) remaining attempts..."
  sleep 1
done



cp /dbsetup/slave_postgresql.conf $PGDATA/postgresql.conf

RETRIES=100
until [ -f /prj/masterfinished.txt ]
 do
  echo "Waiting for master finished, $((RETRIES--)) remaining attempts..."
  sleep 5
done



 
echo "ok"  > /prj/slavefinished.txt



