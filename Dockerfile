##############################################################################
#
# Module: Dockerfile
#
# Function:
#   Specify docker image contents for Claude Code work in a container.
#
# Version:
#   V0.1.0  Wed Feb 04 2026 23:10:08  tmm   Edit level 1
#
# Copyright notice:
#   This file copyright (C) 2026 by:
#
#       MCCI Corporation
#       3520 Krums Corners Rd
#       Ithaca, NY  14850
#
#   See LICENSE.md for license information.
#
# Author:
#   Terry Moore, MCCI Corporation   February 2026
#
# Revision History:
#   0.1.0  Wed Feb 04 2026 23:10:08  tmm
#	    Module created.
#
##############################################################################

#
# By default, we build on Ubuntu 24.04. This can be overridden when building
# if needed.
#
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}
LABEL Description="MCCI Claude Code environment"

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

SHELL [ "/bin/bash", "-c" ]

RUN apt-get update
RUN apt-get -y dist-upgrade
RUN apt-get -y --no-install-recommends install \
    make \
    ca-certificates \
    gnupg \
    curl

RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install -y nodejs

RUN apt-get -y --no-install-recommends install \
    git \
    openssh-client \
    sudo \
    iptables \
    ipset \
    jq \
    dnsutils \
    aggregate \
    iproute2

#RUN apt-get -y --no-install-recommends install \
#    build-essential \
#    gcc-multilib

# Copy the firewall script
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY read-bashrc-init-firewall.sh /usr/local/bin/read-bashrc-init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/read-bashrc-init-firewall.sh

# set up user ids; normally overriden
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=mcci
ARG GROUP_NAME=mcci
ARG USER_GECOS="MCCI Corporation"

# create a guest user with given UID and GID.
RUN if id -u ${USER_NAME} > /dev/null 2>&1 ; then userdel -f ${USER_NAME} ; fi && \
    if getent group ${GROUP_NAME} ; then groupdel ${GROUP_NAME} ; fi && \
    groupadd -g ${GROUP_ID} ${GROUP_NAME} && \
    if getent group admin ; then true; else groupadd admin ; fi && \
    adduser --uid ${USER_ID} --disabled-password --ingroup ${GROUP_NAME} --gecos="${USER_GECOS}" ${USER_NAME} && \
    adduser ${USER_NAME} admin

# make sure user can sudo w/o password
RUN printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' ${USER_NAME} >> /etc/sudoers

# switch to the created user
WORKDIR /home/${USER_NAME}

# set up the user env.
USER ${USER_NAME}
ENV HOME=/home/${USER_NAME}
ENV PATH="$PATH:/home/${USER_NAME}/.local/bin"

# set up ssh
RUN mkdir -m 700 .ssh && \
    printf "StrictHostKeyChecking no\n" > .ssh/config

# configure git, just in case.
RUN git config --global user.email "$USER_NAME@mcci.com" && \
    git config --global user.name "$USER_GECOS"

# install claude
RUN curl -fsSL https://claude.ai/install.sh | bash

### end of file ###
