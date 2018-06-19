up:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml up -d ${SERVICE} ; docker stop oauth2-service && docker start oauth2-service
	pipenv install --dev
	pipenv run python setup_database.py

down:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml down

up-local:
	docker-compose -f ras-local.yml up -d ${SERVICE}

down-local:
	docker-compose -f ras-local.yml down ${SERVICE}

pull:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml pull ${SERVICE}

logs:
	docker-compose -f dev.yml -f ras-services.yml -f rm-services.yml logs --follow ${SERVICE}

