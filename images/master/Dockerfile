FROM postgressource
ADD ./dbsetup /dbsetup
#COPY dump_yourdb.sql /dbsetup/dump_yourdb.sql

COPY ./setup-master.sh /docker-entrypoint-initdb.d/setup-master.sh

RUN chmod 0666 /docker-entrypoint-initdb.d/setup-master.sh