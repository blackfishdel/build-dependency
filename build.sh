#!/bin/bash
set -x
###########################################
#command_failed:判断命令是否正常执行，如果错误并输出错误信息并退出脚本
###########################################
command_failed(){
	if [ $? -ne 0 ]
	then
		echo "error: $*"
		exit 1
	fi
}

###########################################
#创建自删除文件lib_explanation.sh
###########################################
echo "info: lib_explanation.sh build!"

echo "#!/bin/bash" > ${WORKSPACE}/lib_explanation.sh
echo "###########################################" >> ${WORKSPACE}/lib_explanation.sh
echo "#BASEDIR" >> ${WORKSPACE}/lib_explanation.sh
echo "#解决获得脚本存储位置绝对路径" >> ${WORKSPACE}/lib_explanation.sh
echo "#这个方法可以完美解决别名、链接、source、bash -c 等导致的问题" >> ${WORKSPACE}/lib_explanation.sh
echo "###########################################" >> ${WORKSPACE}/lib_explanation.sh
echo "SOURCE=\${BASH_SOURCE[0]}" >> ${WORKSPACE}/lib_explanation.sh
echo "while [ -h \${SOURCE} ]; do" >> ${WORKSPACE}/lib_explanation.sh
echo "  DIR=\$( cd -P \$( dirname \${SOURCE} ) \&\& pwd \)" >> ${WORKSPACE}/lib_explanation.sh
echo "  SOURCE=\$(readlink \${SOURCE})" >> ${WORKSPACE}/lib_explanation.sh
echo "  [[ \${SOURCE} != /* ]] && SOURCE=\${DIR}/\${SOURCE}" >> ${WORKSPACE}/lib_explanation.sh
echo "done" >> ${WORKSPACE}/lib_explanation.sh
echo "#获取到该文件当前目录" >> ${WORKSPACE}/lib_explanation.sh
echo "BASEDIR=\$( cd -P \$( dirname \${SOURCE} ) && pwd )" >> ${WORKSPACE}/lib_explanation.sh
echo "#进入到该文件当前目录,删除目录下文件" >> ${WORKSPACE}/lib_explanation.sh
echo "cd \${BASEDIR}" >> ${WORKSPACE}/lib_explanation.sh

###########################################
#打印执行命令
#指定dependency文件夹
#找到目标项目dependency.txt while读取
#dependency.txt文件不能少于2行,最后一行不执行
#在lib_explanation.sh中写入删除的jar
###########################################
echo "info: dependencys build!"

mkdir -p ${WORKSPACE}/dependency
BASEDIR=${WORKSPACE}/dependency

if [ ${project_name} = ${module_name} ]
then
		BASEFILE=$(find ${WORKSPACE} -name dependency.txt | head -n 1)
	else
		BASEFILE=$(find ${WORKSPACE}/${module_name} -name dependency.txt | head -n 1)
fi

if [ ${BASEFILE} ]
then
	while read pathLine
	do
		if [[ ${pathLine} == "end" || ${pathLine} =~ "#" ]]
		then
			continue
		fi
		proName=`echo ${pathLine} | cut -d \; -f 1`
		proBranch=`echo ${pathLine} | cut -d \; -f 2`
		proPath=`echo ${pathLine} | cut -d \; -f 3`
		proType=`echo ${pathLine} | cut -d \; -f 4`
		if [[ ${proType} == "deploy" ]]
		then
			#git下载代码并更新
			git clone ${proPath}
			if [[ ${proName} =~ "/" ]]
			then
				cd ${BASEDIR}/${proName%/*}
			fi
			#进入到子目录
			git checkout ${proBranch}
			git fetch
			cd ${BASEDIR}/${proName}
			echo ${branchName}"  打包发布该分支"
			#调用mvn构建项目,更新本地库，更新远端库
			mvn -Dmaven.test.skip=true clean package install 
			command_failed ${proName}" install failed!"
			mvn -Dmaven.test.skip=true deploy -DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ -DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/
			command_failed ${proName}" deploy failed!"
		elif [[ ${proName} != "/" && ${proName} != "" && ${proType} == "delete" ]]
		then
			echo "rm -f "${proName} >> ${WORKSPACE}/lib_explanation.sh
		fi
		#退出到主目录
		cd ${BASEDIR}
	done < ${BASEFILE}
else
	echo "info: the "${project_name}" is not find a dependency.txt!"
fi

echo "rm -f \${BASEDIR}/lib_explanation.sh" >> ${WORKSPACE}/lib_explanation.sh

###########################################
#删除dependency文件夹，退回项目本身，开始构建目标项目
###########################################
echo "info: "${project_name}" build!"

rm -rf ${BASEDIR}
cd ${WORKSPACE}
mvn -Dmaven.test.skip=true clean
command_failed ${project_name}" clean failed!"

projectName=${project_name}
moduleName=${module_name}
branchName=${branch_name}
lastTag=${last_tag}

if [ ${projectName} = ${moduleName} ]
then
	moduleBase=${WORKSPACE}
else
	moduleBase=${WORKSPACE}/${moduleName}
fi

###########################################
#deploy到nexus使maven执行时能正确从nexus抓取依赖
###########################################
cd ${WORKSPACE}
git stash
git fetch
git checkout origin/${branch_name}
git pull origin ${branch_name}

mvn -Dmaven.test.skip=true clean package install 
command_failed ${project_name}" install failed!"

mvn -Dmaven.test.skip=true deploy -DaltReleaseDeploymentRepository=nexus-releases::default::http://192.168.1.222:8081/nexus/content/repositories/releases/ -DaltSnapshotDeploymentRepository=nexus-snapshots::default::http://192.168.1.222:8081/nexus/content/repositories/snapshots/ 
command_failed ${project_name}" deploy failed!"

rm -rf $(find ./ -name "*.war")
rm -rf $(find ./ -name "*.jar")

###########################################
#抓取master分支的zip包，解压代码至master目录,并package，获取旧版本lib
###########################################
echo "info: ${moduleName}.zip build!"

mkdir -p ${moduleBase}/target/build
buildDir="${moduleBase}/target/build"
if [ -d ${moduleBase}/target/build ]
then
	rm -rf ${moduleBase}/target/build/*
fi

cd ${buildDir}
curl -o master.zip "http://192.168.1.215:9090/zip/?r=joinwe/${projectName}.git&h=master&format=zip"
unzip -q -d ${buildDir}/master master.zip
rm -f ${buildDir}/master.zip

if [ ${projectName} = ${moduleName} ]
then
	mkdir -p ${buildDir}/master/${moduleName}
	cd ${buildDir}/master
	mv $(ls | grep -v ${moduleName}) ${buildDir}/master/${moduleName}
fi

cd ${buildDir}/master/${moduleName}
mvn -Dmaven.test.skip=true clean package install 
command_failed "master/${moduleName}  install failed!"

cd ${buildDir}/master/${moduleName}/target/${moduleName}/WEB-INF/lib
oldLibs=(*)

###########################################
#branch版本对比Tag版本生成修改文件列表，
#compile,static,resource,pom。
###########################################

cd ${WORKSPACE}
compileFileList=$(git diff ${lastTag} HEAD --name-only | grep ${moduleName}** | grep **.java)
staticFileList=$(git diff ${lastTag} HEAD  --name-only --ignore-all-space | grep ${moduleName}/src/main/webapp/**.*)
pomFileList=$(git diff ${lastTag} HEAD --name-only | grep **pom.xml)
read -a array <<< ${compileFileList}
read -a array_static <<< ${staticFileList}
read -a array_pom <<< ${pomFileList}

#将修改的.pom应用到master dir
if [[ ${#array_pom[@]} != 0 ]]
then
	for i in ${!array_pom[@]};do
		cp ${array_pom[$i]} ${buildDir}/master/${array_pom[$i]}
	done
fi

cd ${moduleBase}
resourceFileList=$(git diff ${lastTag} HEAD --name-only | grep ${moduleName}/src/main/resources/**.*)
read -a array_resource <<< ${resourceFileList}

#将修改的.java打包成patch.zip
if [[ $(echo ${compileFileList}) != "" ]]
then
	zip -q ${buildDir}/patch.zip ${compileFileList}
fi

###########################################
#升级包patch.zip覆盖至master dir并编译
###########################################
if [ ! -f ${buildDir}"/patch.zip" ]
then
	unzip -q -o patch.zip -d master
fi
cd ${buildDir}/master/${moduleName}
mvn -Dmaven.test.skip=true clean compile 
command_failed "master/${moduleName} compile failed!"

###########################################
#提取master dir编译后的class文件到升级包
#提取变更的静态文件到升级包,并覆盖至master dir代码
###########################################
echo "info: copy changed file to master/${moduleName}!"

javaSuffix=.java
classSuffix=.class

if [[ ${#array[@]} != 0 ]]
then
	for i in ${!array[@]};do
		mkdir -p $(dirname ${buildDir}/${moduleName}/WEB-INF/classes/${array[$i]:${#moduleName}+15})
		cp ${buildDir}/master/${moduleName}/target/classes/${array[$i]:${#moduleName}+15:-${#javaSuffix}}$classSuffix /
		   ${buildDir}/${moduleName}/WEB-INF/classes/${array[$i]:${#moduleName}+15:-${#javaSuffix}}$classSuffix
	done
fi

if [[ ${#array_static[@]} != 0 ]]
then
	for i in ${!array_static[@]};do
		mkdir -p $(dirname ${buildDir}/${moduleName}/${array_static[$i]:${#moduleName}+17})
		cp ${WORKSPACE}/${array_static[$i]} ${buildDir}/${moduleName}/${array_static[$i]:${#moduleName}+17}
		cp ${WORKSPACE}/${array_static[$i]} ${buildDir}/master/${array_static[$i]}
	done
fi

if [[ ${#array_static[@]} != 0 ]]
then
	for i in ${!array_resource[@]};do
		mkdir -p $(dirname ${buildDir}/${moduleName}/WEB-INF/classes/${array_resource[$i]:${#moduleName}+20})
		cp ${WORKSPACE}/${array_resource[$i]} ${buildDir}/${moduleName}/WEB-INF/classes/${array_resource[$i]:${#moduleName}+20}
		cp ${WORKSPACE}/${array_resource[$i]} ${buildDir}/master/${array_resource[$i]}
	done
fi

###########################################
#master重新编译并打war包
#将当前分支的docker目录覆盖至master代码
#构建镜像推送至215服务器
###########################################
echo "info: again build master/${moduleName}!"
cd ${buildDir}/master/${moduleName}
mvn -Dmaven.test.skip=true package
command_failed "master/${moduleName} package failed!"
cp -r ${excuteDir} ${buildDir}/master/${moduleName}/src/main
mvn -Dmaven.test.skip=true docker:build -DpushImageTag
command_failed "master/${moduleName} docker push failed!"
cd ${buildDir}/master/${moduleName}/target/docker/
rm -rf $(find ./ -name "*.war")

###########################################
#创建增量文件$moduleName.zip
###########################################
echo "info: master/${moduleName}/**/lib/*.jar and ${moduleName}/**/lib/*.jar comparison!"
cd ${buildDir}/master/${moduleName}/target/${moduleName}/WEB-INF/lib
libs=(*)
difLibs=()
#对比新增jar
for i in ${libs[@]}; do
	skip=
	for j in ${oldLibs[@]}; do
	    [[ $i == $j ]] && { skip=1; break; }
	done
	[[ -n $skip ]] || difLibs+=("$i")
done

mkdir -p ${buildDir}/${moduleName}/WEB-INF/lib

if [[ ${#difLibs[@]} != 0 ]]
then
	rm -rf ${buildDir}/${moduleName}/WEB-INF/lib/*
	for i in ${difLibs[@]}; do
		cp $i ${buildDir}/${moduleName}/WEB-INF/lib
	done
fi

mv ${WORKSPACE}/lib_explanation.sh ${buildDir}/${moduleName}/WEB-INF/lib/lib_explanation.sh

###########################################
#压缩增量包并上传（ftp，scp）到指定位置
###########################################
echo "info: compress the incremental package and upload it!"
cd ${buildDir}
zip -r -q "${moduleName}.zip" ${moduleName}/*

###########################################
#增量文件上传ftp
#本地的${buildDir}/ to ftp服务器上的/home/data
#ftp -n<<!
#open 192.168.1.215
#user upload_admin 123456
#hash
#cd /home/data
#lcd ${buildDir}/
#prompt
#put ${moduleName}".zip"
#close
#bye
#!
###########################################

scp "${buildDir}/${moduleName}.zip" "root@192.168.1.215:/home/test-version/joinwe/${moduleName}.zip"
command_failed "backup file is failed!"

echo "info: success end!"
exit 0