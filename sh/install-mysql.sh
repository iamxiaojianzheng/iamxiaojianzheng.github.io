#!/bin/bash

##############################################################################

version_list=(
	"mysql5.7@5"
	"mysql8.0@8"
)

## 定义系统判定变量
SYSTEM_DEBIAN="Debian"
SYSTEM_UBUNTU="Ubuntu"
SYSTEM_KALI="Kali"
SYSTEM_REDHAT="RedHat"
SYSTEM_RHEL="Red Hat Enterprise Linux"
SYSTEM_CENTOS="CentOS"
SYSTEM_CENTOS_STREAM="CentOS Stream"
SYSTEM_ROCKY="Rocky"
SYSTEM_ALMALINUX="AlmaLinux"
SYSTEM_FEDORA="Fedora"
SYSTEM_OPENCLOUDOS="OpenCloudOS"
SYSTEM_OPENEULER="openEuler"
SYSTEM_OPENSUSE="openSUSE"
SYSTEM_ARCH="Arch"

## 定义目录和文件
File_LinuxRelease=/etc/os-release
File_RedHatRelease=/etc/redhat-release
File_OpenCloudOSRelease=/etc/opencloudos-release
File_openEulerRelease=/etc/openEuler-release
File_ArchRelease=/etc/arch-release
File_DebianVersion=/etc/debian_version
File_DebianSourceList=/etc/apt/sources.list
File_DebianSourceListBackup=/etc/apt/sources.list.bak
Dir_DebianExtendSource=/etc/apt/sources.list.d
Dir_DebianExtendSourceBackup=/etc/apt/sources.list.d.bak
File_ArchMirrorList=/etc/pacman.d/mirrorlist
File_ArchMirrorListBackup=/etc/pacman.d/mirrorlist.bak
Dir_YumRepos=/etc/yum.repos.d
Dir_YumReposBackup=/etc/yum.repos.d.bak
Dir_openSUSERepos=/etc/zypp/repos.d
Dir_openSUSEReposBackup=/etc/zypp/repos.d.bak

## 定义颜色变量
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'
BOLD='\033[1m'
SUCCESS='[\033[32mOK\033[0m]'
COMPLETE='[\033[32mDONE\033[0m]'
WARN='[\033[33mWARN\033[0m]'
ERROR='[\033[31mERROR\033[0m]'
WORKING='[\033[34m*\033[0m]'

## 报错退出
function Output_Error() {
	[ "$1" ] && echo -e "\n$ERROR $1\n"
	exit 1
}

## 权限判定
function PermissionJudgment() {
	if [ $UID -ne 0 ]; then
		Output_Error "权限不足，请使用 Root 用户运行本脚本"
	fi
}

## 系统判定变量
function EnvJudgment() {

	## 定义系统名称
	SYSTEM_NAME="$(cat $File_LinuxRelease | grep -E "^NAME=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"
	cat $File_LinuxRelease | grep "PRETTY_NAME=" -q
	[ $? -eq 0 ] && SYSTEM_PRETTY_NAME="$(cat $File_LinuxRelease | grep -E "^PRETTY_NAME=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"

	## 定义系统版本号
	SYSTEM_VERSION_NUMBER="$(cat $File_LinuxRelease | grep -E "^VERSION_ID=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"

	## 定义系统ID
	SYSTEM_ID="$(cat $File_LinuxRelease | grep -E "^ID=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"

	## 判定当前系统派系（Debian/RedHat/openEuler/OpenCloudOS/openSUSE）
	if [ -s $File_DebianVersion ]; then
		SYSTEM_FACTIONS="${SYSTEM_DEBIAN}"
	elif [ -s $File_OpenCloudOSRelease ]; then
		# OpenCloudOS 判断优先级需要高于 RedHat，因为8版本基于红帽而9版本不是
		SYSTEM_FACTIONS="${SYSTEM_OPENCLOUDOS}"
	elif [ -s $File_openEulerRelease ]; then
		SYSTEM_FACTIONS="${SYSTEM_OPENEULER}"
	elif [[ "${SYSTEM_NAME}" == *"openSUSE"* ]]; then
		SYSTEM_FACTIONS="${SYSTEM_OPENSUSE}"
	elif [ -f $File_ArchRelease ]; then
		SYSTEM_FACTIONS="${SYSTEM_ARCH}"
	elif [ -s $File_RedHatRelease ]; then
		SYSTEM_FACTIONS="${SYSTEM_REDHAT}"
	else
		Output_Error "无法判断当前运行环境，当前系统不在本脚本的支持范围内"
	fi

	## 判定系统名称、版本、版本号
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		if [ ! -x /usr/bin/lsb_release ]; then
			apt-get install -y lsb-release
			if [ $? -ne 0 ]; then
				Output_Error "lsb-release 软件包安装失败\n        本脚本需要通过 lsb_release 指令判断系统类型，当前可能为精简安装的系统，因为正常情况下系统会自带该软件包，请自行安装后重新执行脚本！"
			fi
		fi
		SYSTEM_JUDGMENT="$(lsb_release -is)"
		SYSTEM_VERSION_CODENAME="${DEBIAN_CODENAME:-"$(lsb_release -cs)"}"
		;;
	"${SYSTEM_REDHAT}")
		SYSTEM_JUDGMENT="$(cat $File_RedHatRelease | awk -F ' ' '{printf$1}')"
		## Red Hat Enterprise Linux
		cat $File_RedHatRelease | grep -q "${SYSTEM_RHEL}"
		[ $? -eq 0 ] && SYSTEM_JUDGMENT="${SYSTEM_RHEL}"
		## CentOS Stream
		cat $File_RedHatRelease | grep -q "${SYSTEM_CENTOS_STREAM}"
		[ $? -eq 0 ] && SYSTEM_JUDGMENT="${SYSTEM_CENTOS_STREAM}"
		;;
	"${SYSTEM_OPENCLOUDOS}")
		SYSTEM_JUDGMENT="${SYSTEM_OPENCLOUDOS}"
		;;
	"${SYSTEM_OPENEULER}")
		SYSTEM_JUDGMENT="${SYSTEM_OPENEULER}"
		;;
	"${SYSTEM_OPENSUSE}")
		SYSTEM_JUDGMENT="${SYSTEM_OPENSUSE}"
		;;
	"${SYSTEM_ARCH}")
		SYSTEM_JUDGMENT="${SYSTEM_ARCH}"
		;;
	esac

	## 判断系统和其版本是否受本脚本支持
	case "${SYSTEM_JUDGMENT}" in
	"${SYSTEM_DEBIAN}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:1}" != [8-9] && "${SYSTEM_VERSION_NUMBER:0:2}" != 1[0-1] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_UBUNTU}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:2}" != 1[4-9] && "${SYSTEM_VERSION_NUMBER:0:2}" != 2[0-3] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_RHEL}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:1}" != [7-9] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_CENTOS}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:1}" != [7-8] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_CENTOS_STREAM}" | "${SYSTEM_ROCKY}" | "${SYSTEM_ALMALINUX}" | "${SYSTEM_OPENCLOUDOS}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:1}" != [8-9] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_FEDORA}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:2}" != 3[6-8] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_OPENEULER}")
		if [[ "${SYSTEM_VERSION_NUMBER:0:2}" != 2[1-3] ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		fi
		;;
	"${SYSTEM_OPENSUSE}")
		if [[ "${SYSTEM_ID}" != "opensuse-leap" && "${SYSTEM_ID}" != "opensuse-tumbleweed" ]]; then
			Output_Error "当前系统版本不在本脚本的支持范围内"
		else
			if [[ "${SYSTEM_ID}" == "opensuse-leap" ]]; then
				if [[ "${SYSTEM_VERSION_NUMBER:0:2}" != 15 ]]; then
					Output_Error "当前系统版本不在本脚本的支持范围内"
				fi
			fi
		fi
		;;
	"${SYSTEM_KALI}" | "${SYSTEM_ARCH}")
		# 理论全部支持
		;;
	*)
		Output_Error "当前系统不在本脚本的支持范围内"
		;;
	esac

	## 判定系统处理器架构
	case "$(uname -m)" in
	x86_64)
		DEVICE_ARCH="x86_64"
		;;
	aarch64)
		DEVICE_ARCH="ARM64"
		;;
	armv7l)
		DEVICE_ARCH="ARMv7"
		;;
	armv6l)
		DEVICE_ARCH="ARMv6"
		;;
	i686)
		DEVICE_ARCH="x86_32"
		;;
	*)
		DEVICE_ARCH="$(uname -m)"
		;;
	esac

	## 定义软件源分支名称
	if [[ -z "${SOURCE_BRANCH}" ]]; then
		## 默认
		SOURCE_BRANCH="$(echo "${SYSTEM_JUDGMENT,,}" | sed "s/ /-/g")"
		## 处理特殊
		case "${SYSTEM_JUDGMENT}" in
		"${SYSTEM_DEBIAN}")
			case ${SYSTEM_VERSION_NUMBER:0:1} in
			8 | 9)
				SOURCE_BRANCH="debian-archive"
				;;
			*)
				SOURCE_BRANCH="debian"
				;;
			esac
			;;
		"${SYSTEM_RHEL}")
			case ${SYSTEM_VERSION_NUMBER:0:1} in
			9)
				SOURCE_BRANCH="rocky"
				;;
			*)
				SOURCE_BRANCH="centos"
				;;
			esac
			;;
		"${SYSTEM_CENTOS}")
			if [[ "${DEVICE_ARCH}" == "x86_64" ]]; then
				SOURCE_BRANCH="centos"
			else
				SOURCE_BRANCH="centos-altarch"
			fi
			;;
		"${SYSTEM_CENTOS_STREAM}")
			case ${SYSTEM_VERSION_NUMBER:0:1} in
			8)
				if [[ "${DEVICE_ARCH}" == "x86_64" ]]; then
					SOURCE_BRANCH="centos"
				else
					SOURCE_BRANCH="centos-altarch"
				fi
				;;
			*)
				SOURCE_BRANCH="centos-stream"
				;;
			esac
			;;
		"${SYSTEM_UBUNTU}")
			if [[ "${DEVICE_ARCH}" == "x86_64" ]] || [[ "${DEVICE_ARCH}" == *i?86* ]]; then
				SOURCE_BRANCH="ubuntu"
			else
				SOURCE_BRANCH="ubuntu-ports"
			fi
			;;
		"${SYSTEM_ARCH}")
			if [[ "${DEVICE_ARCH}" == "x86_64" ]] || [[ "${DEVICE_ARCH}" == *i?86* ]]; then
				SOURCE_BRANCH="archlinux"
			else
				SOURCE_BRANCH="archlinuxarm"
			fi
			;;
		esac
	fi

	## 定义软件源同步/更新文字
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		SYNC_TXT="更新"
		;;
	*)
		SYNC_TXT="同步"
		;;
	esac
}

## 命令选项兼容性判断
function CheckCommandOptions() {
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		if [[ "${SYSTEM_JUDGMENT}" != "${SYSTEM_DEBIAN}" ]]; then
			if [[ "${SOURCE_SECURITY}" == "true" || "${SOURCE_BRANCH_SECURITY}" == "true" ]]; then
				Output_Error "当前系统不支持使用 security 仓库相关命令选项，请确认后重试！"
			fi
		fi
		if [[ "${INSTALL_EPEL}" == "true" || "${ONLY_EPEL}" == "true" ]]; then
			Output_Error "当前系统不支持安装 EPEL 附件软件包故无法使用相关命令选项，请确认后重试！"
		fi
		;;
	"${SYSTEM_REDHAT}")
		if [[ "${SYSTEM_JUDGMENT}" != "${SYSTEM_CENTOS}" && "${SYSTEM_JUDGMENT}" != "${SYSTEM_RHEL}" && "${SYSTEM_JUDGMENT}" != "${SYSTEM_ALMALINUX}" ]]; then
			if [[ "${SOURCE_VAULT}" == "true" || "${SOURCE_BRANCH_VAULT}" == "true" ]]; then
				Output_Error "当前系统不支持使用 vault 仓库相关命令选项，请确认后重试！"
			fi
		fi
		case "${SYSTEM_JUDGMENT}" in
		"${SYSTEM_FEDORA}")
			if [[ "${INSTALL_EPEL}" == "true" || "${ONLY_EPEL}" == "true" ]]; then
				Output_Error "当前系统不支持安装 EPEL 附件软件包故无法使用相关命令选项，请确认后重试！"
			fi
			;;
		esac
		if [[ "${DEBIAN_CODENAME}" ]]; then
			Output_Error "当前系统不支持使用指定版本名称命令选项，请确认后重试！"
		fi
		;;
	"${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENSUSE}" | "${SYSTEM_ARCH}")
		if [[ "${SOURCE_SECURITY}" == "true" || "${SOURCE_BRANCH_SECURITY}" == "true" ]]; then
			Output_Error "当前系统不支持使用 security 仓库相关命令选项，请确认后重试！"
		fi
		if [[ "${SOURCE_VAULT}" == "true" || "${SOURCE_BRANCH_VAULT}" == "true" ]]; then
			Output_Error "当前系统不支持安装 EPEL 附件软件包故无法使用相关命令选项，请确认后重试！"
		fi
		if [[ "${INSTALL_EPEL}" == "true" || "${ONLY_EPEL}" == "true" ]]; then
			Output_Error "当前系统不支持安装 EPEL 附件软件包故无法使用相关命令选项，请确认后重试！"
		fi
		if [[ "${DEBIAN_CODENAME}" ]]; then
			Output_Error "当前系统不支持使用指定版本名称命令选项，请确认后重试！"
		fi
		;;
	esac
	if [[ "${USE_ABROAD_SOURCE}" == "true" && "${USE_EDU_SOURCE}" == "true" ]]; then
		Output_Error "两种模式不可同时使用！"
	fi
}

function StartTitle() {
	[ -z "${MYSQL_VERSION}" ] && clear
	echo -e ' +-----------------------------------+'
	echo -e " | \033[0;1;35;95m⡇\033[0m  \033[0;1;33;93m⠄\033[0m \033[0;1;32;92m⣀⡀\033[0m \033[0;1;36;96m⡀\033[0;1;34;94m⢀\033[0m \033[0;1;35;95m⡀⢀\033[0m \033[0;1;31;91m⡷\033[0;1;33;93m⢾\033[0m \033[0;1;32;92m⠄\033[0m \033[0;1;36;96m⡀⣀\033[0m \033[0;1;34;94m⡀\033[0;1;35;95m⣀\033[0m \033[0;1;31;91m⢀⡀\033[0m \033[0;1;33;93m⡀\033[0;1;32;92m⣀\033[0m \033[0;1;36;96m⢀⣀\033[0m |"
	echo -e " | \033[0;1;31;91m⠧\033[0;1;33;93m⠤\033[0m \033[0;1;32;92m⠇\033[0m \033[0;1;36;96m⠇⠸\033[0m \033[0;1;34;94m⠣\033[0;1;35;95m⠼\033[0m \033[0;1;31;91m⠜⠣\033[0m \033[0;1;33;93m⠇\033[0;1;32;92m⠸\033[0m \033[0;1;36;96m⠇\033[0m \033[0;1;34;94m⠏\033[0m  \033[0;1;35;95m⠏\033[0m  \033[0;1;33;93m⠣⠜\033[0m \033[0;1;32;92m⠏\033[0m  \033[0;1;34;94m⠭⠕\033[0m |"
	echo -e ' +-----------------------------------+'
	echo -e ' 欢迎使用 GNU/Linux 一键安装MySQL脚本'
}

## 打印软件源列表
function PrintMirrorsList() {
    local tmp_mirror_name tmp_mirror_version arr_num default_mirror_name_length tmp_mirror_name_length tmp_spaces_nums a i j
    ## 计算字符串长度
    function StringLength() {
        local text=$1
        echo "${#text}"
    }
    echo -e ''

    local list_arr=()
    local list_arr_sum="$(eval echo \${#$1[@]})"
    for ((a = 0; a < $list_arr_sum; a++)); do
        list_arr[$a]="$(eval echo \${$1[a]})"
    done
    if [ -x /usr/bin/printf ]; then
        for ((i = 0; i < ${#list_arr[@]}; i++)); do
            tmp_mirror_name=$(echo "${list_arr[i]}" | awk -F '@' '{print$1}') # 软件源名称
            arr_num=$((i + 1))
            default_mirror_name_length=${2:-"30"} # 默认软件源名称打印长度
            ## 补齐长度差异（中文的引号在等宽字体中占1格而非2格）
            [[ $(echo "${tmp_mirror_name}" | grep -c "“") -gt 0 ]] && let default_mirror_name_length+=$(echo "${tmp_mirror_name}" | grep -c "“")
            [[ $(echo "${tmp_mirror_name}" | grep -c "”") -gt 0 ]] && let default_mirror_name_length+=$(echo "${tmp_mirror_name}" | grep -c "”")
            [[ $(echo "${tmp_mirror_name}" | grep -c "‘") -gt 0 ]] && let default_mirror_name_length+=$(echo "${tmp_mirror_name}" | grep -c "‘")
            [[ $(echo "${tmp_mirror_name}" | grep -c "’") -gt 0 ]] && let default_mirror_name_length+=$(echo "${tmp_mirror_name}" | grep -c "’")
            # 非一般字符长度
            tmp_mirror_name_length=$(StringLength $(echo "${tmp_mirror_name}" | sed "s| ||g" | sed "s|[0-9a-zA-Z\.\=\:\_\(\)\'\"-\/\!·]||g;"))
            ## 填充空格
            tmp_spaces_nums=$(($(($default_mirror_name_length - ${tmp_mirror_name_length} - $(StringLength "${tmp_mirror_name}"))) / 2))
            for ((j = 1; j <= ${tmp_spaces_nums}; j++)); do
                tmp_mirror_name="${tmp_mirror_name} "
            done
            printf " ❖  %-$(($default_mirror_name_length + ${tmp_mirror_name_length}))s %4s\n" "${tmp_mirror_name}" "$arr_num)"
        done
    else
        for ((i = 0; i < ${#list_arr[@]}; i++)); do
            tmp_mirror_name=$(echo "${list_arr[i]}" | awk -F '@' '{print$1}')    # 软件源名称
            tmp_mirror_version=$(echo "${list_arr[i]}" | awk -F '@' '{print$2}') # 软件源地址
            arr_num=$((i + 1))
            echo -e " ❖  $arr_num. ${tmp_mirror_version} | ${tmp_mirror_name}"
        done
    fi
}

## 安装MySQL
function InstallMySQL() {
	
	local list_name="version_list"
	PrintMirrorsList "${list_name}" 10

	local CHOICE=$(echo -e "\n${BOLD}└─ 请选择并输入你想使用的MySQL版本 [ 1-$(eval echo \${#$list_name[@]}) ]：${PLAIN}")
	while true; do
		read -p "${CHOICE}" INPUT
		case "${INPUT}" in
		[1-2])
			local tmp_source="$(eval echo \${$list_name[$(($INPUT - 1))]})"
			if [[ -z "${tmp_source}" ]]; then
				echo -e "\n$WARN 请输入有效的数字序号！"
			else
				MYSQL_VERSION="$(eval echo \${$list_name[$(($INPUT - 1))]} | awk -F '@' '{print$2}')"
				#echo "${MYSQL_VERSION}"
				#exit
				break
			fi
			;;
		*)
			echo -e "\n$WARN 请输入数字序号以选择你想使用的MySQL版本！"
			;;
		esac
	done

	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		InstallMySQLForDebian
		;;
	"${SYSTEM_REDHAT}")
        local CHOICE=$(echo -e "\n${BOLD}└─ 请输入MySQL密码? [admin] ${PLAIN}")
        read -p "${CHOICE}" MYSQL_PASSWORD
        [[ -z "${MYSQL_PASSWORD}" ]] && MYSQL_PASSWORD=admin
        
        
        local CHOICE=$(echo -e "\n${BOLD}└─ 请输入MySQL数据存放目录? [/var/lib/mysql] ${PLAIN}")
        read -p "${CHOICE}" MYSQL_DATA_DIR
        [[ -z "${MYSQL_DATA_DIR}" ]] && MYSQL_DATA_DIR=/var/lib/mysql
        
		InstallMySQLRedHat
		;;
	"${SYSTEM_OPENCLOUDOS}")
		InstallMySQLOpenCloudOS
		;;
	"${SYSTEM_OPENEULER}")
		InstallMySQLopenEuler
		;;
	"${SYSTEM_OPENSUSE}")
		InstallMySQLopenSUSE
		;;
	"${SYSTEM_ARCH}")
		InstallMySQLArch
		;;
	esac
}

## Redhat 安装MySQL
function InstallMySQLRedHat() {
	case "${SYSTEM_VERSION_NUMBER}" in
	6)
		rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el6-7.noarch.rpm
		;;
	7)
		rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el7-7.noarch.rpm
		;;
	8)
		rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el8-5.noarch.rpm
		;;
	9)
		rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
		;;
	esac

    yum install -y yum-utils
	case "${MYSQL_VERSION}" in
	5)
		yum-config-manager --disable mysql80-community
		yum-config-manager --enable mysql57-community
		;;
	8)
		yum-config-manager --disable mysql57-community
		yum-config-manager --enable mysql80-community
		;;
	esac
    
	yum install -y mysql-community-server
    
    sed -i "s#datadir=/var/lib/mysql#datadir=$MYSQL_DATA_DIR#" /etc/my.cnf
    
    # 启动MySQL，获取临时密码
	systemctl start mysqld
	INIT_PW=$(grep "temporary password" /var/log/mysqld.log | awk -F' ' 'END{print $NF}')
    
    # 修改密码
    case "${MYSQL_VERSION}" in
	5)
        mysql --connect-expired-password -uroot -p$INIT_PW mysql -N -e "set global validate_password_policy=0;set global validate_password_length=1;alter user 'root'@'localhost' identified by '$MYSQL_PASSWORD';flush privileges;set global validate_password_policy=default;set global validate_password_length=default;flush privileges;"
        mysql -uroot -p$MYSQL_PASSWORD -N -e "SELECT 1;"
		;;
	8)
        echo '由于MySQL8.0 无法通过外部命令修改初始化密码，请您执行 mysql -uroot -p$INIT_PW 自行修改'
        echo 
        echo 'set global validate_password.policy = LOW;'
        echo 'set global validate_password.length = 1;'
        echo "alter user 'root'@'localhost' identified with mysql_native_password BY '$MYSQL_PASSWORD' password expire never;"
        echo 'set global validate_password.policy = default;'
        echo 'set global validate_password.length = default;'
        echo 'flush privileges;'
        #mysql --connect-expired-password -uroot -p$INIT_PW mysql -N -e "set global validate_password.policy = LOW; set global validate_password.length = 1; alter user 'root'@'localhost' identified with mysql_native_password BY '$MYSQL_PASSWORD' password expire never; flush privileges; set global validate_password.policy = default; set global validate_password.length = default; flush privileges; "
		;;
	esac
    
}

## Ubuntu Debian 安装MySQL
function InstallMySQLForDebian() {
    apt install -y gnupg debconf-utils
    apt-key del 5072E1F5 > /dev/null
    apt-key del 3A79BD29 > /dev/null
    apt update
    apt purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
    apt autoremove -y
    apt autoclean -y
	case "${MYSQL_VERSION}" in
	5)
		apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5072E1F5
        debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-server string mysql-5.7"
        #debconf-set-selections <<< "mysql-community-server mysql-community-server/root_password password $MYSQL_PASSWORD"
        #debconf-set-selections <<< "mysql-community-server mysql-community-server/root_password_again password $MYSQL_PASSWORD"
		;;
	8)
		apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3A79BD29
        debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-server string mysql-8.0"
        #debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password $MYSQL_PASSWORD"
        #debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password $MYSQL_PASSWORD"
        #debconf-set-selections <<< "mysql-community-server mysql-community-server/data-dir string $MYSQL_DATA_DIR"
		;;
	esac

    # 查看配置 debconf-show mysql-server
    debconf-set-selections <<< "mysql-apt-config mysql-apt-config/repo-distro string debian"
    debconf-set-selections <<< "mysql-apt-config mysql-apt-config/repo-codename string buster"
    debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-product select true"
    # 启用历史版本
    debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-preview select true"
    
    # 安装MySQL源
    if [ $(dpkg -s mysql-apt-config | grep "install ok installed" | wc -l) == "0" ]; then
        wget https://dev.mysql.com/get/mysql-apt-config_0.8.25-1_all.deb
        dpkg -i mysql-apt-config_0.8.25-1_all.deb
    else
        if ! grep -q "mysql-${MYSQL_VERSION}" /etc/apt/sources.list.d/mysql.list ; then
            # 重置配置 dpkg-reconfigure mysql-apt-config
            dpkg-reconfigure mysql-apt-config
            if ! grep -q "mysql-${MYSQL_VERSION}" /etc/apt/sources.list.d/mysql.list ; then
                echo "dpkg-reconfigure mysql-apt-config 配置失败"
                exit
            fi
        fi
    fi
    
    # 静默安装mysql-server
    #export DEBIAN_FRONTEND="noninteractive"
    
	apt update
    rm -rf /etc/mysql/ /var/lib/mysql
	apt install -y mysql-common  mysql-server
}

## 运行结束
function RunEnd() {
	echo -e "\n$COMPLETE 脚本执行结束"
	echo -e "\n\033[1;34mPowered by xiaojianzheng.cn\033[0m\n"
}

## 处理命令选项
function CommandOptions() {
	## 命令帮助
	function Output_Help_Info() {
		echo -e "
命令选项(参数名/含义/参数值)：

  --abroad                 使用海外软件源                                    无
  --codename               指定 Debian 系操作系统的版本名称                  版本名

  "
	}

	## 判断参数
	while [ $# -gt 0 ]; do
		case "$1" in
		## 指定 Debian 系操作系统的版本名称
		--codename)
			if [ "$2" ]; then
				DEBIAN_CODENAME="$2"
				shift
			else
				Output_Error "检测到 ${BLUE}$1${PLAIN} 为无效参数，请在该参数后指定版本名称！"
			fi
			;;
		## 命令帮助
		--help)
			Output_Help_Info
			exit
			;;
		*)
			Output_Error "检测到 ${BLUE}$1${PLAIN} 为无效参数，请确认后重新输入！"
			;;
		esac
		shift
	done
	## 给部分命令选项赋予默认值
	ONLY_EPEL="${ONLY_EPEL:-"false"}"
	BACKUP="${BACKUP:-"true"}"
	IGNORE_BACKUP_TIPS="${IGNORE_BACKUP_TIPS:-"false"}"
	PRINT_DIFF="${PRINT_DIFF:-"false"}"
}

## 组合函数
function Combin_Function() {
	PermissionJudgment
	EnvJudgment
	StartTitle
	InstallMySQL
	RunEnd
}

CommandOptions "$@"
Combin_Function
