Param
(
	[parameter(Mandatory=$false)][bool]$IsRecompileImage=$false,
	[parameter(Mandatory=$false)][bool]$IsMaserOnly=$false
)

$res =Get-Process 'com.docker.proxy' -ErrorAction SilentlyContinue
if([string]::IsNullOrEmpty($res)){
	Write-Host "DOCKER is not running. Visit and download https://docs.docker.com/docker-for-windows/install/ " -fore red
	exit -1
}

$ResultSearch = docker ps | Select-String -Pattern "postgres-master"
if([string]::IsNullOrEmpty($ResultSearch)){
	Write-Host "Stoped container: docker-compose -f docker-compose.yml down"
	docker-compose -f docker-compose.yml down

}
if($IsRecompileImage){
	docker rmi postgressource -f   #- base image
	docker rmi postgrestest -f
	docker rmi postgresone -f
	docker rmi postgrestwo -f
	docker rm postgres-test -f
	docker rm postgres-master -f
	docker rm postgres-slave -f
}
$ResultSearch = docker ps -a | Select-String -Pattern "postgres-test"
if([string]::IsNullOrEmpty($ResultSearch)){
	Write-Host "remove container postgres-test"
	docker rm postgres-test
}

docker ps -a --filter "ancestor=postgresone" --format "{{.ID}}" | ForEach-Object {
	docker rm $_
}
docker ps -a --filter "ancestor=postgressource" --format "{{.ID}}" | ForEach-Object {
	docker rm $_
}

#Create dump script
$SourceDBFolder = Convert-Path .
$OutputDumpFile = $SourceDBFolder + "\dc_postgres\db_dump.sql"
$OutputDumpMirrorFile = $SourceDBFolder + "\dc_postgres\db_dump_mirror.sql"
$SourceDBFolder = $SourceDBFolder + "\DBSource"

Remove-Item -Path $OutputDumpFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $OutputDumpMirrorFile -Force -ErrorAction SilentlyContinue

Write-Host "Build DB dump script from folder: "$SourceDBFolder" to file "$OutputDumpFile
$FileFilter = "???_*.sql"
Write-Host "Source file filter: "$FileFilter
Get-ChildItem $SourceDBFolder -Attributes !Directory
$Files = Get-ChildItem $SourceDBFolder -Attributes !Directory -Filter $FileFilter
for ($i=0; $i -lt $Files.count; $i++){
	$SqlFile = $SourceDBFolder+"\"+$Files[$i]
	$error.Clear()
	$LASTEXITCODE = 0
	Write-Host "Step"$i": "$SqlFile
	Get-Content $SqlFile | Out-File -FilePath $OutputDumpFile -Encoding "UTF8" -Append
}

Copy-Item -Path $OutputDumpFile -Destination $OutputDumpMirrorFile

#UnitTest
$SourceDBFolder = Convert-Path .
$OutputDumpFile = $SourceDBFolder + "\dc_postgres\master_unit_test.sql"
$SourceDBFolder = $SourceDBFolder + "\DBSource\UnitTest"

Remove-Item -Path $OutputDumpFile -Force -ErrorAction SilentlyContinue

Write-Host "Build DB dump script from folder: "$SourceDBFolder" to file "$OutputDumpFile
$FileFilter = "???_*.sql"
Write-Host "Source file filter: "$FileFilter
Get-ChildItem $SourceDBFolder -Attributes !Directory
$Files = Get-ChildItem $SourceDBFolder -Attributes !Directory -Filter $FileFilter
for ($i=0; $i -lt $Files.count; $i++){
	$SqlFile = $SourceDBFolder+"\"+$Files[$i]
	$error.Clear()
	$LASTEXITCODE = 0
	Write-Host "Step"$i": "$SqlFile
	Get-Content $SqlFile | Out-File -FilePath $OutputDumpFile -Encoding "UTF8" -Append
}


#Check docker folder sharing
$Projectpath = Convert-Path .
$PostgresFolder = $Projectpath +"\dc_postgres"
$Opts = "-v ${PostgresFolder}:/prj "
Write-Host "Check shared database folder: "$PostgresFolder
Write-Host "cmd: docker run --rm ${Opts} alpine ls /prj"

$IsFolderSharing = $false
Invoke-Expression -Command "docker run --rm ${Opts} alpine ls /prj" | ForEach-Object {
	Write-Host $_
	IF ($_.Contains("db_dump.sql")){
		$IsFolderSharing = $true
	}
}
Write-Host $IsFolderSharing
if(-Not $IsFolderSharing){
	Write-Host "Not exists db_dump.sql or folder ./dc_postgres not sharing for docker."
	exit
}

#Check network
$ResultSearch = docker network ls | Select-String -Pattern "static-network"
write-Host $ResultSearch
if([string]::IsNullOrEmpty($ResultSearch)){
	docker network create --gateway 172.30.10.1 --subnet 172.30.10.0/28 static-network
	# if you get error: Pool overlaps with other one on this address space. found wrong network and remove it or change IP in container.
	# docker network inspect $(docker network ls -q)
	# docker network rm static-network
}


Write-Host $IsMaserOnly		
if(-Not $IsMaserOnly){
	Write-Host " docker-compose  start"
	docker-compose -f docker-compose.yml up
	exit
}



$ResultSearch = docker image ls | Select-String -Pattern "postgressource"
if([string]::IsNullOrEmpty($ResultSearch) ){
	cd source
	docker build -f Dockerfile --rm -t postgressource . --progress=plain
	cd ..

}
cd master
docker build -f Dockerfile --rm -t postgresone . --progress=plain
cd ..
# -d  -detach
$Cmd = "docker run -i ${Opts} -e DB_NAME=ieaccountinginusd -e PG_CONFIG=/usr/local/bin/ --network static-network --ip 172.30.10.2 -p 54321:5432 -t --name postgres-master  postgresone:latest"
Write-Host $Cmd
Invoke-Expression -Command $Cmd
docker logs -n 30 postgres-master    # View logs
