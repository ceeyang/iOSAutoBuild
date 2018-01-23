#!/bin/sh
## Code by yangxichuan
## 2018-01-18 11:34:32
##
## iOS 自动打包脚本
##
## 已经实现的功能如下:
## 1. 自动打包 xrchive 文件;
## 2. 自动到处 ipa 文件;
## 3. 自动上传到七牛云;
## 4. 自动发送邮件到测试人员邮箱;
##
## 脚本执行准备:
## 0. 执行脚本前请确认您的项目能通过 xcode 直接运行到手机上;
## 1. 更改下文第行 Enterprise 证书配置信息;
## 2. 更改根目录下 DevelopmentExportOptions.plist 里的相关信息;
## 3. 如需上传七牛云,需要安装七牛云上传工具: qshell, 详情请见可选工具;
## 4. 如需上传七牛云,请确定七牛云版本号;
## 5. 如需版本升级,请在根目录文件中创建 升级所需的 plist 文件;  文件名类型为 项目前缀 + 版本号. plist  例如: zxy_saas_lpht_1.0.0.plist
##
## 脚本执行命令:
## chmod +x autoBuild.sh
## ./autoBuild.sh
##
##
## 可选工具:
## qshell: 七牛云上传工具,详情请移步: [https://github.com/qiniu/qshell]


echo "START: ~~~~~~~~~~~~~~~~开始执行脚本~~~~~~~~~~~~~~~~"

####################################################################
###################工程信息以及最下面的七牛云信息########################

##----------------- 发版需要编辑的地方   ----------------------------##
# 七牛云改项目前缀

# 正式环境前缀
# QINIU_DIRECTORY_PRDFIX="zxy_saas_yqdz_"

# 测试环境前缀
QINIU_DIRECTORY_PRDFIX="zxy_saas_yqdz_uat_"

# 项目下载地址: 用于发送邮件给测试人员打开下载
PROJECT_DOWNLOAD_URL="http://vwtrainingtest.faw-vw.com/app/qr.png"

##----------------- 默认配置,每个项目配置一次就好   -------------------##
#工程名
PROJECTNAME="your_project_name"

#需要编译的 targetName
TARGET_NAME="your_target_name"

# ADHOC 证书名 & 描述文件
ADHOCCODE_SIGN_IDENTITY="xxxxx"
ADHOCPROVISIONING_PROFILE_NAME="xxxx"

# AppStore 证书名 & 描述文件
APPSTORECODE_SIGN_IDENTITY="xxxxx"
APPSTOREADHOCPROVISIONING_PROFILE_NAME="xxxx"

# Enterprise 证书名 & 描述文件
DEVELOPMENT_CODE_SIGN_IDENTITY="iPhone Developer: your_identity (xxxxx)"
DEVELOPMENT_PROVISIONING_PROFILE_NAME="your_company_identity"

# 是否是工作空间,Default is true
ISWORKSPACE=true

#编译模式 工程默认有 Debug Release
CONFIGURATION_TARGET=Debug

# 编译根目录,可以设置到其他目录
ARCHIVE_ROOT_PATH=~/Desktop/work/project/YQDZ


# 七牛云配置信息 账号名: zhixueyun@zhixueyun.com,  如需更改
QINIU_ACCESS_KEY="your_qiniu_account_ak"
QINIU_SECRET_KEY="your_qiniu_account_sk"


####################################################################
####################################################################

#证书名
CODE_SIGN_IDENTITY=${DEVELOPMENT_CODE_SIGN_IDENTITY}
#描述文件
PROVISIONING_PROFILE_NAME=${DEVELOPMENT_PROVISIONING_PROFILE_NAME}

# 开始时间
beginTime=`date +%s`
DATE=`date '+%Y-%m-%d-%T'`

#编译路径
BUILDPATH=${ARCHIVE_ROOT_PATH}/${TARGET_NAME}_${DATE}
#archivePath
ARCHIVEPATH=${BUILDPATH}/${TARGET_NAME}.xcarchive
#输出的ipa目录
IPA_PATH=${BUILDPATH}


#导出ipa 所需plist
ADHOCExportOptionsPlist=./ADHOCExportOptionsPlist.plist
AppStoreExportOptionsPlist=./AppStoreExportOptionsPlist.plist
DevelopmentExportOptionsPlist=./DevelopmentExportOptions.Plist

ExportOptionsPlist=${ADHOCExportOptionsPlist}


# 是否上传七牛云
UPLOADPGYER=false
echo ""
echo "~~~~~~~~~~~~~~~~并选择打包方式~~~~~~~~~~~~~~~~"
echo "		1 Enterprise (默认)"
echo "		2 Ad-hoc"
echo "		3 AppStore "

# 读取用户输入并存到变量里
read parameter
sleep 0.5
method="$parameter"

# 判读用户是否有输入
if [ -n "$method" ]
then
	if [ "$method" = "1" ]
	then
		CODE_SIGN_IDENTITY=${DEVELOPMENT_CODE_SIGN_IDENTITY}
		PROVISIONING_PROFILE_NAME=${DEVELOPMENT_PROVISIONING_PROFILE_NAME}
		ExportOptionsPlist=${DevelopmentExportOptionsPlist}
	elif [ "$method" = "2" ]
	then
		CODE_SIGN_IDENTITY=${ADHOCCODE_SIGN_IDENTITY}
    	PROVISIONING_PROFILE_NAME=${ADHOCPROVISIONING_PROFILE_NAME}
		ExportOptionsPlist=${ADHOCExportOptionsPlist}
	elif [ "$method" = "3" ]
	then
		CODE_SIGN_IDENTITY=${APPSTORECODE_SIGN_IDENTITY}
    	PROVISIONING_PROFILE_NAME=${APPSTOREADHOCPROVISIONING_PROFILE_NAME}
		ExportOptionsPlist=${AppStoreExportOptionsPlist}
		CONFIGURATION_TARGET=Release
	else
	echo "参数无效...."
	exit 1
	fi
else
	echo "1 Enterprise (默认)"
	ExportOptionsPlist=${DevelopmentExportOptionsPlist}
fi

echo ""
echo "~~~~~~~~~~~~~~~~是否上传七牛云~~~~~~~~~~~~~~~~"
echo "		1 上传 (默认)"
echo "		2 不上传 "
read para
sleep 0.5

if [ -n "$para" ]
then
	if [ "$para" = "1" ]
	then
	UPLOADPGYER=true
	elif [ "$para" = "2" ]
	then
	UPLOADPGYER=false
	else
	echo "参数无效...."
	exit 1
	fi
else
	echo "1 上传 (默认)"
	UPLOADPGYER=true
fi


echo ""
echo "~~~~~~~~~~~~~~~~是否需要上传 plist 文件~~~~~~~~~~~~~~~~"
echo "		1 不上传 (默认)"
echo "		2 上传   (需要将 plist 文件放到项目根目录下)"
read plistName
sleep 0.2

NEED_UPDATE_PLIST=flase
SHOW_PLIST_NOT_EXIST_ERROR=flase

# 得到IPA中Info.plist的路径
appInfoPlistPath="`pwd`/${TARGET_NAME}/Info.plist"
# 获取版本号
bundleShortVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" ${appInfoPlistPath})
# 获取编译的 build 版本号
bundleVersion=$(/usr/libexec/PlistBuddy -c "print CFBundleVersion" ${appInfoPlistPath})

QINIU_PLIST_NAME=${QINIU_DIRECTORY_PRDFIX}${bundleShortVersion}.plist
# 通过 readlink 获取绝对路径，再取出目录
QINIU_PLIST_FILE_PATH="`pwd`/${QINIU_PLIST_NAME}"

if [[ -n "$plistName" ]]; then
	if [[ "$plistName" = "2" ]]; then
		echo "正在检查 plist 文件: ${QINIU_PLIST_FILE_PATH}"
		if [[ -f "$QINIU_PLIST_FILE_PATH" ]]; then
			echo "${QINIU_PLIST_FILE_PATH} 文件存在"
			NEED_UPDATE_PLIST=true
		else
			SHOW_PLIST_NOT_EXIST_ERROR=true
		fi
	fi
else
	echo "1 不上传 (默认)"
	NEED_UPDATE_PLIST=flase
fi



echo ""
echo "~~~~~~~~~~~~~~~~开始编译~~~~~~~~~~~~~~~~~~~"

if [ $ISWORKSPACE = true ]
then
# 清理 避免出现一些莫名的错误
xcodebuild clean -workspace ${PROJECTNAME}.xcworkspace \
-configuration \
${CONFIGURATION} -alltargets

#开始构建
xcodebuild archive -workspace ${PROJECTNAME}.xcworkspace \
-scheme ${TARGET_NAME} \
-archivePath ${ARCHIVEPATH} \
-configuration ${CONFIGURATION_TARGET} \
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
PROVISIONING_PROFILE="${PROVISIONING_PROFILE_NAME}"

else
# 清理 避免出现一些莫名的错误
xcodebuild clean -project ${PROJECTNAME}.xcodeproj \
-configuration ${CONFIGURATION} -alltargets

#开始构建
xcodebuild archive -project ${PROJECTNAME}.xcodeproj \
-scheme ${TARGET_NAME} \
-archivePath ${ARCHIVEPATH} \
-configuration ${CONFIGURATION_TARGET} \
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
PROVISIONING_PROFILE="${PROVISIONING_PROFILE_NAME}"
fi

echo ""
echo "~~~~~~~~~~~~~~~~检查是否构建成功~~~~~~~~~~~~~~~~~~~"
# xcarchive 实际是一个文件夹不是一个文件所以使用 -d 判断
if [ -d "$ARCHIVEPATH" ]
then
	echo ''
	echo '///--------------------------------///'
	echo '///---ARCHIEVE SUCCESS: 构建成功----///'
	echo '///--------------------------------///'
else
	echo ''
	echo '///--------------------------------///'
	echo '///----ARCHIEVE FAILED: 构建失败----///'
	echo '///--------------------------------///'
rm -rf $BUILDPATH
exit 1
fi
endTime=`date +%s`
ArchiveTime="构建时间$[ endTime - beginTime ]秒"

echo ""
echo "~~~~~~~~~~~~~~~~导出ipa~~~~~~~~~~~~~~~~~~~"

beginTime=`date +%s`

xcodebuild -exportArchive \
-archivePath ${ARCHIVEPATH} \
-exportOptionsPlist ${ExportOptionsPlist} \
-exportPath ${IPA_PATH}

echo ""
echo "~~~~~~~~~~~~~~~~检查是否成功导出ipa~~~~~~~~~~~~~~~~~~~"
IPA_PATH=${IPA_PATH}/${TARGET_NAME}.ipa
if [ -f "$IPA_PATH" ]
then
	echo ''
	echo '///--------------------------------///'
	echo '///-EXPORT IPA SUCCESS: 导出ipa成功-///'
	echo '///--------------------------------///'
	open $BUILDPATH
else
	echo ''
	echo '///--------------------------------///'
	echo '///-EXPORT IPA FAILED:  导出ipa失败-///'
	echo '///--------------------------------///'
	# 结束时间
	endTime=`date +%s`
	echo "$ArchiveTime"
	echo "导出ipa时间$[ endTime - beginTime ]秒"
	exit 1
fi

endTime=`date +%s`
ExportTime="导出ipa时间$[ endTime - beginTime ]秒"


# 上传七牛云
UPLOAD_QINIU_SUCCESS=false
if [ $UPLOADPGYER = true ]
then
	echo "\n~~~~~~~~~~~~~~~~上传ipa到七牛云~~~~~~~~~~~~~~~~~~~"

	# 更改 ipa 名称;  规则: 前缀 + 版本号 eg: zxy_saas_xxx_1.0.0.ipa
	IPA_NAME=${QINIU_DIRECTORY_PRDFIX}${bundleShortVersion}.ipa
	mv ${IPA_PATH} ${BUILDPATH}/${IPA_NAME}
	IPA_PATH=${BUILDPATH}/${IPA_NAME}
	if [[ -f "$IPA_PATH" ]]; then
		echo "\nipa 更名成功,更新后地址为: ${IPA_PATH}"
	else
		echo "ERROR: ipa 更名失败!"
		exit 1
	fi

	# 判断 qshell 工具是否可用
	if hash qshell 2>/dev/null;
	then
        echo "\n当前环境中存在qshell工具"

		# 设置账户信息
		qshell account ${QINIU_ACCESS_KEY} ${QINIU_SECRET_KEY}

		# 上传 ipa 文件
		echo ""
		echo '///--------------------------'
		echo '/// ipa 上传中。。。。。。。。。。。'
		echo '///--------------------------'
		QINI_BUILD_IPA_PATH=${BUILDPATH}/${IPA_NAME}
		qshell rput zxyapp ${IPA_NAME} ${IPA_PATH} true

		# 刷新 ipa 下载地址
		echo '\n/// 正在刷新预取。。。。。。。。。。。'
		CDN_DOWNLOAD_PATH=http://zxyapp.qiniudn.com/${IPA_NAME}
		CDN_TEXT_PATH=${BUILDPATH}/CDN.text
		echo ""
		echo "${CDN_DOWNLOAD_PATH}"|tee ${CDN_TEXT_PATH}
		qshell cdnprefetch ${CDN_TEXT_PATH}
        rm ${CDN_TEXT_PATH}

		# 上传 plist 文件
		if [[ $NEED_UPDATE_PLIST = true ]]; then
			echo '\n/// 正在上传 plist 文件。。。。。。。。。。。'
			qshell rput zxyapp ${QINIU_PLIST_NAME} ${QINIU_PLIST_FILE_PATH} true
		fi

		if [ $? = 0 ]
		then
			UPLOAD_QINIU_SUCCESS=true
			echo "\n~~~~~~~~~~~~~~~~上传七牛云成功~~~~~~~~~~~~~~~~~~~"
		else
			echo "\n~~~~~~~~~~~~~~~~上传七牛云失败~~~~~~~~~~~~~~~~~~~"
		fi
	else
		echo "\nERROR: 当前目录下不存在 Qshell 工具, 请到七牛云官网下载 qshell 工具到本目录下,或者安装到您的系统中,详情请点击:https://github.com/qiniu/qshell"
	fi
fi

if [[ $SHOW_PLIST_NOT_EXIST_ERROR = true ]]; then
	echo "\n${QINIU_PLIST_NAME} 文件不存在,请手动上传该文件"
else
	echo ""
	echo '///--------------------------'
	echo '/// 邮件发送中。。。。。。。。。。。'
	echo '///--------------------------'

    # 上传到七牛云成功之后 发送邮件给测试人员
    python sendEmail.py "测试版本 iOS ${bundleShortVersion}(${bundleVersion})上传成功" "赶紧下载体验吧! ${PROJECT_DOWNLOAD_URL}"

fi

echo ""
echo "/// ---  Build Info --- ///"
echo "开始执行脚本时间: ${DATE}"
echo "编译模式: ${CONFIGURATION_TARGET}"
echo "导出ipa配置: ${ExportOptionsPlist}"
echo "打包文件路径: ${ARCHIVEPATH}"
echo "导出ipa路径: ${IPA_PATH}"

echo ""
echo "/// ---  App Info --- ///"
echo "App 版本号: ${bundleShortVersion}"
echo "Build 版本号: ${bundleVersion}"
echo "Ipa 文件名: ${IPA_NAME}"

echo ""
echo "$ArchiveTime"
echo "$ExportTime"
exit 0
