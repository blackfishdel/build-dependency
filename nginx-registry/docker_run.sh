
cd ~
## 创建CA证书
mkdir certs

## 创建registry auth
mkdir auth
docker run --entrypoint htpasswd registry:2.6.0 -Bbn zkp zhongkejf > auth/htpasswd


docker run -d -p 127.0.0.1:5000:5000 --restart=always --name registry \
  -v ~/auth:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -v ~/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  registry:2.6.0
  
docker run -d -p 5043:443 --link registry:registry --name nginx \
  -v ~/certs:/etc/nginx/conf.d \
  -v ~/certs/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:1.11.10
  
## 用例
docker login -u=zkp -p=zhongkejf myregistrydomain.com:5043
docker tag ubuntu myregistrydomain.com:5043/test
docker push myregistrydomain.com:5043/test
docker pull myregistrydomain.com:5043/test