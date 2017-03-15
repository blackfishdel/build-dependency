#!/bin/bash -ex
#------------------------------------------------------------------------------
#处理master_dir中pom文件修改逻辑
#------------------------------------------------------------------------------
#参数
#${json_description} 整个json字符串

#获取依赖包的version并修改到pom文件中
$
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
#构建项目并push image到registry
#------------------------------------------------------------------------------
cd ${WORKSPACE}
master_dir="${WORKSPACE}/master"
mkdir -p ${master_dir}

#当项目第一次发布时没有master分支，也没有last_tag,所以last_tag与branch_name相同
if [ ${branch_name} != ${last_tag#*/} ];then
	project_tag="patch" #以发布过，有master分支，有tag分支，有patch包
	elif [[ ${branch_name} = ${last_tag#*/} ||  ${last_tag} ]];then
	project_tag="full" #未发布过，没有master分支，没有tag分支,没有patch包
fi

master_zip_url="http://192.168.1.215:9090/zip/?r=joinwe/${project_name}.git&h=master&format=zip"
master_zip_path="${WORKSPACE}/master.zip"

case ${project_tag} in
'patch')
curl -o "${master_zip_path}" "${master_zip_url}"
unzip -q -d "${master_dir}" "${master_zip_path}"
rm -rf "${master_zip_path}"

#对比branch与master修改文件
diff_file_list=($(diff -ruaq "${base_dir}" "${master_dir}" \
	| grep '^Files' | grep -v '\.git' | awk '{print $2}' ))
#对比branch有，master没有的文件
#屏蔽没有后缀的列，认为没有“.”的列为文件夹
#屏蔽master的文件列，默认为master需要文件
add_file_list=($(diff -ruaq "${base_dir}" "${master_dir}" \
	| grep '^Only' | grep "${base_dir}" | grep -v '\.git' \
	| awk '{print $3,$4;}' | sed 's/: /\//' ))
	
#屏蔽master的文件列，默认为master需要文件
remove_file_list=($(diff -ruaq "${base_dir}" "${master_dir}" \
	| grep '^Only' | grep "${master_dir}" | grep -v '\.git' \
	| awk '{print $3,$4;}' | sed 's/: /\//' ))

#把branch的add\diff文件复制到master
if [[ ${#diff_file_list[@]} != 0 ]];then
	for i in ${!diff_file_list[@]};do
		dir_path="${diff_file_list[$i]/${base_dir}/${master_dir}}"
		mkdir -p $(dirname "${dir_path}")
		if [ -d ${diff_file_list[$i]} ];then
			continue
		fi
		cp "${diff_file_list[$i]}" "${dir_path}"
	done
fi

if [[ ${#add_file_list[@]} != 0 ]];then
for i in ${!add_file_list[@]};do
dir_path="${add_file_list[$i]/${base_dir}/${master_dir}}"
mkdir -p $(dirname "${dir_path}")
if [ -d ${add_file_list[$i]} ];then
continue
fi
cp "${add_file_list[$i]}" "${dir_path}"
done
fi

if [[ ${#remove_file_list[@]} != 0 ]];then
for i in ${!remove_file_list[@]};do
if [[ -d "${remove_file_list[$i]}" ]];then
continue
fi
rm -f "${remove_file_list[$i]}"
done
fi
#master_dir进行打包
cd "${master_dir}"
#查找是否有project.json文件
project_path="$(find ${master_dir} -name project.json | head -n 1)"
if [ ${project_path} ];then
	project_found='been found'
else
	project_found='not found'
fi
case ${project_found} in
'been found')
	json_List=$(cat ${project_path})
	json_artifactId_length=$(echo ${json_List} | jq '.project_artifactId' | jq length)
	for ((i=0;i<json_artifactId_length;i++));do
		json_artifactId=$(echo ${json_List} | jq '.project_artifactId' | jq ".[${i}]")
		json_artifactId_name=$(echo ${json_artifactId} \
		| jq ".artifactId_name"  | sed {s/\"//g})
		json_artifactId_value=$(echo ${json_artifactId} \
		| jq ".artifactId_value"  | sed {s/\"//g})
		mvn versions:set -q -B -e -U -DartifactId="${json_artifactId_name}" \
		-DnewVersion="${json_artifactId_value}"
	done
	
	json_project_properties_length=$(echo ${json_List} | jq '.project_properties' | jq length)
	for ((i=0;i<json_project_properties_length;i++));do
		json_project_properties=$(echo ${json_List} | jq '.project_properties' | jq ".[${i}]")
		json_property_name=$(echo ${json_project_properties} \
		| jq ".property_name"  | sed {s/\"//g})
		json_property_value=$(echo ${json_project_properties} \
		| jq ".property_value"  | sed {s/\"//g})
			mvn versions:update-property -q -B -e -U -Dproperty="${json_property_name}" \
			-DnewVersion="${json_property_value}"
	done
;;
'not found')
	echo "warn:project.json is not found!"
;;
esac
mvn clean deploy -q -B -e -U -Dmaven.test.skip=true  -Dmaven.repo.local=${maven_local_dir} \
-DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ \
-DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
#master_dir进行docker image构建并上传
if [ ! -d  "${master_dir}/${module_name}" ];then
cd "${master_dir}"
else
cd "${master_dir}/${module_name}"
fi
mvn docker:build -q -e -Dmaven.test.skip=true -DpushImage 
#------------------------------------------------------------------------------
#下载last.zip并解压到last_dir,当前未编译
curl -o "${last_tag_zip_path}" "${last_tag_zip_url}"
unzip -q -d "${last_dir}" "${last_tag_zip_path}"
rm -rf "${last_tag_zip_path}"
#last_dir进行打包
if [ ! -d "${last_dir}/${module_name}" ];then
	cd "${last_dir}"
	last_web_dir="${last_dir}"
else
	cd "${last_dir}/${module_name}"
	last_web_dir="${last_dir}/${module_name}"
fi
mvn clean package -q -Dmaven.test.skip=true

#对比master与last编译后修改文件
patch_diff_file_list=($(diff -ruaq "${master_dir}/${module_name}/target/${module_name}" \
	"${last_web_dir}/target/${module_name}" \
	| grep '^Files' | grep -v '\.git' | awk '{print $2}'))
#对比master编译后有，last编译后last没有的文件
#屏蔽没有后缀的列，认为没有“.”的列为文件夹
patch_add_file_list=($(diff -ruaq "${master_dir}/${module_name}/target/${module_name}" \
	"${last_web_dir}/target/${module_name}" \
	| grep '^Only' | grep "${master_dir}" | grep -v '\.git' \
	| awk  '{print $3,$4;}' | sed 's/: /\//'))

#把master的add\diff文件复制到patch
if [[ ${#patch_diff_file_list[@]} != 0 ]];then
for i in ${!patch_diff_file_list[@]};do
dir_path="${patch_diff_file_list[$i]/"${master_dir}/${module_name}/target"/${patch_dir}}"
mkdir -p $(dirname "${dir_path}")
if [ -d ${patch_diff_file_list[$i]} ];then
continue
fi
cp "${patch_diff_file_list[$i]}" "${dir_path}"
done
fi

if [[ ${#patch_add_file_list[@]} != 0 ]];then
for i in ${!patch_add_file_list[@]};do
dir_path="${patch_add_file_list[$i]/"${master_dir}/${module_name}/target"/${patch_dir}}"
mkdir -p $(dirname "${dir_path}")
if [ -d ${patch_add_file_list[$i]} ];then
continue
fi
cp "${patch_add_file_list[$i]}" "${dir_path}"
done
fi
#对比master编译后有，last编译后master没有的文件
#屏蔽没有后缀的列，认为没有“.”的列为文件夹
patch_remove_file_list=($(diff -ruaq "${master_dir}/${module_name}/target/${module_name}" \
								"${last_web_dir}/target/${module_name}" \
								| grep '^Only' | grep "${last_web_dir}" \
								| awk  '{print $3,$4;}' | sed 's/: /\//'  \
								| sed "s;"${last_web_dir}/target/${module_name}/";;"))

if [[ ${#patch_remove_file_list[@]} != 0 ]];then
for i in ${!patch_remove_file_list[@]};do
if [[ -d "${last_web_dir}/target/${module_name}/${patch_remove_file_list[$i]}" ]];then
continue
fi
echo "rm -f ${patch_remove_file_list[i]}" >> "${WORKSPACE}/explanation.sh"
done
fi

echo "rm -f \${BASEDIR}/explanation.sh" >> "${WORKSPACE}/explanation.sh"
mv "${WORKSPACE}/explanation.sh" "${patch_dir}/${module_name}"

cd "${patch_dir}"
zip -r "${patch_name}" "${module_name}"
#压缩增量包并上传（scp）到指定位置
scp "${patch_dir}/${patch_name}" "root@192.168.1.215:/home/test-version/joinwe/${patch_name}"

rm -rf $(find ${master_dir} -name '*\.jar')
rm -rf $(find ${master_dir} -name '*\.war')
;;
'full')
#base_dir进行打包
cd "${base_dir}"
#查找是否有project.json文件
project_path="$(find ${base_dir} -name project.json | head -n 1)"
if [ ${project_path} ];then
	project_found='been found'
else
	project_found='not found'
fi
case ${project_found} in
'been found')
	json_List=$(cat ${project_path})
	json_artifactId_length=$(echo ${json_List} | jq '.project_artifactId' | jq length)
	for ((i=0;i<json_artifactId_length;i++));do
		json_artifactId=$(echo ${json_List} | jq '.project_artifactId' | jq ".[${i}]")
		json_artifactId_name=$(echo ${json_artifactId} \
		| jq ".artifactId_name"  | sed {s/\"//g})
		json_artifactId_value=$(echo ${json_artifactId} \
		| jq ".artifactId_value"  | sed {s/\"//g})
		mvn versions:set -q -B -e -U -DartifactId="${json_artifactId_name}" \
		-DnewVersion="${json_artifactId_value}"
	done
	
	json_project_properties_length=$(echo ${json_List} | jq '.project_properties' | jq length)
	for ((i=0;i<json_project_properties_length;i++));do
		json_project_properties=$(echo ${json_List} | jq '.project_properties' | jq ".[${i}]")
		json_property_name=$(echo ${json_project_properties} \
		| jq ".property_name"  | sed {s/\"//g})
		json_property_value=$(echo ${json_project_properties} \
		| jq ".property_value"  | sed {s/\"//g})
			mvn versions:update-property -q -B -e -U -Dproperty="${json_property_name}" \
			-DnewVersion="${json_property_value}"
	done
;;
'not found')
	echo "warn:project.json is not found!"
;;
esac

mvn clean deploy -q -B -e -U -Dmaven.test.skip=true  -Dmaven.repo.local=${maven_local_dir} \
-DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ \
-DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
#master_dir进行docker image构建并上传
if [ ! -d "${base_dir}/${module_name}" ];then
cd "${base_dir}"
else
cd "${base_dir}/${module_name}"
fi
mvn docker:build -q -Dmaven.test.skip=true -DpushImage
rm -rf $(find ./ -name '*\.war'| head -n 1) 
war_path=$(find ./ -name '*\.war'| head -n 1) 
scp "${war_path}" "root@192.168.1.215:/home/test-version/joinwe/${war_path#*/}"
;;
esac