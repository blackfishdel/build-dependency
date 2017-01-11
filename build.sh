#!/bin/bash

###########################################
#BASEDIR
#解决获得脚本存储位置绝对路径
#这个方法可以完美解决别名、链接、source、bash -c 等导致的问题
###########################################
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do 
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" 
done
#获取到主目录
BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
#进入到主目录,删除主目录下文件夹
cd $BASEDIR
ls -F|grep '/$' | while read fileLine
do
	echo $BASEDIR/${fileLine}"  删除"
	rm -rf $BASEDIR/${fileLine}
done

###########################################
#while读取path.txt文件
#该文件必须与build.sh文件在同级目录下
#path.txt文件不能少于2行,最后一行不执行
###########################################
while read pathLine
do
	line=${pathLine##*/} && line=${line%.*}
	#git下载代码并更新
	git clone ${pathLine} ${line}
	#进入到子目录
	cd ${BASEDIR}/${line}
	git pull
	#while读取分支
	git branch -r | while read branchName
	do
		#if判断分支是否是release分支
		if [[ $(echo ${branchName} | grep "release") != "" ]]
		then
			echo ${branchName}"  打包发布该分支"
			git checkout ${branchName}
			#调用mvn构建项目
			mvn -Dmaven.test.skip=true clean deploy
		else
			echo ${branchName}"  忽略处理该分支"
		fi
	done
	#退出到主目录
	cd ${BASEDIR}
done < ${BASEDIR}/path.txt
