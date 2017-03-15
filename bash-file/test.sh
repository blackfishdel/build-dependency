#!/bin/bash -e

json_file_path="/home/delxie/Documents/git-repository/build-dependency/bash-file/description.json"

jq_names=$(cat ${json_file_path} | jq '.modules | .[] | .name' | sed {s/\"//g})
jq_values=$(cat ${json_file_path} | jq '.modules | .[] | .value' | sed {s/\"//g})
echo ${jq_names[@]}
#cat ${json_file_path} | jq '.dependencies | recurse(.modules[])'
#echo ${#list[@]}
#echo ${list[2]} | jq 'fromjson | .modules'

#cat ${json_file_path} | jq -r 'recurse(.dependencies[]) | tostring'
