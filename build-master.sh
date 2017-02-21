#!/bin/bash -x

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
copy_file(){
	path_prefix=$1
	array=$2
	if [[ ${#array[@]} != 0 ]]
	then
		for i in ${!array[@]}
		do
			dir_path="${array[$i]:${#path_prefix}}"
			mkdir -p $(dirname "${incremental_dir}/${module_name}/${dir_path}")
#			cp "${WORKSPACE}/${array[$i]}" "${master_dir}/${module_name}/${dir_path}"
			cp "${WORKSPACE}/${array[$i]}" "${incremental_dir}/${module_name}/${dir_path}"
		done
	fi
}
#------------------------------------------------------------------------------
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
			cp "${web_path}/target/classes/${dir_path%%.*}${class_suffix}" "${incremental_dir}/${module_name}/target/classes/${dir_path%%.*}${class_suffix}"
		done
	fi
}
#------------------------------------------------------------------------------
#step 1
#------------------------------------------------------------------------------
#创建lib_explanation.sh文件
touch ${WORKSPACE}/lib_explanation.sh
cat << "EOF" > "${WORKSPACE}/lib_explanation.sh"
#!/bin/bash
#BASEDIR解决获得脚本存储位置绝对路径,这个方法可以完美解决别名、链接、source、bash -c 等导致的问题
SOURCE="${BASH_SOURCE[0]}"
while [ -h ${SOURCE} ]
do
	DIR=$( cd -P $( dirname ${SOURCE} ) && pwd )
	SOURCE="$(readlink ${SOURCE})"
	[[ ${SOURCE} != /* ]] && SOURCE=${DIR}/${SOURCE}
done
BASEDIR="$( cd -P $( dirname ${SOURCE} ) && pwd )"
cd ${BASEDIR}
EOF
#------------------------------------------------------------------------------
#解析dependency.txt文件
dependency_path="$(find ${web_path} -name dependency.txt | head -n 1)"
if [ ${dependency_path} ]
then
	while read pathLine
	do
		if [[ ${pathLine} == "end" || ${pathLine} =~ "#" ]]
		then
			continue
		fi
		pro_name=`echo ${pathLine} | cut -d \; -f 1`
		pro_branch=`echo ${pathLine} | cut -d \; -f 2`
		pro_path=`echo ${pathLine} | cut -d \; -f 3`
		pro_type=`echo ${pathLine} | cut -d \; -f 4`
		if [[ ${pro_type} == "deploy" ]]
		then
			#git下载代码并更新
			git clone ${pro_path}
			if [[ ${pro_name} =~ "/" ]]
			then
				cd ${dependency_dir}/${pro_name%/*}
			fi
			#进入到子目录
			git checkout ${pro_branch}
			git fetch
			cd ${dependency_dir}/${pro_name}
			echo "${branchName}  打包发布该分支"
			#调用mvn构建项目,更新本地库，更新远端库
			mvn -Dmaven.test.skip=true clean package -U install 
			command_failed "${pro_name} install failed!"
			mvn -Dmaven.test.skip=true deploy -DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ -DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
			command_failed "${pro_name} deploy failed!"
		elif [[ ${pro_name} != "/" && ${pro_name} != "" && ${pro_type} = "delete" ]]
		then
			echo "rm -f ${pro_name}" >> "${WORKSPACE}/lib_explanation.sh"
		fi
		#退出到主目录
		cd ${dependency_dir}
	done < ${dependency_path}
fi
echo "rm -f ${BASEDIR}/lib_explanation.sh" >> "${WORKSPACE}/lib_explanation.sh"
rm -rf ${dependency_dir}
#------------------------------------------------------------------------------
#step 2
#------------------------------------------------------------------------------
#对branch打包
cd ${WORKSPACE}
git stash
git fetch
git checkout origin/${branch_name}
git pull origin ${branch_name}
mvn -Dmaven.test.skip=true clean package -U install deploy -DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ -DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/ 
command_failed ${project_name}" deploy failed!"
rm -rf $(find ${WORKSPACE} -name "*.war")
rm -rf $(find ${WORKSPACE} -name "*.jar")
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
	rm -rf "${patch_zip_path}"
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
mvn -Dmaven.test.skip=true docker:build -DpushImage
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
#------------------------------------------------------------------------------
#step 6
#------------------------------------------------------------------------------
#压缩增量包并上传（scp）到指定位置
scp "${incremental_dir}/${module_name}.zip" "root@192.168.1.215:/home/test-version/joinwe/${module_name}.zip"
