#!/bin/bash -ex

#------------------------------------------------------------------------------
#文件路径数组处理需要处理
copy_diff_file(){
file_path_array=$1
old_dir=$2
now_dir=$3

if [ ${#file_path_array[@]} != 0 ];then
	for i in ${!file_path_array[@]};do
		file_path=${file_path_array[i]}
		mkdir -p "${next_dir}/${file_path%/*}"
		cp "${last_dir}/${file_path}" "${next_dir}/${file_path}"
	done
fi
}
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#编译前文件替换 java
for i in deleted_java_array;do
	file_path=${deleted_java_array[i]}
	if [[ ${file_path} && ${file_path} != '*' && ${file_path} != '/'  ]];then
		rm -rf ${master_dir}/${file_path}
	fi
done

for i in added_java_array;do
	file_path=${added_java_array[i]}
	mkdir ${file_path%/*}
	cp "${WORKSPACE}/${file_path}" "${master_dir}/${file_path}"
done

for i in modified_java_array;do
	file_path=${modified_java_array[i]}
	mkdir ${file_path%/*}
	cp "${WORKSPACE}/${file_path}" "${master_dir}/${file_path}"
done
#编译前文件替换 other
for i in deleted_other_array;do
	file_path=${deleted_other_array[i]}
	if [[ ${file_path} && ${file_path} != '*' && ${file_path} != '/'  ]];then
		rm -rf ${master_dir}/${file_path}
	fi
done

for i in added_other_array;do
	file_path=${added_other_array[i]}
	mkdir ${file_path%/*}
	cp "${WORKSPACE}/${file_path}" "${master_dir}/${file_path}"
done

for i in modified_other_array;do
	file_path=${modified_other_array[i]}
	mkdir ${file_path%/*}
	cp "${WORKSPACE}/${file_path}" "${master_dir}/${file_path}"
done
#------------------------------------------------------------------------------
#master_dir 打包
cd "${master_dir}/${module_name}"
mvn -Dmaven.test.skip=true clean package
command_failed "${master_dir}/${module_name} compile failed!"
cd "${master_dir}/${module_name}/target/${module_name}/WEB-INF/lib"
nowLibs=(*)
#------------------------------------------------------------------------------
#编译后文件提取



