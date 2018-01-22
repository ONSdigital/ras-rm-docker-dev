# ras-rm-docker-dev
A combined repository for unifying approach to running RAS and RM in Docker

## Pre-requisites
1. Create a docker hub account
1. Ask to become a team member of sdcplatformras
1. Run `docker login` in a terminal and use your docker hub account

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
docker-compose -f rm-services.yml up -d collex
```

This will spin up just the collection exercise service.

## Development

### Running in docker with local changes
Development using this repo can be done by doing the following:

1. Make changes to whichever repository.  In this example we'll suppose you're changing the response-operations-ui repository.
1. Stop the service with `docker-compose -f ras-services.yml stop response-operations-ui`
1. Delete the stopped container with `docker-compose -f ras-services.yml rm response-operations-ui`
1. Rebuild the image and tag it as the latest to 'trick' the build into thinking we already have the latest and don't need to pull down the image from dockerhub.
  - Python repo - `docker build . -t sdcplatform/response-operations-ui:latest`
  - Java repo - `mvn clean install` will automatically rebuild the docker image
1. Finally, start the service again with `docker-compose -f ras-services.yml up -d response-operations-ui`

### Running natively with local changes
1. Stop all the services `make down`
1. Make changes to whichever repository.  In this example we'll suppose you're changing the response-operations-ui repository.
1. Update [.env](./.env) so that any services that speak to the service(s) running locally has the host configured as `docker.for.mac.localhost`. e.g. `PARTY_HOST=docker.for.mac.localhost`
1. Finally, start the services excluding the service(s) you are running locally
1. Run the service(s) locally

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
ERROR: for collection-instrument  Cannot start service collection-instrument-service: driver failed programming external connectivity on endpoint collection-instrument (7c6ad787c9d57028a44848719d8d705b14e1f82ea2f393ada80e5f7e476c50b1): Error starting userland pStarting secure-message ... done

ERROR: for collection-instrument-service  Cannot start service collection-instrument-service: driver failed programming external connectivity on endpoint collection-instrument (7c6ad787c9d57028a44848719d8d705b14e1f82ea2f393ada80e5f7e476c50b1): Error starting userland proxy: Bind for 0.0.0.0:8002 failed: port is already allocated
ERROR: Encountered errors while bringing up the project.
make: *** [up] Error 1
```
- Kill the process hogging that port by running `lsof -n -i:8002|awk 'FNR == 2 { print $2 }'|xargs kill` where 8002 is the port you are trying to bind to