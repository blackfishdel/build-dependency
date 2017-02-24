#!/bin/bash -ex

#------------------------------------------------------------------------------
#init
#------------------------------------------------------------------------------
cd ${WORKSPACE}

if [ ${project_name} = ${module_name} ]
then
		web_path="${WORKSPACE}"
	else
		web_path="${WORKSPACE}/${module_name}"
fi

master_zip_url="http://192.168.1.215:9090/zip/?r=joinwe/${project_name}.git&h=master&format=zip"
master_zip_path="${WORKSPACE}/master.zip"

master_dir="${WORKSPACE}/master"
mkdir -p ${master_dir}

incremental_dir="${WORKSPACE}/incremental"
mkdir -p ${incremental_dir}

dependency_dir="${WORKSPACE}/dependency"
mkdir -p ${WORKSPACE}/dependency

patch_zip_path="${WORKSPACE}/patch.zip"
#------------------------------------------------------------------------------
#function
#------------------------------------------------------------------------------
command_failed(){
	if [ $? -ne 0 ]
	then
		echo "error: $*"
		exit 1
	fi
}
#------------------------------------------------------------------------------
#复制修改的java文件到master dir
copy_java_file(){
	path_prefix=$1
	array=$2
	java_suffix='.java'
	class_suffix='.class'
	if [ ${#array[@]} != 0 ]
	then
		for i in ${!array[@]}
		do
			dir_path="${array[$i]:${#path_prefix}}"
			mkdir -p $(dirname "${incremental_dir}/${module_name}/WEB-INF/classes/${dir_path}")
			cp "${master_dir}/${module_name}/target/classes/${dir_path%%.*}${class_suffix}" "${incremental_dir}/${module_name}/WEB-INF/classes/${dir_path%%.*}${class_suffix}"
		done
	fi
}
#------------------------------------------------------------------------------
#复制修改的class文件到incremental dir
copy_class_file(){
	path_prefix=$1
	array=$2
	java_suffix='.java'
	class_suffix='.class'
	if [ ${#array[@]} != 0 ]
	then
		for i in ${!array[@]}
		do
			dir_path="${array[$i]:${#path_prefix}}"
			mkdir -p $(dirname "${incremental_dir}/${module_name}/WEB-INF/classes/${dir_path}")
			cp "${master_dir}/${module_name}/target/classes/${dir_path%%.*}${class_suffix}" "${incremental_dir}/${module_name}/WEB-INF/classes/${dir_path%%.*}${class_suffix}"
		done
	fi
}
#------------------------------------------------------------------------------
copy_file(){
	path_prefix=$1
	array=$2
	if [[ ${#array[@]} != 0 ]]
	then
		for i in ${!array[@]}
		do
			dir_path="${array[$i]:${#path_prefix}}"
			mkdir -p $(dirname "${incremental_dir}/${module_name}/${dir_path}")
			cp "${WORKSPACE}/${array[$i]}" "${incremental_dir}/${module_name}/${dir_path}"
		done
	fi
}
#------------------------------------------------------------------------------
#step 3
#------------------------------------------------------------------------------
#下载master.zip并解压到master_dir
curl -o ${master_zip_path} ${master_zip_url}
if [ ! -e ${master_zip_path} ]
then
	echo "warn:${master_zip_path} is not found!"
fi
unzip -q -d ${master_dir} ${master_zip_path}
rm -rf ${master_zip_path}
#------------------------------------------------------------------------------
#对master打包
cd ${master_dir}/${module_name}
mvn -Dmaven.test.skip=true package -U install
command_failed "${master_dir}/${module_name}  install failed!"
cd ${master_dir}/${module_name}/target/${module_name}/WEB-INF/lib
oldLibs=(*)
#------------------------------------------------------------------------------
#step 4
#------------------------------------------------------------------------------
pomFileList=$(git diff ${last_tag} HEAD --name-only | grep "**pom.xml")
compileFileList=$(git diff ${last_tag} HEAD --name-only | grep "${module_name}/src/main/java**" | grep "**.java")
resourceFileList=$(git diff ${last_tag} HEAD --name-only | grep "${module_name}/src/main/resources/**.*")
staticFileList=$(git diff ${last_tag} HEAD  --name-only --ignore-all-space | grep "${module_name}/src/main/webapp/**.*")

read -a array_pom <<< ${pomFileList}
read -a array_compile <<< ${compileFileList}
read -a array_resource <<< ${resourceFileList}
read -a array_static <<< ${staticFileList}
#------------------------------------------------------------------------------
#将修改的array_pom文件到master_dir文件夹
if [ ${#array_pom[@]} != 0 ]
then
	for i in ${!array_pom[@]}
	do
		mkdir -p $(dirname ${master_dir}/${array_pom[$i]})
		cp "${WORKSPACE}/${array_pom[$i]}" "${master_dir}/${array_pom[$i]}"
	done
fi
#------------------------------------------------------------------------------
#将修改的.java打包成patch.zip
cd ${WORKSPACE}
if [ "${compileFileList}" ]
then
	zip -q ${patch_zip_path} ${compileFileList}
else
	echo "warn:${compileFileList} is null!"
fi
#------------------------------------------------------------------------------
#patch.zip覆盖master并编译，删除patch.zip
if [ ! -e "${patch_zip_path}" ]
then
	echo "warn:${patch_zip_path} is not found!"
else
	unzip -q -o "${patch_zip_path}" -d "${master_dir}"
	#rm -rf "${patch_zip_path}"
fi

cd "${master_dir}/${module_name}"
mvn -Dmaven.test.skip=true clean package
command_failed "${master_dir}/${module_name} compile failed!"
cd "${master_dir}/${module_name}/target/${module_name}/WEB-INF/lib"
nowLibs=(*)
#------------------------------------------------------------------------------
#step 5
#------------------------------------------------------------------------------
#web_path构建docker并push,并删除war
cd "${master_dir}/${module_name}"
#mvn -Dmaven.test.skip=true docker:build -DpushImage
command_failed "${master_dir}/${module_name} docker push failed!"
rm -rf $(find "${master_dir}" -name '*.war' | grep 'docker')
#------------------------------------------------------------------------------
#提取master_dir编译后的array_compile文件到incremental_dir文件夹
path_prefix="${module_name}/src/main/java/"
copy_class_file ${path_prefix} ${array_compile}
#------------------------------------------------------------------------------
#提取array_resource文件到master_dir文件夹和incremental_dir文件夹
path_prefix="${module_name}/src/main/resources/"
copy_file ${path_prefix} ${array_resource}
#------------------------------------------------------------------------------
#提取array_static文件到master_dir文件夹和incremental_dir文件夹
path_prefix="${module_name}/src/main/webapp/"
copy_file ${path_prefix} ${array_static}
#------------------------------------------------------------------------------
#对比新增jar
difLibs=()
for i in ${nowLibs[@]}
do
	skip=
	for j in ${oldLibs[@]}
	do
		[[ $i == $j ]] && { skip=1; break; }
	done
	[[ -n $skip ]] || difLibs+=("$i")
done
#create lib dir
mkdir -p ${incremental_dir}/${module_name}/WEB-INF/lib

if [[ ${#difLibs[@]} != 0 ]]
then
	for i in ${difLibs[@]}
	do
		cp $i ${incremental_dir}/${module_name}/WEB-INF/lib
	done
fi
#move lib_explanation.sh to lib dir
mv ${WORKSPACE}/lib_explanation.sh ${incremental_dir}/${module_name}/WEB-INF/lib/lib_explanation.sh
cd ${incremental_dir}
zip -r -q "${module_name}.zip" ${module_name}/*


diff -r /root/.jenkins/workspace/TEST-JAVA/zkp-dbms-web/ /root/.jenkins/workspace/TEST-JAVA/master/zkp-dbms-web/




git diff --name-status origin/1.0.0-release HEAD | grep '^M' | awk '{print $2}' | grep -v '^\.'  | grep -v '.java'

git diff --name-status d725b5dc9e78a2a4efd5fe8fabf1ab15100ea1be a66f117b5bd729f19f2334d6ab65378293a219ef | grep -v '^.' | grep '^D' | awk '{print $2}'

git diff --name-status d725b5dc9e78a2a4efd5fe8fabf1ab15100ea1be a66f117b5bd729f19f2334d6ab65378293a219ef | grep -v '^.' | grep '^D' | awk '{print $2}'


git diff --name-status d725b5dc9e78a2a4efd5fe8fabf1ab15100ea1be b7d17c128b5fc746a07fd6205e79c5ed440305f7


curl -o 1.0.0-release.zip "http://192.168.1.215:9090/zip/?r=joinwe/zkp-dbms.git&h=1.0.0-release&format=zip"
curl -o 1.0.2-release.zip "http://192.168.1.215:9090/zip/?r=joinwe/zkp-dbms.git&h=1.0.2-release&format=zip"

diff -ruNaq ./test/a ./test/b > patch.log

diff -ruaq /root/test/b/zkp-dbms-web/target/classes /root/test/a/zkp-dbms-web/target/classes > patch.log


diff -ruNaq /root/test/b/ /root/test/a --exclude=/tartget | grep '^Files'


diff -ruaq /root/test/b/ /root/test/a | grep '^Only in'

diff -ruaq /root/test/b/zkp-dbms-web/target/zkp-dbms-web/WEB-INF/lib /root/test/a/zkp-dbms-web/target/dbms-web/WEB-INF/lib > patch.log








