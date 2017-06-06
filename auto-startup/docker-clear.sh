#!/bin/bash

docker rmi $(docker images | sed '1d' | gawk '{print $1,$3}' | grep 'none' | gawk '{print $2}')