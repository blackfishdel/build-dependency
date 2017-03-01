#/bin/bash -ex

#ubuntu
#sudo cp ~/docker-registry/domain.crt /usr/local/share/ca-certificates/myregistrydomain.com.crt
#sudo update-ca-certificates

#centos
#cp ~/docker-registry/domain.crt /etc/pki/ca-trust/source/anchors/myregistrydomain.com.crt
#update-ca-trust

echo "192.168.1.79	myregistrydomain.com" >> /etc/hosts

service docker stop && service docker start


#Docker client仍然在使用身份验证时证书验证不通过？
#使用身份验证时，某些版本的Docker还需要您在操作系统级别信任证书。通常，在Ubuntu上，这是通过：
#$ cp certs/domain.crt /usr/local/share/ca-certificates/myregistrydomain.com.crt
#update-ca-certificates

#..和红帽（及其衍生品）上：
#cp certs/domain.crt /etc/pki/ca-trust/source/anchors/myregistrydomain.com.crt
#update-ca-trust

#...在某些发行版（例如Oracle Linux 6）上，需要手动启用共享系统证书功能：
#$ update-ca-trust enable
#现在重新启动docker（service docker stop && service docker start或任何其他方式，你用来重新启动docker）。
#docker login -u=zkp -p=zhongkejf -e=ci@zhongkejf.com myregistrydomain.com:5043
#docker tag ubuntu 192.168.1.79:5043/test
#docker push 192.168.1.79:5043/test
#docker pull 192.168.1.79:5043/test