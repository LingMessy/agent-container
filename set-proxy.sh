#!/bin/bash

# 检查是否以 source 方式运行（提示用户）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "提示: 请使用 'source set-proxy.sh' 或 '. set-proxy.sh' 来让环境变量在当前终端生效！"
    echo ""
fi

# 配置参数（支持通过环境变量覆盖，方便灵活定制）
PROXY_IP="${PROXY_IP:-192.168.3.70}"
PROXY_PORT="${PROXY_PORT:-7890}"
PROXY_USER="${PROXY_USER:-}"       # 如果需要用户名，可在此填写或通过环境变量传入
PROXY_PASS="${PROXY_PASS:-}"       # 如果需要密码，可在此填写

# 拼接代理 URL（支持认证信息）
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    PROXY_AUTH="$PROXY_USER:$PROXY_PASS@"
else
    PROXY_AUTH=""
fi

export http_proxy="http://${PROXY_AUTH}${PROXY_IP}:${PROXY_PORT}"
export https_proxy="http://${PROXY_AUTH}${PROXY_IP}:${PROXY_PORT}"
# 使用 socks5h:// 代替 socks5://，确保 DNS 解析也通过代理，防止 DNS 污染
export all_proxy="socks5h://${PROXY_AUTH}${PROXY_IP}:${PROXY_PORT}"

# 优化后的 no_proxy：涵盖了本地、常见私有网段以及常见 K8s 内部域名
export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.svc,.cluster.local"

# 同时设置大写形式（部分传统软件或 Java 程序需要大写环境变量）
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy"
export NO_PROXY="$no_proxy"

# 打印当前生效的代理配置
echo "==================== 代理已成功配置 ===================="
echo "HTTP Proxy  : $http_proxy"
echo "HTTPS Proxy : $https_proxy"
echo "SOCKS Proxy : $all_proxy"
echo "No Proxy    : $no_proxy"
echo "--------------------------------------------------------"
echo "💡 提示: 你可以通过环境变量临时修改配置，例如："
echo "   PROXY_IP=192.168.1.100 PROXY_PORT=1080 source set-proxy.sh"
echo "========================================================"
