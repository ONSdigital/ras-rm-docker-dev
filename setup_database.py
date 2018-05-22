import os

import sqlalchemy

if __name__ == '__main__':
    username = os.getenv('POSTGRES_USERNAME')
    password = os.getenv('POSTGRES_PASSWORD')
    port = os.getenv('EX_POSTGRES_PORT')
    engine = sqlalchemy.create_engine(f'postgresql://{username}:{password}@localhost:{port}/postgres')

    try:
        conn = engine.connect()
    except sqlalchemy.exc.OperationalError as e:
        print('Cannot connect to postgres.')
        exit 0

    print('Dropping pgcrypto')
    conn.execute('DROP EXTENSION IF EXISTS pgcrypto;')
    print('Creating pgcrypto')
    conn.execute('CREATE EXTENSION pgcrypto WITH SCHEMA public;')

