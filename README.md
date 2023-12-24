# System Requirements
- Windows 10 64-bit: Pro, Enterprise, or Education (build 19044 or later).
- Hyper-V and Containers Windows features must be enabled.
	
# Install docker 
1. Install Docker Desktop (download https://docs.docker.com/docker-for-windows/install/ )
2. Docker -> Settings -> Shared Drives   share drive with project
3. Check docker setup
```
 docker run --rm -v c:/Users:/data alpine ls /data
```
4. Git clone without replacing LF by CRLF. Use option --config core.autocrlf=false 
```
git clone https://github.com/Raul-dev/Migration-MSSQL-toPostgres.git --config core.autocrlf=false 
```
 
# RUN from powershell
-rebuild master and slave postgres environment:
```
./db_start.ps1    
```
or 
```
docker-compose -f docker-compose.yml up   
```
<p align="center">
  <img src="./doc/img/testlog.jpg" width="350" alt="accessibility text">
</p>

- launch test from dc_postgres/test001.sh:
```
./Test_Start.ps1
```

# Connections:
To master DB :
		localhost
user: 	postgres
pwd: 	postgres
port: 	54321
To slave DB
port:   54322


# Other cmd
```
#build postgressource image from Postgresql source https://ftp.postgresql.org/pub/source/v16.1/
cd ./images/source
docker build --no-cache --progress=plain -t postgressource .
docker build -f Dockerfile2 --no-cache --progress=plain -t postgressource2 .
docker rmi postgressource
docker run --name postgresres -p 54321:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -d postgressource
docker rm postgresres
docker logs postgresres
docker run --rm -it --entrypoint sh postgressource2

#restart slave DB server:
docker exec -it postgres-slave gosu postgres pg_ctl restart
exec cmd:
docker exec -it postgres-slave bash
```

# Setup DB server
- listen_addresses = '172.30.10.2' Master
- listen_addresses = '172.30.10.4' Slave
- wal_level = logical	
- max_stack_depth = 2MB -> 4MB
- work_mem = 4mb -> 16MB

	
# TODO Liquibase https://habr.com/ru/post/333762/
```
#Install java docker alpine
apk add openjdk8-jre
apk update
apk add maven

wget https://github.com/liquibase/liquibase/releases/download/v3.8.6/liquibase-3.8.6.tar.gz
wget https://jdbc.postgresql.org/download/postgresql-42.2.10.jar

wget https://github.com/liquibase/liquibase/releases/download/v3.6.2/liquibase-3.6.2.tar.gz
wget https://github.com/liquibase/liquibase/releases/download/liquibase-parent-3.6.2/liquibase-3.6.2-bin.tar.gz

mkdir /liquibase &&\
cd /liquibase &&\
export PATH=$PATH:/liquibase 

cp /prj/liquibase-3.8.6.tar.gz liquibase-3.8.6.tar.gz &&\
tar xzvf liquibase-3.8.6.tar.gz

cp /prj/liquibase.properties liquibase.properties &&\
cp /prj/postgresql-42.2.10.jar postgresql-42.2.10.jar &&\
cp /prj/db.changelog.xml db.changelog.xml

cd /dbupgrade
liquibase --defaultsFile=/prj/liquibase.properties --url=jdbc:postgresql://172.30.10.2/DatabaseName --changeLogFile=/dbupgrade/app/changelog/004_app_user.xml status
liquibase --defaultsFile=/prj/liquibase.properties --url=jdbc:postgresql://172.30.10.2/DatabaseName --changeLogFile=/dbupgrade/app/changelog/004_app_user.xml upgrade
```

# Backup and restor DB
```
pg_dump -U postgres -p 5432 db >> /prj/db.bak --schema-only
psql -U postgres  -c "CREATE DATABASE tests1;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "tests1" < /prj/db.bak
```

# Software can be download here: 
- Postgres 14.5 for Windows https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
- AWS Schema Conversion Tool https://docs.aws.amazon.com/SchemaConversionTool/latest/userguide/CHAP_Installing.html#CHAP_Installing.Procedure
