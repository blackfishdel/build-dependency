#!/bin/bash
###########################################
#打印执行命令
#指定dependency文件夹
#找到目标项目dependency.txt
###########################################
set -x
mkdir ${WORKSPACE}/dependency
cd ${WORKSPACE}/dependency
BASEDIR=${WORKSPACE}/dependency
BASEFILE=$(find ${WORKSPACE} -name dependency.txt | head -n 1)

###########################################
#创建清单文件lib_explanation.sh
###########################################
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
#while读取dependency.txt文件
#dependency.txt文件不能少于2行,最后一行不执行
#在lib_explanation.sh中写入删除的jar
###########################################
while read pathLine
do
	if [[ ${pathLine} == "end" && $(echo ${pathLine} | grep "#") != "" ]]
	then
		continue
	fi
	proName=`echo ${pathLine} | cut -d \; -f 1`
	proBranch=`echo ${pathLine} | cut -d \; -f 2`
	proTag=`echo ${pathLine} | cut -d \; -f 3`
	proPath=`echo ${pathLine} | cut -d \; -f 4`
	proType=`echo ${pathLine} | cut -d \; -f 5`
	if [[ ${proType} == "deploy" ]]
	then
		#git下载代码并更新
		git clone ${proPath}
		#进入到子目录
		cd $BASEDIR/${proName}
		git checkout origin/${proBranch}
		git pull origin ${proBranch}
		echo ${branchName}"  打包发布该分支"
		#调用mvn构建项目
		mvn -Dmaven.test.skip=true clean deploy
	elif [[ ${proName} != "/" && ${proName} != "" && ${proType} == "delete" ]]
	then
		echo "rm -f "${proName} >> ${WORKSPACE}/lib_explanation.sh
	fi
	#退出到主目录
	cd ${BASEDIR}
done < ${BASEFILE}

echo "rm -f \${BASEDIR}/lib_explanation.sh" >> ${WORKSPACE}/lib_explanation.sh
###########################################
#删除dependency文件夹
#退回项目本身
###########################################
rm -rf ${BASEDIR}

###########################################
#退回项目本身
#开始构建目标项目
###########################################
cd ${WORKSPACE}
mvn clean

projectName=${project_name}
moduleName=${module_name}
branchName=${branch_name}
lastTag=${project_tag}

excuteDir=$(find ${WORKSPACE} -name \\docker | head -n 1)
moduleBase=${excuteDir%/*/*/*}
buildDir=${moduleBase}/target/build

mkdir -p ${moduleBase}/target/build/
rm -rf ${moduleBase}/target/build/*

###########################################
#deploy到nexus使maven执行时能正确从nexus抓取依赖
###########################################
cd ${WORKSPACE}
git stash
git fetch
git checkout origin/${branch_name}
git pull origin ${branch_name}
mvn deploy -Dmaven.test.skip=true

###########################################
#抓取master分支的zip包
#解压代码至master目录,并package
#获取旧版本lib
###########################################
cd ${buildDir}
curl -o master.zip "http://192.168.1.215:9090/zip/?r=joinwe/"${projectName}".git&h=master&format=zip"
unzip -q -d ${buildDir}/master master.zip
cd ${buildDir}/master/${moduleName}
mvn package -Dmaven.test.skip=true
cd ${buildDir}/master/${moduleName}/target/${moduleName}/WEB-INF/lib
oldLibs=(*)

###########################################
#branch_name版本对比lastTag修改文件
#compile,static,resource,pom
###########################################
cd ${WORKSPACE}
compileFileList=$(git diff ${lastTag} HEAD --name-only | grep ${moduleName}** | grep **.java)
staticFileList=$(git diff HEAD ${lastTag} --name-only --ignore-all-space | grep ${moduleName}/src/main/webapp/**.*)
pomFileList=$(git diff ${lastTag} HEAD --name-only | grep **pom.xml)
read -a array <<< ${compileFileList}
read -a array_static <<< ${staticFileList}
read -a array_pom <<< ${pomFileList}

#将修改的.pom应用到master dir
for i in ${!array_pom[@]}
do
	cp ${array_pom[$i]} ${buildDir}/master/${array_pom[$i]}
done

cd ${moduleBase}
resourceFileList=$(git diff ${lastTag} HEAD --name-only | grep ${moduleName}/src/main/resources/**.*)
read -a array_resource <<< ${resourceFileList}

#将修改的.java打包成patch.zip
zip -q ${buildDir}/patch.zip ${compileFileList}

###########################################
#升级包patch.zip覆盖至master dir并编译
###########################################
cd ${buildDir}
unzip -q -o patch.zip -d master
cd ${buildDir}/master/${moduleName}
mvn clean compile -Dmaven.test.skip=true

###########################################
#提取master dir编译后的class文件到升级包
#提取变更的静态文件到升级包 并覆盖至master dir代码
###########################################
javaSuffix=.java
classSuffix=.class
for i in ${!array[@]}
do
	mkdir -p $(dirname ${buildDir}/${moduleName}/WEB-INF/classes/${array[$i]:${#moduleName}+15})
	cp ${buildDir}/master/${moduleName}/target/classes/${array[$i]:${#moduleName}+15:-${#javaSuffix}}$classSuffix ${buildDir}/${moduleName}/WEB-INF/classes/${array[$i]:${#moduleName}+15:-${#javaSuffix}}$classSuffix
done
for i in ${!array_static[@]}
do
	mkdir -p $(dirname ${buildDir}/${moduleName}/${array_static[$i]:${#moduleName}+17})
	cp ${WORKSPACE}/${array_static[$i]} ${buildDir}/${moduleName}/${array_static[$i]:${#moduleName}+17}
	cp ${WORKSPACE}/${array_static[$i]} ${buildDir}/master/${array_static[$i]}
done

###########################################
#提取变更的classes dir下的资源文件 并覆盖至master dir代码
###########################################
for i in ${!array_resource[@]}
do
	mkdir -p $(dirname ${buildDir}/${moduleName}/WEB-INF/classes/${array_resource[$i]:${#moduleName}+20})
	cp ${WORKSPACE}/${array_resource[$i]} ${buildDir}/${moduleName}/WEB-INF/classes/${array_resource[$i]:${#moduleName}+20}
	cp ${WORKSPACE}/${array_resource[$i]} ${buildDir}/master/${array_resource[$i]}
done

###########################################
#重新编译并打war包
#将当前分支的docker目录覆盖至master代码
#构建镜像推送至215服务器
###########################################
cd ${buildDir}/${moduleName}
mvn package -Dmaven.test.skip=true
cp -r ${excuteDir} ${buildDir}/master/${moduleName}/src/main
mvn docker:build -DpushImageTag 

###########################################
#创建增量文件$moduleName.zip
###########################################
#当前版本lib
cd ${buildDir}/${moduleName}/target/${moduleName}/WEB-INF/lib
libs=(*)
#对比新增jar
difLibs=()
for i in ${libs[@]}; do
	skip=
	for j in ${oldLibs[@]}; do
	    [[ $i == $j ]] && { skip=1; break; }
	done
	[[ -n $skip ]] || difLibs+=("$i")
done
mkdir ${buildDir}/${moduleName}/WEB-INF/lib
rm -rf ${buildDir}/${moduleName}/WEB-INF/lib/*
for i in ${difLibs[@]}; do
	cp $i ${buildDir}/${moduleName}/WEB-INF/lib
done
mv ${WORKSPACE}/lib_explanation.sh ${buildDir}/${moduleName}/WEB-INF/lib/lib_explanation.sh
#压缩增量dir
zip -q ${buildDir}/${moduleName}".zip" ${buildDir}/${moduleName}

###########################################
#增量文件上传ftp
#本地的${buildDir}/ to ftp服务器上的/home/data
###########################################
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
#ssh无密码传文件
###########################################
scp ${buildDir}/${moduleName}".zip" root@192.168.1.215:/home/test-version/joinwe/${moduleName}".zip"
