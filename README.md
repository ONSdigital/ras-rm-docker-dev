# ras-rm-docker-dev
A combined repository for unifying approach to running RAS and RM in Docker

## Pre-requisites
1. Create a docker hub account
1. Ask to become a team member of sdcplatform
1. Run `docker login` in a terminal and use your docker hub account
1. Run `docker network create rasrmdockerdev_default` to create the docker network
1. Have at least 16GiB of memory allocated to Docker

## Setup
Based on python 3.6

Use [Pyenv](https://github.com/pyenv/pyenv) to manage installed Python versions

[Pipenv](https://docs.pipenv.org/) is required locally for running setup scripts

```bash
pip install -U pipenv
```

## Quickstart
![make up](https://media.giphy.com/media/xULW8lyhMJjzyO33sA/giphy.gif)
```
make up
```

## Slowstart

There are 3 docker-compose files in this repository:
- dev.yml - spins up the core development containers such as postgres, rabbit and sftp
- ras-services.yml - spins up the python services such as party and collection-instrument
- rm-services.yml - spins up the Java and Go services such as survery service and action service

These can be run together as per the Quickstart section or individually.  Additionally individual services can be specified at the end of the command. For example:

```
docker-compose -f dev.yml -f ras-services.yml up -d
```

This will spin up the development containers and the ras-services.

```
docker-compose -f rm-services.yml up -d collection-exercise
```

This will spin up just the collection exercise service.

## Development

### Running in docker with local changes
Development using this repo can be done by doing the following:

1. Make changes to whichever repository.  In this example we'll suppose you're changing the response-operations-ui repository.
1. Stop the service with `docker-compose -f ras-services.yml stop response-operations-ui`
1. Delete the stopped container with `docker-compose -f ras-services.yml rm response-operations-ui`
1. Rebuild the image and tag it as the latest to 'trick' the build into thinking we already have the latest and don't need to pull down the image from dockerhub.
    1. Python repo - `docker build . -t sdcplatform/response-operations-ui:latest`
    1. Java repo - `mvn clean install` will automatically rebuild the docker image
1. Finally, start the service again with `docker-compose -f ras-services.yml up -d response-operations-ui`

### Running natively with local changes
1. Stop all the services `make down`
1. Make changes to whichever repository.  In this example we'll suppose you're changing the response-operations-ui repository.
1. Update [.env](./.env) so that any services that speak to the service(s) running locally has the host configured as `docker.for.mac.localhost`. e.g. `PARTY_HOST=docker.for.mac.localhost`
1. Finally, start the services excluding the service(s) you are running locally
1. Run the service(s) locally

### Running Python services mounted as a volume (allows hot-reloading)
1. Bring up all the services `make up`
2. Make sure that the environment variable `RAS_HOME` has been set, and points to the root of your RAS project folders e.g. `ras-frontstage` would be found at `$RAS_HOME/ras-frontstage`
3. Run `make local` to run all the Python services, or `docker-compose -f ras-local.yml up -d name-of-service` to run a single service

### pgAdmin 4
1. Start all the services `make up`
1. Navigate to `localhost:80` in your browser
1. Login with `ons@ons.gov` / `secret`
1. Object -> Create -> Server...
1. Give it a suitable name then in the connection tab:
    1. `postgres` for the host name
    1. `5432` for the port
    1. `postgres` for the maintenance database
    1. `postgres` for the username
1. Click save to close the dialog and connect to the postgres docker container

## Troubleshooting
### Not logged in
```
Pulling iac (sdcplatform/iacsvc:latest)...
ERROR: pull access denied for sdcplatform/iacsvc, repository does not exist or may require 'docker login'
make: *** [pull] Error 1
```
1. Create a docker hub account
1. Ask to become a team member of sdcplatformras
1. Run `docker login` in a terminal and use your docker hub account

### Database already running
- `sm-postgres` container not working? Check there isn't a local postgres running on your system as it uses port 5432 and won't start if another service is running on this port.

### Port already bound to
```
ERROR: for collection-instrument  Cannot start service collection-instrument: driver failed programming external connectivity on endpoint collection-instrument (7c6ad787c9d57028a44848719d8d705b14e1f82ea2f393ada80e5f7e476c50b1): Error starting userland pStarting secure-message ... done

ERROR: for collection-instrument  Cannot start service collection-instrument: driver failed programming external connectivity on endpoint collection-instrument (7c6ad787c9d57028a44848719d8d705b14e1f82ea2f393ada80e5f7e476c50b1): Error starting userland proxy: Bind for 0.0.0.0:8002 failed: port is already allocated
ERROR: Encountered errors while bringing up the project.
make: *** [up] Error 1
```
- Kill the process hogging that port by running `lsof -n -i:8002|awk 'FNR == 2 { print $2 }'|xargs kill` where 8002 is the port you are trying to bind to

### Docker network
```
ERROR: Network rasrmdockerdev_default declared as external, but could not be found. Please create the network manually using `docker network create rasrmdockerdev_default` and try again.
make: *** [up] Error 1
```

- Run `docker network create rasrmdockerdev_default` to create the docker network.

### Unexpected behavior

1. Stop docker containers `make down`
1. Remove containers `docker rm $(docker ps -aq)`
1. Delete images `docker rmi $(docker images -qa)`
1. Pull and run containers `make up`

### Service not up?

Some services aren't resilient to the database not being up before the service has started. Rerun `make up`

### Services running sluggishly?

When ras/rm is all running it takes a lot of memory.  Click on the docker icon in the top bar of your Mac,
then click on 'preferences', then go to the 'advanced' tab.  The default memory allocated to Docker is 2gb.
Bumping that up to 8gb and the number of cores to 4 should make the service run much smoother. Note: These aren't
hard and fast numbers, this is just what worked for people.

### UAA
A default user (uaa_user/password) is added automatically to the UAA and this user can be used to sign into response-operations-ui
