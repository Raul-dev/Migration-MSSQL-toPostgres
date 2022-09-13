Param
(
	[parameter(Mandatory=$false)][bool]$IsRecompileImage=$false
)
if($IsRecompileImage){
	docker rmi postgrestest -f
	docker rmi postgressource -f
	docker rmi postgresone -f
	docker rmi postgrestwo -f
	docker rm postgres-test -f
	docker rm postgres-master -f
	docker rm postgres-slave -f
	exit
}
$IsPostgresMasterExists = $false
docker ps | ForEach-Object {
	IF ($_.Contains("postgres-test")){
		Write-Host "Stoped container postgres-test"
		docker stop postgres-test
	}
	IF ($_.Contains("postgres-master")){
		$IsPostgresMasterExists = $true
	}
}
if(-Not $IsPostgresMasterExists){
	Write-Host "postgres-master container not running."
	Write-Host "Launch first: docker-compose -f docker-compose.yml up"
	exit
}

docker ps -a | ForEach-Object {
	IF ($_.Contains("postgres-test")){
		Write-Host "Remove container postgres-test"
		docker rm postgres-test
	}
}



#Check network
$IsNetworkExists = $fale
docker network ls | ForEach-Object {
	IF ($_.Contains("static-network")){
		$IsNetworkExists = $true
	}
}
if(-Not $IsNetworkExists){
	docker network create --gateway 172.30.10.1 --subnet 172.30.10.0/28 static-network
	# if you get error: Pool overlaps with other one on this address space. found wrong network and remove it or change IP in container.
	# docker network inspect $(docker network ls -q)
	# docker network rm static-network
}
	
$Projectpath = Convert-Path .
$PostgresFolder = $Projectpath +"\dc_postgres"
$Opts = "-v ${PostgresFolder}:/prj "
Write-Host "Shared database folder: "$PostgresFolder


Invoke-Expression -Command "docker run --rm ${Opts} alpine ls /prj" | ForEach-Object {
	Write-Host $_
	IF ($_.Contains("phoenix_shrink.bak")){
		Write-Host "Not found db dump phoenix_shrink.bak"
	}
}
cd testdb
###docker build -f Dockerfile_source --rm -t postgrestest_source .
docker build -f Dockerfile --rm -t postgrestest .
cd ..

$Cmd = "docker run -e DB_NAME=ieaccountinginusd -e TESTONLY=false -e UPGRADEDB=false ${Opts}  --network static-network --ip 172.30.10.3 -t --name postgres-test  postgrestest:latest bash"
Write-Host $Cmd
Invoke-Expression -Command $Cmd

# only test
# docker run -e TESTONLY=true -v C:\Install\terra0.12.6:/liquibase -v C:\Work18_10_19\Postgres\PHOENIX:/dbupgrade  -v C:\Work18_10_19\Postgres\Replicationlogic\dc_postgres:/prj  --network replicationlogic_static-network --ip 172.30.10.3 -t postgrestest:latest bash
####
#docker run -e TESTONLY=true -v C:\Work18_10_19\Postgres\PHOENIX:/dbupgrade  -v C:\Work18_10_19\Postgres\Replicationlogic\dc_postgres:/prj  --network replicationlogic_static-network --ip 172.30.10.3 -t postgrestest:latest bash
#docker run -e TESTONLY=true -e UPGRADEDB=true -v C:\Work18_10_19\Postgres\Replicationlogic\dc_postgres:/prj  --network replicationlogic_static-network --ip 172.30.10.3 -t postgrestest:latest bash

#/liquibase/liquibase status –defaultsFile /prj/liquibase.properties
# docker exec -it postgres-test bash 

