#FROM cosmosdigital/postgres11.1-alpine3.8
FROM postgres:14-alpine
ENV POSTGRES_USER postgres 
ENV POSTGRES_PASSWORD postgres 
ENV POSTGRES_DB postgres 
ENV PG_REP_USER replica 
ENV PG_REP_PASSWORD replica




RUN mkdir /prj &&\
 mkdir -p /arcivepg && chmod 700 /arcivepg && chown -R postgres:postgres /arcivepg &&\
 mkdir -p /dbsetup && chmod 700 /dbsetup && chown -R postgres:postgres /dbsetup


RUN apk add --update htop
RUN apk add py3-setuptools &&\
apk add --update py-pip &&\
apk add postgresql-dev 

RUN pip install --upgrade pip 
RUN apk add alpine-sdk 
RUN apk add zlib-dev
RUN apk add lz4-dev 
RUN apk add gawk
RUN pip install pgxnclient
RUN pgxn install pg_repack
RUN apk add postgresql-plpython3 
RUN pip install requests


