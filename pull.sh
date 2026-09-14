#!/bin/bash

dockerio_mirror="m.daocloud.io/docker.io"

# 通过 DaoCloud 镜像拉取 Debian，并标记为官方镜像名称
podman pull $dockerio_mirror/library/debian:trixie-slim
podman tag $dockerio_mirror/library/debian:trixie-slim docker.io/library/debian:trixie-slim
podman rmi $dockerio_mirror/library/debian:trixie-slim
