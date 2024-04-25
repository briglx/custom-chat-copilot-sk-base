FROM mcr.microsoft.com/devcontainers/python:3.12-bullseye

# hadolint ignore=DL3008,SC2016
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    jq \
    lsb-release \
    shellcheck \
    unzip \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    echo 'alias ll='"'"'ls $LS_OPTIONS -al'"'"'' >> /etc/bash.bashrc

# Install hadolint for dockerfile linting
RUN curl -Lo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint

# [Optional] If your pip requirements rarely change, uncomment this section to add them to the image.
# COPY ./requirements.txt /tmp/pip-tmp/
# COPY ./requirements_dev.txt /tmp/pip-tmp/
# RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements_dev.txt \
#     && rm -rf /tmp/pip-tmp
