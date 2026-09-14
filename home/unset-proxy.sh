#!/bin/bash

# POSIX sh 没有通用的 source 检测接口；按文件名识别常规直接执行。
# 脚本重命名后需同步此处文件名；调用方同名时可能误报。
if [ "${0##*/}" = "unset-proxy.sh" ]; then
    echo "提示: 请使用 '. ./unset-proxy.sh'（sh/Bash）或 'source ./unset-proxy.sh'（Bash） 来让环境变量在当前终端生效！"
    echo ""
fi

# 清除所有常见的小写和大写代理环境变量
unset http_proxy
unset https_proxy
unset all_proxy
unset no_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset ALL_PROXY
unset NO_PROXY

# 打印清除成功的提示
echo "==================== 代理已成功清除 ===================="
echo "所有 HTTP/HTTPS/SOCKS 代理环境变量已被注销。"
echo "========================================================"
