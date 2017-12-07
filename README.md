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

