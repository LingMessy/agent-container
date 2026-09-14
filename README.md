# Agent Container

一个面向 AI Coding Agent 的通用开发容器镜像。项目基于 Debian Trixie Slim，预装常用开发工具，并提供非 root 用户、SSH 服务、目录挂载和国内网络配置。

## 环境概览

| 项目 | 配置 |
| --- | --- |
| 基础镜像 | `debian:trixie-slim` |
| 默认用户 | `agent`（UID `1000`） |
| 工作目录 | `/home/agent/workspace` |
| 开发工具 | Git、curl、jq、Python 3、pip、venv、fnm、固定版本 Node.js、pnpm、Codex、Pi Agent、build-essential |
| 远程访问 | OpenSSH Server，默认宿主机端口 `2233` 映射到容器端口 `22` |
| 提权方式 | `agent` 用户可免密使用 `sudo` |
| 默认 APT 源 | 清华大学镜像源，可通过构建参数关闭 |
| 默认 npm 源 | `https://registry.npmmirror.com`，可通过构建参数关闭 |

## 前置要求

推荐使用 Podman 及其 Compose 支持：

```bash
# 查看 Podman 和 Compose 版本
podman --version
podman compose version

# 查看容器状态和日志
podman compose ps
podman compose logs -f

# 停止并删除当前项目的容器和网络
podman compose down
```

更多用法请参考 [Podman 文档](https://docs.podman.io/) 和 [podman-compose 文档](https://github.com/containers/podman-compose)。

`compose.yaml` 使用了 Podman 的 `userns_mode: keep-id`，以便在 Rootless 模式下让容器内进程正确访问宿主机挂载的文件。镜像本身也可以使用 Docker 构建，但 Docker Compose 可能不支持该配置项。

## 快速开始（国内环境）

克隆项目：

```bash
git clone https://github.com/LingMessy/agent-container.git
cd agent-container
```

使用国内镜像拉取基础镜像：

```bash
chmod +x ./pull.sh && ./pull.sh
```

配置 SSH 端口和 fnm/Node.js 下载代理，然后构建并启动容器：

```bash
# 设置 SSH 端口
export SSH_PORT=2234

# 设置代理
export USE_PROXY=true
export PROXY_IP=192.168.3.70
export PROXY_PORT=7890

# 构建镜像并启动容器
podman compose up --build -d
```

当前项目目录会挂载到容器内的 `/home/agent/workspace`。

## 支持变量

可配置的构建参数如下；Compose 支持同名宿主机环境变量或项目 `.env` 文件：

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `USE_PROXY` | `true` | 仅在安装 fnm 和 Node.js 时加载代理 |
| `PROXY_IP` | `192.168.3.70` | 代理主机地址 |
| `PROXY_PORT` | `7890` | 代理端口 |
| `PROXY_USER` | 空 | 代理用户名 |
| `PROXY_PASS` | 空 | 代理密码，与用户名同时设置时启用认证 |
| `USE_CHINA_NPM_MIRROR` | `true` | 使用 `https://registry.npmmirror.com` 配置 npm、Corepack 和 pnpm |
| `USE_CHINA_APT_MIRROR` | `true` | 使用清华大学 Debian APT 镜像源 |

## SSH 连接

```bash
ssh agent@localhost -p 2234
```

默认凭据：

- 用户名：`agent`
- 密码：`agent123`

## 项目结构

```text
.
├── Containerfile    # 镜像构建定义
├── compose.yaml     # 本地开发容器编排配置
├── pull.sh          # 用于通过国内镜像拉取基础镜像的脚本
├── home/            # 构建时复制到 /home/agent 的外部工具和脚本
└── bashrc.sh        # 构建时追加到 agent 用户 .bashrc
```
