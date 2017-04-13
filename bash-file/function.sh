#!/bin/bash -ex

#echo 'cd command'
#cd /home/delxie/Documents/workspace-sts/spring-cloud-demo
#echo 'mvn command'
#set +e
#mvn install deploy -N -q -B -e -U -Dmaven.test.skip=true \
#-Dmaven.repo.local="${maven_repository}" \
#-DaltReleaseDeploymentRepository="nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/releases"
#set -e
#if [ $? == 0 ];then
	#	echo 'warn:this project deploy failed!'
#fi
#echo 'mvn command'

#mvn install deploy -N -q -B -e -U -Dmaven.test.skip=true \
#-Dmaven.repo.local="${maven_repository}" \
#-DaltReleaseDeploymentRepository="nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/releases"
#echo "$(pwd) close"


#array_test=('a' 'b' 'c')
#value_test='a'
#if [ ${value_test} !=  ${array_test[@]} ];then
	#	echo 'true'
#else
	#	echo 'false'
#fi

json_description=$(cat /home/delxie/Documents/git-repository/build-dependency/bash-file/build-2.3.json)


project_name=$(echo ${json_description} | \
	jq '.project_name' | sed {s/\"//g})
	
web_modules=($(echo ${json_description} | \
	jq '.web_module | .[]' | sed {s/\"//g}))
	
	
echo ${web_modules}

