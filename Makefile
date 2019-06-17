DOT := $(shell command -v dot 2> /dev/null)

RAS_REPOS="ras-party" "ras-secure-message" "ras-frontstage" "ras-collection-instrument" "django-oauth2-test" "ras-rm-auth-service" "respondent-home-ui" "response-operations-ui" "response-operations-social-ui" "rasrm-ops"
RM_REPOS="rm-sample-service" "rm-case-service" "rm-action-service" "rm-actionexporter-service" "iac-service" "rm-sdx-gateway" "rm-collection-exercise-service" "rm-survey-service" "rm-notify-gateway" "rm-comms-template-service" "rm-reporting"
REPOS=${RAS_REPOS} ${RM_REPOS}
REPOS=${RAS_REPOS} ${RM_REPOS}

check-env:
ifndef RASRM_HOME
	$(error RASRM_HOME environment variable is not set.)
endif
	@ printf "\n[RASRM_HOME set to ${RASRM_HOME}]\n"

clone: check-env
	@ printf "\n[Cloning into ${RASRM_HOME}]\n"
	@ for r in ${REPOS}; do \
		echo "($${r})"; \
		if [ ! -e ${RASRM_HOME}/$${r} ]; then \
			git clone git@github.com:ONSdigital/$${r}.git ${RASRM_HOME}/$${r}; \
		else \
			echo "  - already exists: skipping"; \
		fi; echo ""; \
	done

build: clone
	@ printf "\n[Building ${RASRM_HOME}]\n"
	@ for r in ${REPOS}; do \
		echo "Building ($${r})"; \
		if [ ! -e ${RASRM_HOME}/$${r}/pom.xml ]; then \
			if [ $${r} == "rm-comms-template-service" ]; then \
				docker build -t sdcplatform/comms-template-svc ${RASRM_HOME}/$${r}; \
			elif [ $${r} == "rm-survey-service" ]; then \
				docker build -t sdcplatform/surveysvc ${RASRM_HOME}/$${r}; \
			else \
				docker build -t sdcplatform/$${r} ${RASRM_HOME}/$${r}; \
			fi; echo ""; \
		else \
			mvn clean install -Dmaven.test.skip=true -DskipITs -DdockerComposeSkip -Dhttp.wait.skip -f ${RASRM_HOME}/$${r}; \
		fi; echo ""; \
	done

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

diagrams: ensure-graphviz download-plantuml
	java -jar plantuml.jar -tsvg diagrams/*.puml

clean:
	rm -f plantuml.jar; rm -f diagrams/*.svg

download-plantuml:
ifeq (,$(wildcard plantuml.jar))
	curl -L --output plantuml.jar https://downloads.sourceforge.net/project/plantuml/plantuml.jar
endif 

ensure-graphviz:
ifndef DOT
	$(error "The dot command is not available - please install graphviz (brew install graphviz)")
endif
