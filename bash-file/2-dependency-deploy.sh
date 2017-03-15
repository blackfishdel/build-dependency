#!/bin/bash -ex

#------------------------------------------------------------------------------
#move file to base_dir
#------------------------------------------------------------------------------
cd ${WORKSPACE}
base_dir="${WORKSPACE}/base_dir"
mkdir -p "${WORKSPACE}/base_dir"
mv $(ls -a | grep -v "^base_dir$" | grep -v "\.$" | grep -v "\.\.$") \
	"${WORKSPACE}/base_dir"

#------------------------------------------------------------------------------
#create maven_repository
#------------------------------------------------------------------------------
maven_repository="${WORKSPACE}/maven_repository"
mkdir -p ${maven_repository}

#------------------------------------------------------------------------------
#read description.json
#------------------------------------------------------------------------------
description_path="$(find ${base_dir} -name description.json | head -n 1)"
if [ ${description_path} ];then
	description_find='find'
else
	description_find='not find'
fi
case ${description_find} in
'not find')
echo "info:description.json is did not find!"
;;
'find')
json_description=$(cat ${description_path})
json_dependencies=$(echo ${json_description} | jq '.dependencies')
json_dependencies_length=$(echo ${json_dependencies} | jq length)
if [ json_dependencies_length == 0 ];then
	dependencies_build = "false"
else
	dependencies_build = "true"
fi
;;
esac
#------------------------------------------------------------------------------
#build dependencies
#------------------------------------------------------------------------------
case ${find_build} in
"false")
echo "info:This project does not need to dependencies!"
;;
"true")
cd ${WORKSPACE}
dependency_dir="${WORKSPACE}/dependency_dir"
mkdir -p ${dependency_dir}

#循环遍历
for ((i=0;i<json_dependencies_length;i++));do
	json_object=$(echo ${json_dependencies} | jq ".[${i}]")
	#发现dependencies有多少层
	json_object_array=("${json_object}")
	while (( $(echo ${json_object} | jq ".dependencies") != 'null' ));do
		json_object=$(echo ${json_object} | jq ".dependencies")
		json_object_array=("${json_object_array[@]}" "${json_object}")
	done
	#array遍历
	for ((j=${#json_object_array[@]};j>0;j--));do
		jn=`expr ${j} - 1`
		json_name=$(echo ${json_object_array[${jn}]} \
		| jq ".name"  | sed {s/\"//g})
		json_version=$(echo ${json_object_array[${jn}]} \
		| jq ".version"  | sed {s/\"//g})
		json_branch_name=$(echo ${json_object_array[${jn}]} \
		| jq ".branch_name"  | sed {s/\"//g})
		json_tag_name=$(echo ${json_object_array[${jn}]} \
		| jq ".tag_name"  | sed {s/\"//g})
		
		cd ${dependency_dir}
		git clone "${git_base_url}${json_name}.git"
		
		if [ ${json_project_branch_name} ];then
			git checkout "origin/${json_project_branch_name}"
			git pull --rebase
			cd ${dependency_dir}/${json_project_name%/*}
		elif [ ${json_project_tag_name} ];then
			echo "info:${json_project_name}发布稳定版-->${json_project_tag_name}"
			git checkout "${json_project_tag_name}"
			git pull --rebase
			cd ${dependency_dir}/${json_project_name%/*}
			mvn versions:set -q -B -e -U -DartifactId="${json_project_name#*/}" \
			-DnewVersion="${json_project_tag_name}"
		fi
		json_pom_properties_length=$(echo ${json_object_array[${jn}]} \
		| jq ".pom_properties" | jq length)
		for ((k=0;k<json_pom_properties_length;k++));do
			json_pom_properties=$(echo ${json_object_array[${jn}]} \
			| jq ".pom_properties" | jq ".[${k}]")
			json_pom_properties_name=$(echo ${json_pom_properties} \
			| jq ".property_name"  | sed {s/\"//g})
			json_pom_properties_value=$(echo ${json_pom_properties} \
			| jq ".property_value"  | sed {s/\"//g})
			mvn versions:update-property -q -B -e -U -Dproperty="${json_pom_properties_name}" \
			-DnewVersion="${json_pom_properties_value}"
		done
#调用mvn构建项目,更新本地库，更新远端库
mvn clean deploy -q -B -e -U -Dmaven.test.skip=true -Dmaven.repo.local=${maven_local_dir} \
-DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ \
-DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
		
	done
done
esac

# 删除dependency_dir
rm -rf ${dependency_dir}