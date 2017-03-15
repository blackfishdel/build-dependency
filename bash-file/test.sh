#!/bin/bash -e
json_description=$(cat "/home/delxie/Documents/git-repository/bssp/description.json")

#循环遍历
jq_dependencies=($(echo ${json_description} | jq "recurse(.dependencies[]) | .dependencies | tostring"))
for ((i=${#jq_dependencies[@]};i>0;i--));do
	jq_i=`expr i-1`
	jq_dependency=$(echo ${jq_dependencies[${jq_i}]} | jq "fromjson")
	jq_dependency_length=$(echo ${jq_dependency} | jq ".[] | length")
	echo ${jq_dependency}
done
