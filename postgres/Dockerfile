FROM postgres:9.6.3

ENV POSTGRES_DB postgres 
ENV POSTGRES_USER postgres

ADD action_groundzero.sql /docker-entrypoint-initdb.d/action_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/action_groundzero.sql

ADD case_groundzero.sql /docker-entrypoint-initdb.d/case_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/case_groundzero.sql

ADD actionexp_groundzero.sql /docker-entrypoint-initdb.d/actionexp_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/actionexp_groundzero.sql

ADD sample_groundzero.sql /docker-entrypoint-initdb.d/sample_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/sample_groundzero.sql

ADD iac_groundzero.sql /docker-entrypoint-initdb.d/iac_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/iac_groundzero.sql

ADD collex_groundzero.sql /docker-entrypoint-initdb.d/collex_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/collex_groundzero.sql

ADD notify_groundzero.sql /docker-entrypoint-initdb.d/notify_groundzero.sql
RUN chmod 755 /docker-entrypoint-initdb.d/notify_groundzero.sql

ADD collection_instrument_test_data.sql /collection_instrument_test_data.sql
RUN chmod 755 /collection_instrument_test_data.sql
