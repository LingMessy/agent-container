# Agent Container

一个面向 AI Coding Agent 的通用开发容器镜像。项目基于 Debian Trixie Slim，预装常用开发工具，并提供适合本地开发的非 root 用户、SSH 服务、目录挂载和代理配置脚本。

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

## 前置要求

推荐使用 Podman 及其 Compose 支持：

```bash
podman --version
podman compose version
```

`compose.yaml` 使用了 Podman 的 `userns_mode: keep-id`，以便在 Rootless 模式下让容器内进程正确访问宿主机挂载的文件。镜像本身也可以使用 Docker 构建，但 Docker Compose 可能不支持该配置项。

## 快速开始

构建默认开启代理和 npm 国内镜像，请先确认 `192.168.3.70:7890` 可从构建容器访问。如果使用其他代理，在启动前设置 `PROXY_IP` 和 `PROXY_PORT`；无需代理时设置 `USE_PROXY=false`，无需 npm 国内镜像时设置 `USE_CHINA_NPM_MIRROR=false`。Node.js、pnpm、Codex 和 Pi Agent 使用固定版本，避免上游发布新版本导致安装结果漂移；版本参数、前置步骤变化或缓存缺失仍会触发重新安装。

克隆项目并启动容器：

```bash
git clone https://github.com/LingMessy/agent-container.git
cd agent-container
podman compose up --build -d
```

进入开发环境：

```bash
podman exec -it agent-container-0.1.0 bash
```

当前项目目录会挂载到容器内的 `/home/agent/workspace`，在容器中产生的代码修改会直接反映到宿主机。

查看运行状态和日志：

```bash
podman compose ps
podman compose logs -f
```

停止并删除容器：

```bash
podman compose down
```

## SSH 连接

Compose 启动时会在容器内运行 SSH 服务，并将其映射到宿主机的 `2233` 端口。版本和端口可以通过环境变量调整：

```bash
export AGENT_CONTAINER_VERSION=0.2.0
export SSH_PORT=2234
podman compose -p agent-container-0-2-0 up --build -d
```

镜像、服务和容器统一使用 `agent-container` 前缀，镜像标签默认是 `0.1.0`。并行运行新旧版本时，必须同时使用不同的镜像版本、Compose 项目名（`-p`）和 `SSH_PORT`。后续管理新版本时也要保留相同的环境变量和 `-p` 参数，例如 `podman compose -p agent-container-0-2-0 down`。仅修改镜像或容器名称，同一 Compose 项目仍可能重建旧服务。

默认版本使用目录名 `agent-container` 作为 Compose 项目名；示例中新版本使用 `agent-container-0-2-0`。Compose 项目名不使用版本号中的点。连接新版本：

```bash
ssh agent@localhost -p 2234
```

镜像标签不是不可变的：重新构建同一标签仍会覆盖它的指向，建议开发时使用 `0.2.0-dev` 等新标签，保留已使用的发布标签。此外，默认挂载的是当前项目目录；如需代码也互不影响，请在独立 checkout 或 Git worktree 中开发新版本。已有的 `agent-runtime` 容器不会因配置文件修改而自动迁移。

默认凭据：

- 用户名：`agent`
- 密码：`agent123`

这些凭据仅适合本地开发。若容器端口会暴露给局域网或公网，请在 `Containerfile` 中修改密码，或改用 SSH 公钥认证后再构建镜像。

## 构建镜像

默认使用清华大学 APT 镜像源：

```bash
podman build -t localhost/agent-container:0.1.0 -f Containerfile .
```

如需使用 Debian 官方源，可关闭 `USE_CHINA_APT_MIRROR`：

```bash
podman build \
  --build-arg USE_CHINA_APT_MIRROR=false \
  -t localhost/agent-container:0.1.0 \
  -f Containerfile .
```

由于 fnm 和 Node.js 下载在国内网络环境下可能不稳定，安装 fnm/Node.js 的构建步骤默认加载镜像内的 `/home/agent/set-proxy.sh`。代理参数通过构建参数暴露，默认值为 `192.168.3.70:7890`：

```bash
podman build \
  --build-arg USE_PROXY=true \
  --build-arg PROXY_IP=192.168.3.70 \
  --build-arg PROXY_PORT=7890 \
  -t localhost/agent-container:0.1.0 \
  -f Containerfile .
```

如不需要代理，可显式关闭；APT 源仍由 `USE_CHINA_APT_MIRROR` 控制：

```bash
podman build --build-arg USE_PROXY=false \
  -t localhost/agent-container:0.1.0 -f Containerfile .
```

使用 Compose 时设置宿主机环境变量即可，Compose 会将这些变量传给构建参数：

```bash
export USE_PROXY=true
export PROXY_IP=192.168.3.70
export PROXY_PORT=7890
export USE_CHINA_NPM_MIRROR=true
# 如代理需要认证，再设置 PROXY_USER 和 PROXY_PASS
podman compose up --build -d
```

可配置的构建参数如下；Compose 支持同名宿主机环境变量或项目 `.env` 文件：

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `USE_PROXY` | `true` | 仅在安装 fnm 和 Node.js 时加载代理 |
| `PROXY_IP` | `192.168.3.70` | 代理主机地址 |
| `PROXY_PORT` | `7890` | 代理端口 |
| `PROXY_USER` | 空 | 代理用户名 |
| `PROXY_PASS` | 空 | 代理密码，与用户名同时设置时启用认证 |
| `USE_CHINA_NPM_MIRROR` | `true` | 使用 `https://registry.npmmirror.com` 配置 npm、Corepack 和 pnpm |

`PROXY_USER` 和 `PROXY_PASS` 会作为构建参数传入，可能出现在构建历史或日志中，不建议用于需要保密的长期凭据。构建参数优先于 `home/set-proxy.sh` 中的默认值；这些参数不会自动保存为容器运行时的环境变量。运行时可通过同名环境变量覆盖代理配置，或修改脚本默认值后重新构建镜像。

npm 和 pnpm 的镜像配置写入 agent 用户配置文件，并保留到容器运行时。Corepack 在安装 pnpm 时通过 `COREPACK_NPM_REGISTRY` 使用同一镜像。设置 `USE_CHINA_NPM_MIRROR=false` 时不配置国内镜像，使用工具的默认 registry；这些安装步骤不会加载 `set-proxy.sh`，也不会自动回退到 `USE_PROXY` 指定的代理。构建器从宿主机继承的代理环境仍可能影响网络访问。

不使用 Compose 时，可以直接启动镜像并挂载工作目录：

```bash
podman run --rm -it \
  --userns=keep-id \
  -v "$PWD:/home/agent/workspace:Z" \
  localhost/agent-container:0.1.0
```

Docker 用户可以将上述 `podman build` 和 `podman run` 替换为对应的 `docker` 命令，并移除 Docker 不支持的 Podman 专用参数。

## 配置代理

镜像会将 `home/` 目录复制到 `/home/agent/`，其中的 `set-proxy.sh` 会在当前 Shell 中设置 HTTP、HTTPS 和 SOCKS5 代理环境变量。必须使用 `source` 执行，才能让变量在当前终端生效：

```bash
source "$HOME/set-proxy.sh"
```

脚本默认使用 `192.168.3.70:7890`。可以在执行时覆盖地址、端口和认证信息：

```bash
PROXY_IP=192.168.1.100 \
PROXY_PORT=1080 \
PROXY_USER=my-user \
PROXY_PASS=my-password \
source "$HOME/set-proxy.sh"
```

清除代理配置：

```bash
source "$HOME/unset-proxy.sh"
```

宿主机上可在项目根目录执行 `source home/set-proxy.sh`。`USE_PROXY` 仅影响构建时的安装步骤，容器启动后按需加载代理。

## 传递 Agent 凭据

建议通过宿主机环境变量向容器传递 API Key，避免将密钥写入镜像或提交到仓库。例如，可在 `compose.yaml` 的 `environment` 中启用并添加所需变量：

```yaml
environment:
  - NODE_ENV=development
  - PYTHONUNBUFFERED=1
  - OPENAI_API_KEY=${OPENAI_API_KEY}
```

启动前在宿主机设置对应变量：

```bash
export OPENAI_API_KEY="your-api-key"
podman compose up --build -d
```

## 自定义环境

### 固定版本与构建缓存

`Containerfile` 使用以下固定版本参数：

| 参数 | 默认值 |
| --- | --- |
| `NODE_VERSION` | `26.8.2` |
| `PNPM_VERSION` | `12.4.1` |
| `CODEX_VERSION` | `0.154.0` |
| `PI_VERSION` | `0.85.1` |

Compose 支持通过同名宿主机环境变量或 `.env` 文件覆盖这些版本。例如只升级 Pi Agent：

```bash
export PI_VERSION=0.86.0
podman-compose -p agent-container-dev up --build -d
```

Node.js、pnpm、Codex 和 Pi Agent 分属独立安装层，升级 Pi Agent 时可以复用前面的 Node、pnpm 和 Codex 层。`.containerignore` 会排除 `.git`、`node_modules`、包管理器缓存、构建产物和日志，避免无关文件变化导致 `COPY` 层失效。

`home/` 的内容（包括隐藏文件）会复制到镜像的 `/home/agent/`，文件归 `agent` 用户所有，权限保持不变。可将外部工具放在 `home/.local/bin/` 并赋予执行权限，该目录已加入 PATH。fnm 安装脚本会自动将初始化配置追加到 `/home/agent/.bashrc`，`bashrc.sh` 负责追加自定义 Bash 函数、别名和 pnpm 配置。修改这些文件后需重新构建镜像。

Node.js 由 fnm 安装指定版本，Corepack 通过 npm 安装或升级，再激活指定版本的 pnpm。Codex 和 Pi Agent 均由 pnpm 全局安装，其中 Pi 使用 `--ignore-scripts`。可在容器中运行 `codex`、`pi`，或使用 pnpm 管理它们：

```bash
pnpm list -g
pnpm update -g --latest @openai/codex
pnpm update -g --latest --ignore-scripts @earendil-works/pi-coding-agent
```

可以按需修改 `Containerfile` 安装 Agent CLI、语言运行时或项目依赖。例如，添加系统软件包后重新构建：

```bash
podman compose build --no-cache
podman compose up -d
```

容器默认以 `agent` 用户运行。如需执行系统级操作，可在容器内使用 `sudo`。

## 项目结构

```text
.
├── Containerfile    # 镜像构建定义
├── compose.yaml     # 本地开发容器编排配置
├── home/            # 构建时复制到 /home/agent 的外部工具和脚本
└── bashrc.sh        # 构建时追加到 agent 用户 .bashrc
```
