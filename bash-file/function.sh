case ${project_tag} in
	'patch')
	master_zip_url=$(fun_master_zip_url ${project_name})
	master_zip_path="${WORKSPACE}/master.zip"
	#下载master分支
	curl -o "${master_zip_path}" "${master_zip_url}"
	unzip -q -d "${master_dir}" "${master_zip_path}"
	rm -rf "${master_zip_path}"
	
	#对比branch与master修改文件
	diff_file_list=($(diff -ruaq "${base_dir}" "${master_dir}" \
		| grep '^Files' | grep -v '\.git' | awk '{print $2}' ))
	#对比branch有，master没有的文件
	#屏蔽没有后缀的列，认为没有“.”的列为文件夹
	#屏蔽master的文件列，默认为master需要文件
	add_file_list=($(diff -ruaq "${base_dir}" "${master_dir}" \
		| grep '^Only' | grep "${base_dir}" | grep -v '\.git' \
		| awk '{print $3,$4;}' | sed 's/: /\//' ))
		
	#屏蔽master的文件列，默认为master需要文件
	remove_file_list=($(diff -ruaq "${base_dir}" "${master_dir}" \
		| grep '^Only' | grep "${master_dir}" | grep -v '\.git' \
		| awk '{print $3,$4;}' | sed 's/: /\//' ))
	
	#把branch的add\diff文件复制到master
	if [[ ${#diff_file_list[@]} != 0 ]];then
		for i in ${!diff_file_list[@]};do
			dir_path="${diff_file_list[$i]/${base_dir}/${master_dir}}"
			mkdir -p $(dirname "${dir_path}")
			if [ -d ${diff_file_list[$i]} ];then
				continue
			fi
			cp "${diff_file_list[$i]}" "${dir_path}"
		done
	fi
	
	if [[ ${#add_file_list[@]} != 0 ]];then
		for i in ${!add_file_list[@]};do
			dir_path="${add_file_list[$i]/${base_dir}/${master_dir}}"
			mkdir -p $(dirname "${dir_path}")
			if [ -d ${add_file_list[$i]} ];then
				continue
			fi
			cp "${add_file_list[$i]}" "${dir_path}"
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
	#------------------------------------------------------------------------------
	#对master_dir修改版本号
	cd ${master_dir}
	#修改父pom文件外部依赖
	jq_dep_names=$(echo ${json_description} \
	| jq '.dependencies | .[] | .modules | .[] | .name' | sed {s/\"//g})
	jq_dep_values=$(echo ${json_description} \
	| jq '.dependencies | .[] | .modules | .[] | .value' | sed {s/\"//g})
	if [ ${#jq_dep_names[@]} != 0 ];then
		for i in ${!jq_dep_names[@]};do
			fun_dependency_change "${build_context}" "${master_dir}" \
			"${jq_dep_names[${i}]}" "${jq_dep_values[${i}]}"
		done
	fi
	#修改父pom文件版本号
	fun_version_change "${build_context}" "${master_dir}"
	
	#修改子项目pom文件版本号
	jq_sub_names=$(echo ${json_description} | jq '.modules | .[] | .name' | sed {s/\"//g})
	jq_sub_values=$(echo ${json_description} | jq '.modules | .[] | .value' | sed {s/\"//g})
	if [ ${#jq_sub_names[@]} != 0 ];then
		for i in ${!jq_sub_names[@]};do
			fun_version_change "${build_context}" "${master_dir}" \
			"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
		done
	fi
	
	#编译子项目
	if [ ${#jq_sub_names[@]} != 0 ];then
		for i in ${!jq_sub_names[@]};do
			fun_deploy_nexus "${build_context}" "${master_dir}/${jq_sub_names[${i}]}"
		done
	fi
	
	#修改父pom文件项目依赖
	if [ ${#jq_sub_names[@]} != 0 ];then
		for i in ${!jq_sub_names[@]};do
			fun_dependency_change "${build_context}" "${master_dir}" \
			"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
		done
	fi
	
	#编译父项目
	fun_deploy_nexus "${build_context}" "${master_dir}"
	
	#master_dir进行docker image构建并上传
	if [ ${web_mdoule} == ${project_name} ];then
		master_web="${master_dir}"
	else
		master_web="${master_dir}/${web_mdoule}"
	fi
	fun_push_image ${master_web}
	
	#------------------------------------------------------------------------------
	#生成patch包
	#------------------------------------------------------------------------------
	#下载last tag并解压到last_dir
	last_dir="${WORKSPACE}/last_dir"
	mkdir -p ${last_dir}
	last_tag_zip_url=$(fun_zip_url ${project_name} ${last_tag})
	last_tag_zip_path="${WORKSPACE}/last.zip"
	curl -o "${last_tag_zip_path}" "${last_tag_zip_url}"
	unzip -q -d "${last_dir}" "${last_tag_zip_path}"
	rm -rf "${last_tag_zip_path}"
	#找到last_web文件夹
	if [ ${web_mdoule} == ${project_name} ];then
		last_web="${last_dir}"
	else
		last_web="${last_dir}/${web_mdoule}"
	fi
	#对last_web进行编译
	fun_package_pro ${last_dir}
	#------------------------------------------------------------------------------
	#对比master与last编译后修改文件
	patch_diff_file_list=($(diff -ruaq "${master_web}/target/${web_mdoule}" \
		"${last_web}/target/${web_mdoule}" \
		| grep '^Files' | grep -v '\.git' | awk '{print $2}'))
	#对比master编译后有，last编译后last没有的文件
	#屏蔽没有后缀的列，认为没有“.”的列为文件夹
	patch_add_file_list=($(diff -ruaq "${master_web}/target/${web_mdoule}" \
		"${last_web}/target/${web_mdoule}" \
		| grep '^Only' | grep "${master_dir}" | grep -v '\.git' \
		| awk  '{print $3,$4;}' | sed 's/: /\//'))
	
	#创建patch_dir文件夹
	patch_dir="${WORKSPACE}/patch"
	patch_name="${module_name}.zip"
	mkdir -p ${patch_dir}
	
	#把master_dir的add\diff文件复制到patch_dir
	if [[ ${#patch_diff_file_list[@]} != 0 ]];then
		for i in ${!patch_diff_file_list[@]};do
			dir_path="${patch_diff_file_list[$i]/"${master_web}/target"/${patch_dir}}"
			mkdir -p $(dirname "${dir_path}")
			if [ -d ${patch_diff_file_list[$i]} ];then
				continue
			fi
			cp "${patch_diff_file_list[$i]}" "${dir_path}"
		done
	fi
	
	if [[ ${#patch_add_file_list[@]} != 0 ]];then
		for i in ${!patch_add_file_list[@]};do
			dir_path="${patch_add_file_list[$i]/"${master_web}/target"/${patch_dir}}"
			mkdir -p $(dirname "${dir_path}")
			if [ -d ${patch_add_file_list[$i]} ];then
				continue
			fi
			cp "${patch_add_file_list[$i]}" "${dir_path}"
		done
	fi
	#对比master_dir编译后有，last_dir编译后master_dir没有的文件
	#屏蔽没有后缀的列，认为没有“.”的列为文件夹
	patch_remove_file_list=($(diff -ruaq "${master_dir}/${web_mdoule}/target/${web_mdoule}" \
									"${last_web}/target/${web_mdoule}" \
									| grep '^Only' | grep "${last_web_dir}" \
									| awk  '{print $3,$4;}' | sed 's/: /\//'  \
									| sed "s;"${last_web}/target/${web_mdoule}/";;"))
	
	if [[ ${#patch_remove_file_list[@]} != 0 ]];then
		for i in ${!patch_remove_file_list[@]};do
			if [[ -d "${last_web}/target/${web_mdoule}/${patch_remove_file_list[$i]}" ]];then
				continue
			fi
			fun_superadd_script "rm -f ${patch_remove_file_list[i]}"
		done
	fi
	
	mv "${WORKSPACE}/remove_file.sh" "${last_web}"
	
	#压缩patch_dir
	cd "${WORKSPACE}"
	zip -r "${web_mdoule}.zip" "${last_web}"
	#压缩增量包并上传（scp）到指定服务器备份
	fun_backup_file "${WORKSPACE}/${web_mdoule}.zip"
	#删除编译后文件
	rm -rf $(find ${master_dir} -name '*\.jar')
	rm -rf $(find ${master_dir} -name '*\.war')
	;;
	'full')
	#------------------------------------------------------------------------------
	cd ${base_dir}
	#修改父pom文件外部依赖
	jq_dep_names=$(echo ${json_description} \
	| jq '.dependencies | .[] | .modules | .[] | .name' | sed {s/\"//g})
	jq_dep_values=$(echo ${json_description} \
	| jq '.dependencies | .[] | .modules | .[] | .value' | sed {s/\"//g})
	if [ ${#jq_dep_names[@]} != 0 ];then
		for i in ${!jq_dep_names[@]};do
			fun_dependency_change "${build_context}" "${base_dir}" \
			"${jq_dep_names[${i}]}" "${jq_dep_values[${i}]}"
		done
	fi
	#修改父pom文件版本号
	fun_version_change "${build_context}" "${base_dir}"
	
	#修改子项目pom文件版本号
	jq_sub_names=$(echo ${json_description} | jq '.modules | .[] | .name' | sed {s/\"//g})
	jq_sub_values=$(echo ${json_description} | jq '.modules | .[] | .value' | sed {s/\"//g})
	if [ ${#jq_sub_names[@]} != 0 ];then
		for i in ${!jq_sub_names[@]};do
			fun_version_change "${build_context}" "${base_dir}" \
			"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
		done
	fi
	
	#编译子项目
	if [ ${#jq_sub_names[@]} != 0 ];then
		for i in ${!jq_sub_names[@]};do
			fun_deploy_nexus "${build_context}" "${base_dir}/${jq_sub_names[${i}]}"
		done
	fi
	
	#修改父pom文件项目依赖
	if [ ${#jq_sub_names[@]} != 0 ];then
		for i in ${!jq_sub_names[@]};do
			fun_dependency_change "${build_context}" "${base_dir}" \
			"${jq_sub_names[${i}]}" "${jq_sub_values[${i}]}"
		done
	fi
	
	#编译父项目
	fun_deploy_nexus "${build_context}" "${base_dir}"
	
	#base_dir进行docker image构建并上传
	if [ ${web_mdoule} == ${project_name} ];then
		base_web="${base_dir}"
	else
		base_web="${base_dir}/${web_mdoule}"
	fi
	fun_push_image ${base_web}
	#删除编译后文件
	rm -rf $(find ./ -name '*\.war'| head -n 1)
	war_path=$(find ./ -name '*\.war'| head -n 1)
	#压缩增量包并上传（scp）到指定服务器备份
	fun_backup_file "${war_path}"
	;;
esac