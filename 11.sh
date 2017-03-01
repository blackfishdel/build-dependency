docker run -d -p 127.0.0.1:5000:5000 --restart=always --name registry \
  -v ~/docker-registry/certs:/certs \
  -v ~/docker-registry/registry/config.yml:/etc/docker/registry/config.yml \
  registry:2.6.0