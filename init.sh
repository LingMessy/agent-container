#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '用法: %s <项目根目录>\n' "$0"
}

if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
  usage
  exit 0
fi
if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi
if [[ ! -d $1 ]]; then
  printf '项目目录不存在或不是目录: %s\n' "$1" >&2
  exit 1
fi

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
project_dir=$(cd -- "$1" && pwd -P)
destination="$project_dir/.agent-container"

if [[ -e $destination || -L $destination ]]; then
  printf '目标路径已存在，未作修改: %s\n' "$destination" >&2
  exit 1
fi
# 防止将复制目标放入源目录，造成递归复制。
if [[ $project_dir == "$source_dir" || $project_dir == "$source_dir/"* ]]; then
  printf '请指定 agent-container 源目录之外的项目目录。\n' >&2
  exit 1
fi

files=(Containerfile compose.yaml README.md pull.sh bashrc.sh home .env.example .gitignore .containerignore)
for file in "${files[@]}"; do
  if [[ ! -e $source_dir/$file ]]; then
    printf '缺少源文件: %s\n' "$source_dir/$file" >&2
    exit 1
  fi
done

project_slug=$(basename -- "$project_dir" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed 's/[^a-z0-9_-]/-/g')
project_slug=${project_slug:0:48}
project_hash=$(printf '%s' "$project_dir" | sha256sum)
project_name="agent-${project_slug}-${project_hash:0:12}"

# mkdir 同时保证已有路径不会被覆盖；失败时移除本次创建的内容。
mkdir -- "$destination"
cleanup() {
  if [[ ${initialized:-false} != true ]]; then
    rm -rf -- "$destination"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for file in "${files[@]}"; do
  cp -R -- "$source_dir/$file" "$destination/"
done
(umask 077; cat -- "$source_dir/.env.example" > "$destination/.env")
printf '\nCOMPOSE_PROJECT_NAME=%s\n' "$project_name" >> "$destination/.env"
chmod 600 -- "$destination/.env"
initialized=true

printf '初始化完成: %s\n' "$destination"
printf '请编辑 .env 中的代理配置和 SSH 端口，然后运行：\n'
printf '  cd %q\n' "$destination"
printf '  bash ./pull.sh\n  podman compose up --build -d\n'
