# 使用最新的 Debian 稳定版镜像
FROM docker.io/library/debian:trixie-slim

# 定义构建参数，默认关闭国内源开关
ARG USE_CHINA_MIRROR=true

# OCI 标准元数据
LABEL org.opencontainers.image.title="AI Agent Execution Environment" \
      org.opencontainers.image.description="Container environment tailored for AI coding agent workloads" \
      org.opencontainers.image.vendor="Local Engine" \
      org.opencontainers.image.licenses="MIT"

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="/home/agent/.local/bin:$PATH"

# 根据参数判断是否更换为清华大学 APT 源，并安装所需软件包（含 sudo 和 openssh-server）
RUN if [ "$USE_CHINA_MIRROR" = "true" ]; then \
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
    nodejs \
    npm \
    build-essential \
    sudo \
    openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建 sshd 运行所需目录
RUN mkdir -p /run/sshd

# 创建非 root 用户（符合 Podman Rootless 最佳实践）
RUN useradd -m -s /bin/bash -u 1000 agent

# 设置 root 和 agent 用户的密码
# (此处设置 agent 密码为 agent123，root 密码为 root123，可根据需求自行更改)
RUN echo 'agent:agent123' | chpasswd && \
    echo 'root:root123' | chpasswd

# 配置 agent 用户的无密码 sudo 权限
RUN echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# 切换至非 root 用户并设置工作目录
USER agent
WORKDIR /home/agent/app

# 默认进入交互式终端
CMD ["/bin/bash"]
