up:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml up -d ${SERVICE} ; docker stop oauth2-service && docker start oauth2-service

down:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml down

pull:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml pull ${SERVICE}

logs:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml logs --follow ${SERVICE}

