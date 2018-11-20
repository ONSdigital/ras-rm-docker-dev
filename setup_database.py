import os

import sqlalchemy
from retrying import retry

def retry_if_sqlalchemy_error(exception):
    print(f'error has occurred: {str(exception)}')
    return isinstance(exception, sqlalchemy.exc.OperationalError)


@retry(retry_on_exception=retry_if_sqlalchemy_error, wait_fixed=10000, stop_max_delay=600000, wrap_exception=True)
def retry_connection(engine):
    return engine.connect()



if __name__ == '__main__':
    username = os.getenv('POSTGRES_USERNAME')
    password = os.getenv('POSTGRES_PASSWORD')
    port = os.getenv('EX_POSTGRES_PORT')

    engine = sqlalchemy.create_engine(f'postgresql://{username}:{password}@localhost:{port}/postgres')
    conn = retry_connection(engine)

    print('Dropping pgcrypto')
    conn.execute('DROP EXTENSION IF EXISTS pgcrypto CASCADE;')
    print('Creating pgcrypto')
    conn.execute('CREATE EXTENSION pgcrypto WITH SCHEMA public;')

