# 自动打包配置说明

ios自动打包脚本
## 目录说明:
+ sendEmail.py： 自动发送邮件的脚本;
+ DevelopmentExportOptions.plist： 导出 ipa 时需要的配置信息, 如不知道怎么配置,使用手动导出 ipa 后,会在 ipa 所在目录生成一个该文件,然后拷贝该文件到根目录更名即可;
+ autoBuild.sh： 自动构建脚本;

## 其他说明:
+ 本目录目前只适用于企业账号打包的方式,其他方式请参照脚本自行更改;
+ 生成的的 ipa 文件会更名为: zxy_saas_xxx_1.0.0.plist, 其中版本号自动获取 APP 版本号;
+ 上传方式目前只支持 七牛云; 后续会完善;



## 已经实现的功能如下:
1. 自动打包 xcarchive 文件;
2. 自动导出 ipa 文件;
3. 自动上传到七牛云;
4. 自动发送邮件到测试人员邮箱;


## 脚本执行准备:
0. 执行脚本前请确认您的项目能通过 xcode 直接运行到手机上;
1. 更改根目录下 autoBuild.sh 里的 Enterprise 证书配置信息;
2. 更改根目录下 DevelopmentExportOptions.plist 里的相关信息;
3. 如需上传七牛云,需要安装七牛云上传工具: qshell, 详情请见:[https://github.com/qiniu/qshell][1] ;
4. 上传的版本号会从 项目里面获取;
5. 如需版本升级,请在根目录文件中创建 升级所需的 plist 文件;  文件名类型为 项目前缀 + 版本号. plist  例如: zxy_saas_lpht_1.0.0.plist;
6. 更多信息请阅读 autoBuild.sh 里需要配置的地方;
7. 如需发送邮件到测试人员,请修改根目录下 sendEmail.py 里的 **receiver**字段, 多个邮箱用分号隔开;

## 脚本执行命令:
```
chmod +x autoBuild.sh
./autoBuild.sh
```


---
code by yangxichuan
2018-01-18 16:50:47


[1]:https://github.com/qiniu/qshell
