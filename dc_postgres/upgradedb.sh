#!/bin/bash
rm -rf /upgradedb
mkdir -p /upgradedb
cp -r /prj/upgrade/* /upgradedb


srcpth='/upgradedb/*'
echo $srcpth

function appfiles {

	dir=$1*

	for file in  $dir 
	do
	if [ -d "$file" ]
	then
		echo "$file is a directory"

	elif [ -f "$file" ]
	then
		echo "$file"
		updatedb $file
		
	fi
	done
}

function replacement {
	find $1 -type f -exec sed -i 's/%dwh_sa_user%/postgres/g' {} \;
	find $1 -type f -exec sed -i 's/%dwh_master_user%/postgres/g' {} \;
	find $1 -type f -exec sed -i 's/%dwh_testro_user%/postgres/g' {} \;
	find $1 -type f -exec sed -i 's/%dwh_testexec_user%/postgres/g' {} \;
	find $1 -type f -exec sed -i 's/%dwh_ro_user%/postgres/g' {} \;
	find $1 -type f -exec sed -i 's/%dwh_etl_user%/postgres/g' {} \; 	
}

function updatedb {
	psql -v ON_ERROR_STOP=1 -h 172.30.10.2 --username "$POSTGRES_USER" -d $DB_NAME < $1
}

for file in  $srcpth 
do
	if [ -d "$file" ]
	then
		echo "$file is a directory1"
		replacement "$file/"
		appfiles "$file/" 
	fi
done