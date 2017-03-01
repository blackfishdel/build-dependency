#/bin/bash -ex

#1
#生成CA证书
mkdir -p  ~/registry-conf && openssl req \
   -subj '/CN=customregistry.com/' -newkey rsa:4096 -nodes -sha256 -keyout ~/registry-conf/domain.key \
   -x509 -days 365 -out ~/registry-conf/domain.crt

#2
#运行registry
docker run -d -p 5000:5000 --restart=always --name registry \
  -v ~/registry-conf/config.yml:/etc/docker/registry/config.yml \
  registry:2.6.0
