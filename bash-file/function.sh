#!/bin/bash -ex

base_url="http://192.168.1.222:8081/nexus/content/repositories/"
snapshots_url="${constant_base_url}snapshots/"
alpha_url="${constant_base_url}alpha/"
beta_url="${constant_base_url}beta/"
releases_url="${constant_base_url}releases/"
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
-DremoveSnapshot=true -DnewVersion=${project.version}"-BETA"
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
mvn clean deploy -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_local_dir}" \
-DaltSnapshotDeploymentRepository="nexus-snapshots::default::${snapshots_url}"
;;
"sit")
mvn clean deploy -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_local_dir}" \
-DaltReleaseDeploymentRepository="nexus-snapshots::default::${alpha_url}"
;;
"uet")
mvn clean deploy -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_local_dir}" \
-DaltReleaseDeploymentRepository="nexus-snapshots::default::${beta_url}"
;;
"pro")
mvn clean deploy -q -B -e -U -Dmaven.test.skip=true \
-Dmaven.repo.local="${maven_local_dir}" \
-DaltReleaseDeploymentRepository="nexus-snapshots::default::${releases_url}"
;;
esac
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
#名字:fun_unzip_file
#描述:解压文件到指定目录，并删除原文件
#范例:fun_unzip_file "/zip_file_path" "/dir_path"
#$1:文件路径
#$1:目录路径
#------------------------------------------------------------------------------
fun_backup_file(){
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
#$1:文件夹路径
#------------------------------------------------------------------------------
fun_create_script(){
cat << "EOF" >> "${1}/remove_file.sh"
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
#$1:文件夹路径
#$2:内容
#------------------------------------------------------------------------------
fun_superadd_script(){
echo "${2}" >> "${1}/remove_file.sh"
}

