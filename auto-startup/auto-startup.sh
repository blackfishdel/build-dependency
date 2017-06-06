#!/bin/bash
#------------------------------------------------------------------------------
#创建启动命令数组

declare -a command_array 
#nexus
command_array=( ${command_array[@]} $(/usr/local/nexus-2.5.1-01/bin/nexus start))

#jenkins
command_array=( ${command_array[@]} $(/usr/local/apache-tomcat-jenkins/bin/catalina.sh start))

#docker
command_array=( ${command_array[@]} $(docker start registry nginx config-1.0.2 config-1.0.2-dev config-1.0.2-sit))

#------------------------------------------------------------------------------
#循环数组并执行

if [[ ${#command_array[@]} != 0 ]];then
	for i in ${!command_array[@]};do
		$(${command_array[i]})
		if [$? = 0];then
			echo "${i} start succeed!"
		else
			echo "${i} start faild!"
		fi
	done
fi



