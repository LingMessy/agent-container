#!/bin/bash

# 检查是否以 source 方式运行（提示用户）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "提示: 请使用 'source unset-proxy.sh' 或 '. unset-proxy.sh' 来让环境变量在当前终端生效！"
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
