#!/bin/bash -ex

#remote paramter:
#project_name
#module_name
#branch_name
#last_tag
#------------------------------------------------------------------------------
#init
#------------------------------------------------------------------------------
cd ${WORKSPACE}
#移动文件到project_name文件夹下
BASE_DIR="${WORKSPACE}/${project_name}"
mkdir -p "${WORKSPACE}/${project_name}"
mv $(ls -a | grep -v "^${project_name}$" | grep -v "\.$" | grep -v "\.\.$") "${WORKSPACE}/${project_name}"

dependency_dir="${WORKSPACE}/dependency"
mkdir -p ${WORKSPACE}/dependency

master_zip_url="http://192.168.1.215:9090/zip/?r=joinwe/${project_name}.git&h=master&format=zip"
master_zip_path="${WORKSPACE}/master.zip"

master_dir="${WORKSPACE}/master"
mkdir -p ${master_dir}

last_tag_zip_url="http://192.168.1.215:9090/zip/?r=joinwe/${project_name}.git&h=${last_tag}&format=zip"
last_tag_zip_path="${WORKSPACE}/last.zip"

last_dir="${WORKSPACE}/last"
mkdir -p ${last_dir}

patch_dir="${WORKSPACE}/patch"
patch_name="${module_name}.zip"
mkdir -p ${patch_dir}

maven_local_dir="${WORKSPACE}/maven_reprository"
mkdir -p ${maven_local_dir}
#------------------------------------------------------------------------------
#step 1
#------------------------------------------------------------------------------
#创建explanation.sh文件
touch ${WORKSPACE}/explanation.sh
cat << "EOF" > "${WORKSPACE}/explanation.sh"
#!/bin/bash
#BASEDIR解决获得脚本存储位置绝对路径,这个方法可以完美解决别名、链接、source、bash -c 等导致的问题
SOURCE="${BASH_SOURCE[0]}"

while [ -h ${SOURCE} ];do
DIR=$( cd -P $( dirname ${SOURCE} ) && pwd )
SOURCE="$(readlink ${SOURCE})"
[[ ${SOURCE} != /* ]] && SOURCE=${DIR}/${SOURCE}
done

BASEDIR="$( cd -P $( dirname ${SOURCE} ) && pwd )"
cd ${BASEDIR}
EOF
#------------------------------------------------------------------------------
#step 2
#------------------------------------------------------------------------------
#解析dependency.txt文件
dependency_path="$(find ${BASE_DIR} -name dependency.txt | head -n 1)"

if [ ${dependency_path} ];then
#进入到dependency_dir
cd ${dependency_dir}
while read pathLine;do
if [[ ${pathLine} == "end" || ${pathLine} =~ "#" ]];then
continue
fi
pro_name=`echo ${pathLine} | cut -d \; -f 1`
pro_branch=`echo ${pathLine} | cut -d \; -f 2`
pro_path=`echo ${pathLine} | cut -d \; -f 3`
pro_type=`echo ${pathLine} | cut -d \; -f 4`
if [ ${pro_type} = "deploy" ];then
#git下载代码并更新
git clone ${pro_path}
if [[ ${pro_name} =~ "/" ]];then
cd ${dependency_dir}/${pro_name%/*}
else
cd ${dependency_dir}/${pro_name}
fi
git checkout ${pro_branch}
git fetch
#进入到maven构建目录
cd ${dependency_dir}/${pro_name}
echo "info:${pro_name} ${pro_branch} 打包发布该分支!"
#调用mvn构建项目,更新本地库，更新远端库
mvn clean package install deploy -q -B -e -U -Dmaven.test.skip=true  -Dmaven.repo.local=${WORKSPACE}/maven_reprository \
-DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ \
-DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
fi
#退出到dependency_dir并删除目录下文件，避免git同一个项目目录冲突
cd ${dependency_dir}
rm -rf ${dependency_dir}/*
done < ${dependency_path}
else
echo "warn:dependency.txt is not found!"
fi

# 删除dependency_dir
rm -rf ${dependency_dir}
#------------------------------------------------------------------------------
#step 3
#------------------------------------------------------------------------------
#当项目第一次发布时没有master分支，也没有last_tag,所以last_tag与branch_name相同
if [ ${branch_name} != ${last_tag#*/} ];then
project_tag="patch" #以发布过，有master分支，有tag分支，有patch包
elif [[ ${branch_name} = ${last_tag#*/} ||  ${last_tag} ]];then
project_tag="full" #未发布过，没有master分支，没有tag分支,没有patch包
fi
#------------------------------------------------------------------------------
#下载master.zip并解压到master_dir,当前未编译
case ${project_tag} in
'patch')
curl -o "${master_zip_path}" "${master_zip_url}"
unzip -q -d "${master_dir}" "${master_zip_path}"
rm -rf "${master_zip_path}"

#对比branch与master修改文件
diff_file_list=($(diff -ruaq "${BASE_DIR}" "${master_dir}" \
	| grep '^Files' | grep -v '\.git' | awk '{print $2}' ))
#对比branch有，master没有的文件
#屏蔽没有后缀的列，认为没有“.”的列为文件夹
#屏蔽master的文件列，默认为master需要文件
add_file_list=($(diff -ruaq "${BASE_DIR}" "${master_dir}" \
	| grep '^Only' | grep "${BASE_DIR}" | grep -v '\.git' \
	| awk '{print $3,$4;}' | sed 's/: /\//' ))
	
#屏蔽master的文件列，默认为master需要文件
remove_file_list=($(diff -ruaq "${BASE_DIR}" "${master_dir}" \
	| grep '^Only' | grep "${master_dir}" | grep -v '\.git' \
	| awk '{print $3,$4;}' | sed 's/: /\//' ))

#把branch的add\diff文件复制到master
if [[ ${#diff_file_list[@]} != 0 ]];then
for i in ${!diff_file_list[@]};do
dir_path="${diff_file_list[$i]/${BASE_DIR}/${master_dir}}"
mkdir -p $(dirname "${dir_path}")
if [ -d ${diff_file_list[$i]} ];then
continue
fi
cp "${diff_file_list[$i]}" "${dir_path}"
done
fi

if [[ ${#add_file_list[@]} != 0 ]];then
	for i in ${!add_file_list[@]};do
		dir_path="${add_file_list[$i]/${BASE_DIR}/${master_dir}}"
		if [ -d ${add_file_list[$i]} ];then
			mkdir -p "${dir_path}"
			cp -r "${add_file_list[$i]}" "${dir_path}"
		else
			mkdir -p $(dirname "${dir_path}")
			cp "${add_file_list[$i]}" "${dir_path}"
		fi
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
mvn clean package install deploy -B -e -U -Dmaven.test.skip=true  -Dmaven.repo.local=${WORKSPACE}/maven_reprository \
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
		if [ -d ${patch_add_file_list[$i]} ];then
			mkdir -p "${dir_path}"
			cp -r "${patch_add_file_list[$i]}" "${dir_path}"
		else
			mkdir -p $(dirname "${dir_path}")
			cp "${patch_add_file_list[$i]}" "${dir_path}"
		fi
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
#------------------------------------------------------------------------------
#step 4
#------------------------------------------------------------------------------
#master_dir进行打包
cd "${BASE_DIR}"
mvn clean package install deploy -q -B -e -U -Dmaven.test.skip=true -Dmaven.repo.local=${WORKSPACE}/maven_reprository \
-DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ \
-DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
#master_dir进行docker image构建并上传
if [ ! -d "${BASE_DIR}/${module_name}" ];then
cd "${BASE_DIR}"
else
cd "${BASE_DIR}/${module_name}"
fi
mvn docker:build -q -Dmaven.test.skip=true -DpushImage
rm -rf $(find ./ -name '*\.war'| head -n 1) 
war_path=$(find ./ -name '*\.war'| head -n 1) 
scp "${war_path}" "root@192.168.1.215:/home/test-version/joinwe/${war_path##*/}"
;;
esac
