# ras-rm-docker-dev
A combined repository for unifying approach to running RAS and RM in Docker

# Quickstart

```
docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml up -d
```

# Slowstart

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

# Development

Development using this repo can be done by doing the following:

 - Make changes to whichever repository.  In this example we'll suppose you're changing
 the response-operations-ui repository.

 -  Stop the service with `docker-compose -f ras-services.yml stop response-operations-ui`
 -  Delete the stopped container with `docker-compose -f ras-services.yml rm response-operations-ui`
 - Rebuild the image and tag it as the latest to 'trick' the build into thinking
 we already have the latest and don't need to pull down the image from dockerhub. `docker build . -t sdcplatform/response-operations-ui:latest`
 - Finally, start the service again with `docker-compose -f ras-services.yml up -d response-operations-ui`

 # Troubleshooting

  - `sm-postgres` container not working? Check there isn't a local postgres running on your system as it uses port 5432 and won't start if another service is running on this port.
