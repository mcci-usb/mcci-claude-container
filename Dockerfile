##############################################################################
#
# Module: Dockerfile
#
# Function:
#   Specify docker image contents for MCCI CI Integration on Ubuntu.
#
# Version:
#   V0.1.1  Fri Jul 28 2023 18:42:18  tmm   Edit level 2
#
# Copyright notice:
#   This file copyright (C) 2022-2023 by:
#
#       MCCI Corporation
#       3520 Krums Corners Rd
#       Ithaca, NY  14850
#
#   An unpublished work; all right reserved.
#
#   This file is proprietary information, and may not be disclosed
#   or copied without the prior permission of MCCI Corporation.
#
# Author:
#   Terry Moore, MCCI Corporation   December 2022
#
# Revision History:
#   0.1.0  Sat Dec 31 2022 17:13:37  tmm
#       Add MCCI module header
#
#   0.1.1  Fri Jul 28 2023 18:42:18  tmm
#	Make cross compiles work properly; and fix sudo.
#
##############################################################################

#
# By default, we build on Ubuntu 16.04 to ensure compatibility
# with older customer environments. This can be overridden when building
# if needed.
#
ARG UBUNTU_VERSION=16.04
FROM ubuntu:${UBUNTU_VERSION}
LABEL Description="MCCI build environment"

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

SHELL [ "/bin/bash", "-c" ]

RUN apt-get update
RUN apt-get -y dist-upgrade
RUN apt-get -y --no-install-recommends install \
    make \
    curl \
    git \
    openssh-client \
    ksh byacc sharutils cvs zip ghostscript groff bsdmainutils \
    sudo

RUN apt-get -y --no-install-recommends install \
    build-essential \
    gcc-multilib

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

# copy and run the install script
## COPY openvino/install_build_dependencies.sh .
## RUN bash install_build_dependencies.sh

# set up the user env.
USER ${USER_NAME}
ENV HOME /home/${USER_NAME}
ENV PATH "$PATH:/home/tools/bin"

# set up ssh
RUN mkdir -m 700 .ssh&& \
    printf "StrictHostKeyChecking no\n" > .ssh/config

# configure git, just in case.
RUN git config --global user.email "$USER_NAME@mcci.com" && \
    git config --global user.name "$USER_GECOS"

### end of file ###
