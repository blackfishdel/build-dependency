#!/bin/bash -ex

#------------------------------------------------------------------------------
#variable
#------------------------------------------------------------------------------
#工作空间目录
WORKSPACE=${WORKSPACE}
#构建环境
build_context=${build_context}
#------------------------------------------------------------------------------
#constant
#------------------------------------------------------------------------------
git_base_url="http://192.168.1.215:9090/r/joinwe/"
maven_base_url="http://192.168.1.222:8081/nexus/content/repositories/"
snapshots_url="${maven_base_url}snapshots/"
alpha_url="${maven_base_url}alpha/"
beta_url="${maven_base_url}beta/"
releases_url="${maven_base_url}releases/"
#------------------------------------------------------------------------------
#function
#------------------------------------------------------------------------------
#名字:fun_version_change
#描述:修改构建项目后缀
#范例:fun_version_change "sit" "/project_file_path"
#$1:构建环境
#$2:项目路径
#------------------------------------------------------------------------------
fun_version_change(){
cd ${2}
case ${1} in
"dev")
;;
"sit")
mvn versions:set -q -B -e -U -Dmaven.test.skip=true \
-DremoveSnapshot=true -DnewVersion=${project.version}
mvn versions:set -q -B -e -U -Dmaven.test.skip=true \
-DremoveSnapshot=true -DnewVersion=${project.version}"-ALPHA"
;;
"uet")
mvn versions:set -q -B -e -U -Dmaven.test.skip=true \
-DremoveSnapshot=true -DnewVersion=${project.version}
mvn versions:set -q -B -e -U -Dmaven.test.skip=true \
-DremoveSnapshot=true -DnewVersion=${project.version}"-BETA"
;;
"pro")
mvn versions:set -q -B -e -U -Dmaven.test.skip=true \
-DremoveSnapshot=true -DnewVersion=${project.version}
mvn versions:set -q -B -e -U -Dmaven.test.skip=true \
-DremoveSnapshot=true -DnewVersion=${project.version}"-RELEASE"
;;
esac
}
#------------------------------------------------------------------------------
#名字:fun_dependency_change
#描述:修改构建项目依赖版本号，注意：如果nexus没有该版本，则修改失败
#注意:pom文件中properties中名字要与artifactId一样
#范例:fun_dependency_change "sit" "/project_file_path"
#$1:构建环境
#$2:项目路径
#$3:属性名称
#$4:版本号
#------------------------------------------------------------------------------
fun_dependency_change(){
cd ${2}
case ${1} in
"dev")
echo "info:dev is not change!"
;;
"sit")
versions:update-property -q -B -e -U -Dmaven.test.skip=true \
-Dproperty="${3}.version" -DnewVersion="${4}-ALPHA"
;;
"uet")
versions:update-property -q -B -e -U -Dmaven.test.skip=true \
-Dproperty="${3}.version" -DnewVersion="${4}-BETA"
;;
"pro")
versions:update-property -q -B -e -U -Dmaven.test.skip=true \
-Dproperty="${3}.version" -DnewVersion="${4}-RELEASE"
;;
esac
}
#------------------------------------------------------------------------------
#名字:fun_deploy_nexus
#描述:发布项目到nexus仓库
#范例:fun_deploy_nexus "sit" "/project_file_path"
#$1:构建环境
#$2:项目路径
#------------------------------------------------------------------------------
fun_deploy_nexus(){
cd ${2}
case ${1} in
"dev")
mvn clean deploy -N -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_repository}" \
-DaltSnapshotDeploymentRepository="nexus-snapshots::default::${snapshots_url}"
;;
"sit")
mvn clean deploy -N -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_repository}" \
-DaltReleaseDeploymentRepository="nexus-snapshots::default::${alpha_url}"
;;
"uet")
mvn clean deploy -N -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_repository}" \
-DaltReleaseDeploymentRepository="nexus-snapshots::default::${beta_url}"
;;
"pro")
mvn clean deploy -N -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_repository}" \
-DaltReleaseDeploymentRepository="nexus-snapshots::default::${releases_url}"
;;
esac
}
#------------------------------------------------------------------------------
#名字:fun_package_pro
#描述:编译项目
#范例:fun_package_pro "/project_file_path"
#$1:项目路径
#------------------------------------------------------------------------------
fun_package_pro(){
cd ${1}
mvn clean package -q -B -e -U -Dmaven.test.skip=true
}
#------------------------------------------------------------------------------
#名字:fun_push_image
#描述:构建image发布到registry
#范例:fun_push_image "/project_file_path"
#$1:项目路径
#------------------------------------------------------------------------------
fun_push_image(){
cd ${1}
mvn docker:build -q -B -e -U -Dmaven.test.skip=true -DpushImage
}
#------------------------------------------------------------------------------
#名字:fun_zip_url
#描述:组合git下载url
#范例:fun_zip_url "project_name"
#$1:项目名称
#$2:分支名称或tag名称
#------------------------------------------------------------------------------
fun_zip_url(){
zip_url="http://192.168.1.215:9090/zip/?r=joinwe/${1}.git&h=${2}&format=zip"
return ${zip_url}
}
#------------------------------------------------------------------------------
#名字:fun_unzip_file
#描述:解压文件到指定目录，并删除原文件
#范例:fun_unzip_file "/zip_file_path" "/dir_path"
#$1:文件路径
#$1:目录路径
#------------------------------------------------------------------------------
fun_unzip_file(){
unzip -q -d "${1}" "${2}"
rm -rf "${1}"
}
#------------------------------------------------------------------------------
#名字:fun_backup_file
#描述:备份文件到指定地址
#范例:fun_backup_file "/project_file_path"
#$1:文件路径
#------------------------------------------------------------------------------
fun_backup_file(){
scp "${1}" "root@192.168.1.215:/home/test-version/joinwe/"
}
#------------------------------------------------------------------------------
#名字:fun_create_script
#描述:创建增量包“删除文件脚本”
#范例:fun_backup_file "/dir_path"
#------------------------------------------------------------------------------
fun_create_script(){
cat << "EOF" >> "${WORKSPACE}/remove_file.sh"
#!/bin/bash
#BASEDIR解决获得脚本存储位置绝对路径
#这个方法可以完美解决别名、链接、source、bash -c 等导致的问题
SOURCE="${BASH_SOURCE[0]}"
while [ -h ${SOURCE} ];do
	DIR=$( cd -P $( dirname ${SOURCE} ) && pwd )
	SOURCE="$(readlink ${SOURCE})"
	[[ ${SOURCE} != /* ]] && SOURCE=${DIR}/${SOURCE}
done
BASE_DIR="$( cd -P $( dirname ${SOURCE} ) && pwd )"
cd ${BASE_DIR}
EOF
}
#------------------------------------------------------------------------------
#名字:fun_superadd_script
#描述:在“删除文件脚本”文件末尾添加内容
#范例:fun_backup_file "/dir_path"
#$1:内容
#------------------------------------------------------------------------------
fun_superadd_script(){
echo "${1}" >> "${WORKSPACE}/remove_file.sh"
}
#------------------------------------------------------------------------------
#init
#------------------------------------------------------------------------------
cd ${WORKSPACE}
base_dir="${WORKSPACE}/base_dir"
mkdir -p "${WORKSPACE}/base_dir"
mv $(ls -a | grep -v "^base_dir$" | grep -v "\.$" | grep -v "\.\.$") \
	"${base_dir}"

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
			json_project_name=$(echo ${json_object_array[${jn}]} \
				| jq ".project_name" | sed {s/\"//g})
			json_version=$(echo ${json_object_array[${jn}]} \
				| jq ".version" | sed {s/\"//g})
			json_branch_name=$(echo ${json_object_array[${jn}]} \
				| jq ".branch_name"  | sed {s/\"//g})
			json_tag_name=$(echo ${json_object_array[${jn}]} \
				| jq ".tag_name" | sed {s/\"//g})

			cd ${dependency_dir}
			git clone "${git_base_url}${json_project_name}.git"
			if [ ${json_branch_name} ];then
				git checkout "origin/${json_branch_name}"
				git pull --rebase
				cd "${dependency_dir}/${json_project_name}"
			elif [ ${json_tag_name} ];then
				git checkout "${json_tag_name}"
				git pull --rebase
				cd "${dependency_dir}/${json_project_name}"
			fi
		
			fun_version_change "${build_context}" \
				"${dependency_dir}/${json_project_name}"
			if [ ${#json_object_array[@]} > ${j} ];do
				json_dependency_modules=($(echo ${json_object_array[${j}]} \
					| jq ".modules"))
				json_dependency_length=$(echo ${json_dependency_modules} \
					| jq length)
				for ((j=0;j<json_dependency_length;j++));do
					json_module_name=$(echo ${json_dependency_modules[${j}]} \
						| jq ".name" | sed {s/\"//g})
					json_module_version=$(echo ${json_dependency_modules[${j}]} \
						| jq ".version" | sed {s/\"//g})
					fun_dependency_change "${build_context}" \
						"${dependency_dir}/${json_project_name}" \
						"${json_module_name}" "${json_module_version}"
				done
			fi
			
			json_modules=$(echo ${json_object_array[${jn}]} \
				| jq ".modules")
			json_modules_length=$(echo ${json_modules} \
				| jq length)
			for ((j=0;j<json_modules_length;j++));do
				json_module_name=$(echo ${json_modules[${j}]} \
					| jq ".name" | sed {s/\"//g})
				json_module_version=$(echo ${json_modules[${j}]} \
					| jq ".version" | sed {s/\"//g})
				fun_version_change "${build_context}" \
					"${dependency_dir}/${json_project_name}/${json_module_name}"
				fun_deploy_nexus "${build_context}" \
					"${dependency_dir}/${json_project_name}/${json_module_name}"
			done
			
			#发布项目到nexus仓库
			fun_deploy_nexus "${build_context}" \
				"${dependency_dir}/${json_project_name}"
		done
	done
	;;
esac

# 删除dependency_dir
rm -rf ${dependency_dir}

#------------------------------------------------------------------------------
#create remove script
#------------------------------------------------------------------------------
fun_create_script

#------------------------------------------------------------------------------
#build target project
#------------------------------------------------------------------------------
cd ${WORKSPACE}
project_name=$(echo ${json_description} | \
	jq '.project_name' | sed {s/\"//g})
project_version=$(echo ${json_description} | \
	jq '.project_version' | sed {s/\"//g})
web_mdoule=$(echo ${json_description} | \
	jq '.web_mdoule' | sed {s/\"//g})
now_branch=$(echo ${json_description} | \
	jq '.now_branch' | sed {s/\"//g})
now_tag=$(echo ${json_description} | \
	jq '.now_tag' | sed {s/\"//g})
last_tag=$(echo ${json_description} | \
	jq '.last_tag' | sed {s/\"//g})

master_dir="${WORKSPACE}/master_dir"
mkdir -p ${master_dir}

#判断该项目是否第一次发布
if [ ${now_branch} ];then
	if [ ${now_branch} != ${last_tag} ];then
		#以发布过，有master分支，有tag分支，有patch包
		project_tag="patch"
	elif [ ${now_branch} = ${last_tag} ];then
		#未发布过，没有master分支，没有tag分支,没有patch包
	fi
	cd ${base_dir}
	git branch -b "${now_branch}" "origin/${now_branch}"
	git fetch
	git checkout "${now_branch}"
elif [ ${now_tag} ];then
	if [ ${now_tag} != ${last_tag} ];then
		#以发布过，有master分支，有tag分支，有patch包
		project_tag="patch"
	elif [ ${now_tag} = ${last_tag} ];then
		#未发布过，没有master分支，没有tag分支,没有patch包
		project_tag="full"
	fi
	cd ${base_dir}
	git branch -b "${now_tag}" "${now_tag}"
	git fetch
	git checkout "${now_branch}"
fi


case ${project_tag} in
'patch')
#------------------------------------------------------------------------------
master_zip_url=$(fun_master_zip_url ${project_name})
master_zip_path="${WORKSPACE}/master.zip"
#下载master分支
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
#------------------------------------------------------------------------------
#对master_dir修改版本号
cd ${master_dir}
#修改父pom文件外部依赖
jq_dep_names=$(echo ${json_description} \
| jq '.dependencies | .[] | .modules | .[] | .name' | sed {s/\"//g})
jq_dep_values=$(echo ${json_description} \
| jq '.dependencies | .[] | .modules | .[] | .value' | sed {s/\"//g})
if [ ${#jq_dep_names[@]} != 0 ];then
for i in ${!jq_dep_names[@]};do
	fun_dependency_change "${build_context}" "${master_dir}" \
	"${jq_dep_names[${i}]}" "${jq_dep_values[${i}]}"
done

#修改父pom文件版本号
fun_version_change "${build_context}" "${master_dir}"

#修改子项目pom文件版本号
jq_sub_names=$(echo ${json_description} | jq '.modules | .[] | .name' | sed {s/\"//g})
jq_sub_values=$(echo ${json_description} | jq '.modules | .[] | .value' | sed {s/\"//g})
if [ ${#jq_sub_names[@]} != 0 ];then
for i in ${!jq_sub_names[@]};do
	fun_version_change "${build_context}" "${master_dir}" \
	"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
done

#编译子项目
if [ ${#jq_sub_names[@]} != 0 ];then
for i in ${!jq_sub_names[@]};do
	fun_deploy_nexus "${build_context}" "${master_dir}/${jq_sub_names[${i}]}"
done

#修改父pom文件项目依赖
if [ ${#jq_sub_names[@]} != 0 ];then
for i in ${!jq_sub_names[@]};do
	fun_dependency_change "${build_context}" "${master_dir}" \
	"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
done

#编译父项目
fun_deploy_nexus "${build_context}" "${master_dir}"

#master_dir进行docker image构建并上传
if [ ${web_mdoule} == ${project_name} ];then
	master_web="${master_dir}"
else
	master_web="${master_dir}/${web_mdoule}"
fi
fun_push_image ${master_web}
#------------------------------------------------------------------------------
#生成patch包
#------------------------------------------------------------------------------
#下载last tag并解压到last_dir
last_dir="${WORKSPACE}/last_dir"
mkdir -p ${last_dir}
last_tag_zip_url=$(fun_zip_url ${project_name} ${last_tag})
last_tag_zip_path="${WORKSPACE}/last.zip"
curl -o "${last_tag_zip_path}" "${last_tag_zip_url}"
unzip -q -d "${last_dir}" "${last_tag_zip_path}"
rm -rf "${last_tag_zip_path}"
#找到last_web文件夹
if [ ${web_mdoule} == ${project_name} ];then
	last_web="${last_dir}"
else
	last_web="${last_dir}/${web_mdoule}"
fi
#对last_web进行编译
fun_package_pro ${last_dir}
#------------------------------------------------------------------------------
#对比master与last编译后修改文件
patch_diff_file_list=($(diff -ruaq "${master_web}/target/${web_mdoule}" \
	"${last_web}/target/${web_mdoule}" \
	| grep '^Files' | grep -v '\.git' | awk '{print $2}'))
#对比master编译后有，last编译后last没有的文件
#屏蔽没有后缀的列，认为没有“.”的列为文件夹
patch_add_file_list=($(diff -ruaq "${master_web}/target/${web_mdoule}" \
	"${last_web}/target/${web_mdoule}" \
	| grep '^Only' | grep "${master_dir}" | grep -v '\.git' \
	| awk  '{print $3,$4;}' | sed 's/: /\//'))

#创建patch_dir文件夹
patch_dir="${WORKSPACE}/patch"
patch_name="${module_name}.zip"
mkdir -p ${patch_dir}

#把master_dir的add\diff文件复制到patch_dir
if [[ ${#patch_diff_file_list[@]} != 0 ]];then
	for i in ${!patch_diff_file_list[@]};do
		dir_path="${patch_diff_file_list[$i]/"${master_web}/target"/${patch_dir}}"
		mkdir -p $(dirname "${dir_path}")
		if [ -d ${patch_diff_file_list[$i]} ];then
			continue
		fi
		cp "${patch_diff_file_list[$i]}" "${dir_path}"
	done
fi

if [[ ${#patch_add_file_list[@]} != 0 ]];then
	for i in ${!patch_add_file_list[@]};do
		dir_path="${patch_add_file_list[$i]/"${master_web}/target"/${patch_dir}}"
		mkdir -p $(dirname "${dir_path}")
		if [ -d ${patch_add_file_list[$i]} ];then
			continue
		fi
		cp "${patch_add_file_list[$i]}" "${dir_path}"
	done
fi
#对比master_dir编译后有，last_dir编译后master_dir没有的文件
#屏蔽没有后缀的列，认为没有“.”的列为文件夹
patch_remove_file_list=($(diff -ruaq "${master_dir}/${web_mdoule}/target/${web_mdoule}" \
								"${last_web}/target/${web_mdoule}" \
								| grep '^Only' | grep "${last_web_dir}" \
								| awk  '{print $3,$4;}' | sed 's/: /\//'  \
								| sed "s;"${last_web}/target/${web_mdoule}/";;"))

if [[ ${#patch_remove_file_list[@]} != 0 ]];then
	for i in ${!patch_remove_file_list[@]};do
	if [[ -d "${last_web}/target/${web_mdoule}/${patch_remove_file_list[$i]}" ]];then
		continue
	fi
	fun_superadd_script "rm -f ${patch_remove_file_list[i]}"
	done
fi
mv "${WORKSPACE}/remove_file.sh" "${last_web}"

#压缩patch_dir
cd "${WORKSPACE}"
zip -r "${web_mdoule}.zip" "${last_web}"
#压缩增量包并上传（scp）到指定服务器备份
fun_backup_file "${WORKSPACE}/${web_mdoule}.zip"
#删除编译后文件
rm -rf $(find ${master_dir} -name '*\.jar')
rm -rf $(find ${master_dir} -name '*\.war')
;;
'full')
#------------------------------------------------------------------------------
cd ${base_dir}
#修改父pom文件外部依赖
jq_dep_names=$(echo ${json_description} \
| jq '.dependencies | .[] | .modules | .[] | .name' | sed {s/\"//g})
jq_dep_values=$(echo ${json_description} \
| jq '.dependencies | .[] | .modules | .[] | .value' | sed {s/\"//g})
if [ ${#jq_dep_names[@]} != 0 ];then
for i in ${!jq_dep_names[@]};do
	fun_dependency_change "${build_context}" "${base_dir}" \
	"${jq_dep_names[${i}]}" "${jq_dep_values[${i}]}"
done

#修改父pom文件版本号
fun_version_change "${build_context}" "${base_dir}"

#修改子项目pom文件版本号
jq_sub_names=$(echo ${json_description} | jq '.modules | .[] | .name' | sed {s/\"//g})
jq_sub_values=$(echo ${json_description} | jq '.modules | .[] | .value' | sed {s/\"//g})
if [ ${#jq_sub_names[@]} != 0 ];then
for i in ${!jq_sub_names[@]};do
	fun_version_change "${build_context}" "${base_dir}" \
	"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
done

#编译子项目
if [ ${#jq_sub_names[@]} != 0 ];then
for i in ${!jq_sub_names[@]};do
	fun_deploy_nexus "${build_context}" "${base_dir}/${jq_sub_names[${i}]}"
done

#修改父pom文件项目依赖
if [ ${#jq_sub_names[@]} != 0 ];then
for i in ${!jq_sub_names[@]};do
	fun_dependency_change "${build_context}" "${base_dir}" \
	"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
done

#编译父项目
fun_deploy_nexus "${build_context}" "${base_dir}"

#base_dir进行docker image构建并上传
if [ ${web_mdoule} == ${project_name} ];then
	base_web="${base_dir}"
else
	base_web="${base_dir}/${web_mdoule}"
fi
fun_push_image ${base_web}
#删除编译后文件
rm -rf $(find ./ -name '*\.war'| head -n 1)
war_path=$(find ./ -name '*\.war'| head -n 1)
#压缩增量包并上传（scp）到指定服务器备份
fun_backup_file "${war_path}"
;;
esac