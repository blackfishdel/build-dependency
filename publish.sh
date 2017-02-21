#!/bin/bash
set -x

IMAGE_NAME=
IMAGE_VERSION=
#DOCKER_PARAMTER example:
# --name pbapweb -d -p 8960:8080 --env application.profile=sit --env application.config.server="http://192.168.1.215:9001" --env spring.application.name=pbapweb  192.168.1.215:5000/pbap-web 
DOCKER_PARAMTER=

#stop docker containers
#docker stop $(docker ps | grep "${IMAGE_NAME}" | grep "${IMAGE_VERSION}" | awk '{print $1}')
#docker stop $(docker ps | grep "${IMAGE_NAME}" | grep 'latest' | awk '{print $1}')

#remove docker containers
#docker rm $(docker ps -a | grep "${IMAGE_NAME}" | grep "${IMAGE_VERSION}" | awk '{print $1}')
#docker rm $(docker ps -a | grep "${IMAGE_NAME}" | grep 'latest' | awk '{print $1}')

#remove docker images
#docker rmi $(docker images | grep "${IMAGE_NAME}" | grep "${IMAGE_VERSION}" | awk '{print $3}')
#docker rmi $(docker images | grep "${IMAGE_NAME}" | grep 'latest' | awk '{print $3}')

docker run ${DOCKER_PARAMTER} ${IMAGE_NAME}:${IMAGE_VERSION}