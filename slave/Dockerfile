FROM postgressource

ADD ./dbsetup /dbsetup
COPY ./setup-slave.sh /docker-entrypoint-initdb.d/setup-slave.sh

RUN chmod 0666 /docker-entrypoint-initdb.d/setup-slave.sh


