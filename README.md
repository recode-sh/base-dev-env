# Base Dev Env

This repository contains the source code of the `recode-sh/base-dev-env` Docker image. 

This image is the base image that powers all the development environments created via the [Recode CLI](https://github.com/recode-sh/cli).

## Table of contents
- [Requirements](#requirements)
- [Build](#build)
- [Image](#image)
  - [ONBUILD commands](#onbuild-commands)
  - [Entrypoint](#entrypoint)
- [The future](#the-future)
- [License](#license)

## Requirements

The Recode Base Dev Env Docker image is defined as a plain Dockerfile file so it only requires `docker` to be built.

## Build

To build this image, the `docker build` command could be used:

```bash
docker build -t recode-base-dev-env-image .
```

## Image

The Dockerfile has been extensively commented to be self-explanatory:

```Dockerfile
# All development environments will be Ubuntu-based
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# RUN will use bash
SHELL ["/bin/bash", "-c"]

# We want a "standard Ubuntu"
# (ie: not one that has been minimized
# by removing packages and content
# not required in a production system)
RUN yes | unminimize

# Install system dependencies
RUN set -euo pipefail \
  && apt-get --assume-yes --quiet --quiet update \
  && apt-get --assume-yes --quiet --quiet install \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  locales \
  lsb-release \
  man-db \
  manpages-posix \
  nano \
  sudo \
  tzdata \
  unzip \
  vim \
  wget \
  && rm --recursive --force /var/lib/apt/lists/*

# Install the Docker CLI. 
# The Docker daemon socket will be mounted from instance.
RUN set -euo pipefail \
  && curl --fail --silent --show-error --location https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --output /usr/share/keyrings/docker-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release --codename --short) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get --assume-yes --quiet --quiet update \
  && apt-get --assume-yes --quiet --quiet install docker-ce-cli \
  && rm --recursive --force /var/lib/apt/lists/*

# Install Docker compose
RUN set -euo pipefail \
  && LATEST_COMPOSE_VERSION=$(curl --fail --silent --show-error --location "https://api.github.com/repos/docker/compose/releases/latest" | grep --only-matching --perl-regexp '(?<="tag_name": ").+(?=")') \
  && curl --fail --silent --show-error --location "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname --kernel-name)-$(uname --machine)" --output /usr/libexec/docker/cli-plugins/docker-compose \
  && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# Install entrypoint script
COPY ./recode_entrypoint.sh /
RUN chmod +x /recode_entrypoint.sh

# Configure the user "recode" in container.
# Triggered during build on instance.
# 
# We want the user "recode" inside the container to get 
# the same permissions than the user "recode" in the instance 
# (to access the Docker daemon, SSH keys and so on).
# 
# To do this, the two users need to share the same UID/GID.
ONBUILD ARG RECODE_USER_ID
ONBUILD ARG RECODE_USER_GROUP_ID
ONBUILD ARG RECODE_DOCKER_GROUP_ID

ONBUILD RUN set -euo pipefail \
  && RECODE_USER_HOME_DIR="/home/recode" \
  && RECODE_USER_WORKSPACE_DIR="${RECODE_USER_HOME_DIR}/workspace" \
  && RECODE_USER_WORKSPACE_CONFIG_DIR="${RECODE_USER_HOME_DIR}/.workspace-config" \
  && groupadd --gid "${RECODE_USER_GROUP_ID}" --non-unique recode \
  && useradd --gid "${RECODE_USER_GROUP_ID}" --uid "${RECODE_USER_ID}" --non-unique --home "${RECODE_USER_HOME_DIR}" --create-home --shell /bin/bash recode \
  && cp /etc/sudoers /etc/sudoers.orig \
  && echo "recode ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/recode > /dev/null \
  && groupadd --gid "${RECODE_DOCKER_GROUP_ID}" --non-unique docker \
  && usermod --append --groups docker recode \
  && mkdir --parents "${RECODE_USER_WORKSPACE_CONFIG_DIR}" \
  && mkdir --parents "${RECODE_USER_WORKSPACE_DIR}" \
  && mkdir --parents "${RECODE_USER_HOME_DIR}/.ssh" \
  && mkdir --parents "${RECODE_USER_HOME_DIR}/.gnupg" \
  && mkdir --parents "${RECODE_USER_HOME_DIR}/.vscode-server" \
  && chown --recursive recode:recode "${RECODE_USER_HOME_DIR}" \
  && chmod 700 "${RECODE_USER_HOME_DIR}/.gnupg"

ONBUILD WORKDIR /home/recode/workspace
ONBUILD USER recode

ONBUILD ENV USER=recode
ONBUILD ENV HOME=/home/recode
ONBUILD ENV EDITOR=/usr/bin/nano

ONBUILD ENV RECODE_WORKSPACE=/home/recode/workspace
ONBUILD ENV RECODE_WORKSPACE_CONFIG=/home/recode/.workspace-config

# Only for documentation purpose.
# Entrypoint and CMD are always set by the 
# Recode agent when running the dev env container.
ONBUILD ENTRYPOINT ["/recode_entrypoint.sh"]
ONBUILD CMD ["sleep", "infinity"]

# Set default timezone
ENV TZ=America/Los_Angeles

# Set default locale
# /!\ locale-gen must be run as root
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
```

In other words, Recode is built on `ubuntu` with `docker` and `docker compose` pre-installed. 

An user `recode` <ins>**will be**</ins> created and configured to be used as the default user <ins>**during the build of your development environment**</ins>. 

Root privileges are managed via `sudo`. Your repositories will be cloned in `/home/recode/workspace`. 

A default timezone and locale are set.

### `ONBUILD` commands

The `ONBUILD` commands are commands that will be run during the build of your development environment. 

In this case, they will enable us to create an user `recode` *in the container* that will match the one created *in the instance*. 

In this way, the user `recode` *inside the container* will be able to access the Docker daemon, SSH keys and so on like the one *in the instance*.

### Entrypoint

The entrypoint is defined as a `bash` script in the `recode_entrypoint.sh` file:

```bash
#!/bin/bash
# Recode development environment entrypoint
set -euo pipefail

# Import GitHub GPG keys for user
gpg --import ~/.gnupg/recode_github_gpg_public.pgp
gpg --import ~/.gnupg/recode_github_gpg_private.pgp

# Run the CMD passed as command-line arguments
exec "$@"
```
As you can see, nothing fancy here. The user's GitHub `GPG` keys are imported in the agent to be used with `GIT`. The passed `CMD` (`sleep infinity`) is then executed.

The `ENTRYPOINT` and `CMD` commands present in the Dockerfile will be overwritten by the [Recode agent](https://github.com/recode-sh/agent) when running the container in order to prevent users from modifiying it in their `dev_env.Dockerfile` files.

## The future

This project is **100% community-driven**, meaning that except for bug fixes <ins>**no more features will be added**</ins>. 

The only features that will be added are the ones that will be [posted as an issue](https://github.com/recode-sh/cli/issues/new) and that will receive a significant amount of upvotes **(>= 10 currently)**.

## License

Recode is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
