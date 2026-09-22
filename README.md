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

克隆此仓库，并将配置初始化到已有项目（需要 Bash 和 GNU 常用命令，包括 `sha256sum`）：

```bash
git clone https://github.com/LingMessy/agent-container.git
cd agent-container
./init.sh /path/to/your-project
cd /path/to/your-project/.agent-container
```

初始化脚本会复制 `Containerfile`、`compose.yaml`、本说明、`pull.sh`、`bashrc.sh`、`home/` 及配置模板和忽略规则到项目的 `.agent-container/`。目标项目目录必须存在且位于源仓库之外；如果 `.agent-container` 路径已存在，脚本提示并退出，不覆盖任何内容。脚本不会构建或启动容器。

`.env` 从 `.env.example` 生成，并追加由项目目录名和绝对路径短哈希组成的 `COMPOSE_PROJECT_NAME`。`compose.yaml` 的顶层 `name` 显式使用这个变量，用于区分不同项目的容器、网络等资源。源仓库的本地 `.env` 和 `.git` 不会被复制。生成的 `.env` 权限为 `600`，并由随附的 `.gitignore` 和 `.containerignore` 排除；可提交 `.env.example` 供团队复用。项目移动后无需重新生成配置；如果将整个项目复制为另一个并行运行的实例，请修改其 `COMPOSE_PROJECT_NAME` 和 SSH 端口。

如果已经在初始化后的 `.agent-container/` 中，直接从以下步骤开始。

为避免当前终端中残留的旧代理配置干扰后续拉取和构建，建议先运行一次：

```bash
source ./home/unset-proxy.sh
```

使用国内镜像拉取基础镜像：

```bash
bash ./pull.sh
```

编辑 `.agent-container/.env`，设置 SSH 端口和 fnm/Node.js 下载代理。例如：

```dotenv
SSH_PORT=2234
USE_PROXY=true
PROXY_IP=192.168.3.70
PROXY_PORT=7890
```

多个项目同时运行时，需要为每个项目指定不同的 SSH 端口。Compose 会自动读取 `.env`，不需要 `source`；同名宿主机环境变量会覆盖文件中的值。

在 `.agent-container/` 内构建并启动容器：

```bash
podman compose up --build -d
```

默认挂载 `.agent-container/` 的上级目录（整个项目）到容器内的 `/home/agent/workspace`。`WORKSPACE_SOURCE` 可以设置为相对 Compose 文件所在目录的路径或宿主机绝对路径；`WORKSPACE_DIRD` 控制容器内挂载位置和工作目录。构建上下文仍为 `.agent-container/`。

如需直接在源仓库中启动，将 `.env.example` 复制为 `.env`，设置 `WORKSPACE_SOURCE=.` 后再运行 Compose。

## 支持变量

可配置变量如下；Compose 支持通过同名宿主机环境变量或项目 `.env` 文件设置：

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `COMPOSE_PROJECT_NAME` | 初始化时生成 | 区分项目的容器和网络 |
| `SSH_PORT` | `2233` | 宿主机 SSH 端口，多个项目应使用不同端口 |
| `USE_PROXY` | `true` | 仅在安装 fnm 和 Node.js 时加载代理 |
| `PROXY_IP` | `192.168.3.70` | 代理主机地址 |
| `PROXY_PORT` | `7890` | 代理端口 |
| `PROXY_USER` | 空 | 代理用户名 |
| `PROXY_PASS` | 空 | 代理密码，与用户名同时设置时启用认证 |
| `USE_CHINA_NPM_MIRROR` | `true` | 使用 `https://registry.npmmirror.com` 配置 npm、Corepack 和 pnpm |
| `USE_CHINA_APT_MIRROR` | `true` | 使用清华大学 Debian APT 镜像源 |
| `WORKSPACE_SOURCE` | `..` | 宿主机挂载源，相对路径以 Compose 文件所在目录为基准 |
| `WORKSPACE_DIRD` | `/home/agent/workspace` | 容器内的项目挂载位置和工作目录，并作为运行时环境变量暴露 |

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
├── init.sh          # 将运行配置初始化到目标项目的 .agent-container/（仅源仓库）
├── .env.example     # 环境变量模板，初始化时生成本地 .env
├── .gitignore       # 忽略本地 .env
├── .containerignore # 排除不需要进入构建上下文的文件
├── Containerfile    # 镜像构建定义
├── compose.yaml     # 本地开发容器编排配置
├── pull.sh          # 用于通过国内镜像拉取基础镜像的脚本
├── home/            # 构建时复制到 /home/agent 的外部工具和脚本
└── bashrc.sh        # 构建时追加到 agent 用户 .bashrc
```
