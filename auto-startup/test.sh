#!/bin/bash -ex
#------------------------------------------------------------------------------
#创建启动命令数组

declare -a command_array 
command_array=( ${command_array[@]} $(echo "aaa"))
command_array=( ${command_array[@]} $(echo "bbb"))
command_array=( ${command_array[@]} $(echo "ccc"))

#------------------------------------------------------------------------------
#循环数组并执行

if [[ ${#command_array[@]} != 0 ]];then
	for i in ${!command_array[@]};do
		$(${command_array[i]})
		if [$? = 0];then
			echo "${i} run succeed!"
		else
			echo "${i} run faild!"
		fi
	done
fi
