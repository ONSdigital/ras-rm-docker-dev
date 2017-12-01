FROM postgres:9.6.3

ENV POSTGRES_DB postgres 
ENV POSTGRES_USER postgres

ADD post-tests.sql /docker-entrypoint-initdb.d/post-tests.sql
RUN psql -U postgres < /docker-entrypoint-initdb.d/post-tests.sql

