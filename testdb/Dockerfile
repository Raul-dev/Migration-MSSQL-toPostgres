FROM alpine:3.8
RUN apk update &&\
 apk upgrade &&\
 apk add bash &&\
 apk add postgresql-client &&\
 apk add openjdk8-jre &&\
 apk update &&\
 apk add nano &&\
 mkdir /prj
 
# Change entry point
COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
#CMD ["gosu", "postgres", "postgres"]