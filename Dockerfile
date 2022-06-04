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
