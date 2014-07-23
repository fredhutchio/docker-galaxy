.PHONY: docker-clean

all: base/.timestamp production/.timestamp

base/.timestamp: base/Dockerfile base/docker-cmd.sh base/startup.sh
	docker build -t bcclaywell/galaxy-base:testing base
	touch base/.timestamp

production/.timestamp: production/Dockerfile production/startup.sh base/.timestamp
	docker build -t bcclaywell/galaxy:testing production
	touch production/.timestamp

docker-clean:
	docker ps -a | grep Exited | cut -d' ' -f1 | xargs docker rm
	docker images | grep none | awk '{print $$3}' | xargs docker rmi
