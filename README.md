# build_dependency_project

读取path.txt文件中git地址并下载
循环切换release分支代码进行maven编译发布到nexus
解决项目构建依赖

# 如何比较目标项目的2个版本
通过 branch	-> master
tag	-> master
branch != tag -> pacth.zip
pacth.zip -> master -> compile -> *.class -> project_name/ ->project_name.zip

sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo

##运行shell为bash-file文件夹下build-all-2.2.sh
