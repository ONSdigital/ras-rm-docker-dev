up:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml up -d ${SERVICE}

down:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml down

pull:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml pull ${SERVICE}
