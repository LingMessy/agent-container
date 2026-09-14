# Debian Trixie 精简基础镜像
FROM docker.io/library/debian:trixie-slim

# OCI 标准元数据
LABEL org.opencontainers.image.title="AI Agent Execution Environment" \
      org.opencontainers.image.description="Container environment tailored for AI coding agent workloads" \
      org.opencontainers.image.vendor="Local Engine" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    FNM_DIR="/home/agent/.local/share/fnm" \
    PNPM_HOME="/home/agent/.local/share/pnpm"

# 直接执行容器命令时也能使用默认 Node.js 和 pnpm 全局命令
ENV PATH="${FNM_DIR}:${FNM_DIR}/aliases/default/bin:${PNPM_HOME}/bin:${PNPM_HOME}:/home/agent/.local/bin:${PATH}"

# 默认使用清华大学 Debian APT 镜像源
ARG USE_CHINA_APT_MIRROR=true

# 安装开发环境依赖；fnm 需要 curl、unzip，Codex 沙箱需要 bubblewrap
RUN if [ "$USE_CHINA_APT_MIRROR" = "true" ]; then \
        sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
        sed -i 's/security.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources ; \
    fi \
    && apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    bubblewrap \
    unzip \
    sudo \
    openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建 sshd 运行所需目录
RUN mkdir -p /run/sshd

# 创建 UID 1000 的非 root 开发用户
RUN useradd -m -s /bin/bash -u 1000 agent

# 设置本地开发使用的默认密码
RUN echo 'agent:agent123' | chpasswd && \
    echo 'root:root123' | chpasswd

# 配置 agent 用户的无密码 sudo 权限
RUN echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# 将外部工具和脚本放入 agent 用户目录，并追加外部 bashrc 配置
COPY --chown=agent:agent home/ /home/agent/
COPY bashrc.sh /tmp/agent-bashrc
RUN printf '\n' >> /home/agent/.bashrc \
    && cat /tmp/agent-bashrc >> /home/agent/.bashrc \
    && rm /tmp/agent-bashrc \
    && chown agent:agent /home/agent/.bashrc

# 切换至非 root 用户并设置工作目录
USER agent
WORKDIR /home/agent/workspace

# fnm 和 Node.js 下载代理
ARG USE_PROXY=true
ARG PROXY_IP=192.168.3.70
ARG PROXY_PORT=7890
ARG PROXY_USER=
ARG PROXY_PASS=

ARG NODE_VERSION=26.8.2

# 通过 fnm 安装固定版本的 Node.js
RUN set -eu; \
    mkdir -p "$PNPM_HOME/bin"; \
    if [ "$USE_PROXY" = "true" ]; then \
        export PROXY_IP PROXY_PORT PROXY_USER PROXY_PASS; \
        . "$HOME/set-proxy.sh"; \
    fi; \
    curl -fsSL https://fnm.vercel.app/install -o /tmp/fnm-install.sh; \
    SHELL=/bin/bash bash /tmp/fnm-install.sh --install-dir "$FNM_DIR"; \
    rm /tmp/fnm-install.sh; \
    eval "$(fnm env --shell bash)"; \
    fnm install "$NODE_VERSION" --use; \
    fnm default "$NODE_VERSION"

ARG USE_CHINA_NPM_MIRROR=true
ARG PNPM_VERSION=12.4.1

# 安装 Corepack 和固定版本 pnpm，并按需配置 npm 国内镜像
RUN set -eu; \
    eval "$(fnm env --shell bash)"; \
    if [ "$USE_CHINA_NPM_MIRROR" = "true" ]; then \
        npm config set registry https://registry.npmmirror.com; \
        export COREPACK_NPM_REGISTRY=https://registry.npmmirror.com; \
    fi; \
    npm install --global corepack@latest; \
    corepack enable pnpm; \
    corepack prepare "pnpm@$PNPM_VERSION" --activate; \
    if [ "$USE_CHINA_NPM_MIRROR" = "true" ]; then \
        pnpm config set registry https://registry.npmmirror.com; \
    fi

ARG CODEX_VERSION=0.154.0

# 安装固定版本 Codex
RUN set -eu; \
    eval "$(fnm env --shell bash)"; \
    pnpm install --global "@openai/codex@$CODEX_VERSION"

ARG PI_VERSION=0.85.1

# 安装固定版本 Pi Agent，跳过包安装脚本
RUN set -eu; \
    eval "$(fnm env --shell bash)"; \
    pnpm add --global --ignore-scripts "@earendil-works/pi-coding-agent@$PI_VERSION"

# 默认启动 Bash
CMD ["/bin/bash"]
