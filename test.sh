pathLine="bacs;1.1.1-release;;http://192.168.1.215:9090/r/joinwe/bacs.git;deploy"
if [[ ${pathLine} == "end" && $(echo ${pathLine} | grep "#") != "" ]]
then
	continue
fi