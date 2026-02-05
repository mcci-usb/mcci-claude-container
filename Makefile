##############################################################################
#
# Module: Makefile
#
# Purpose:
#	Procedures for building/running docker container from this directory
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
#   	Cleanup accidently pollution from openvino fork; get user ID
#   	from /etc/passwd by searching, not by $UID.
#
##############################################################################

MCCI_CI_COMPILE_UBUNTU_TAG=gitlab-x.mcci.com:10001/mcci/tools/containers/mcci-ci-compile-ubuntu
MCCI_CI_COMPILE_UBUNTU_VERSION=v0.1.1

# defaults
BUILD_UNAME ?= ${LOGNAME}
BUILD_UID ?= $(shell grep '^${LOGNAME}:' /etc/passwd | cut -d: -f3)
$(message BUILD_UID: ${BUILD_UID})
BUILD_GECOS ?= $(shell grep '^${LOGNAME}:' /etc/passwd | cut -d: -f5 | cut -d, -f1)
BUILD_GID ?= $(shell grep '^${LOGNAME}:' /etc/passwd | cut -d: -f4)
BUILD_GNAME ?= $(shell getent group ${BUILD_GID} | cut -d: -f1)

build:	Dockerfile
	cd $(dir Dockerfile)
	docker build \
		-t ${MCCI_CI_COMPILE_UBUNTU_TAG}:latest \
		-t ${MCCI_CI_COMPILE_UBUNTU_TAG}:${MCCI_CI_COMPILE_UBUNTU_VERSION} \
		-t mcci-ci-compile-ubuntu \
		--build-arg USER_ID=${BUILD_UID} \
		--build-arg USER_NAME=${BUILD_UNAME} \
		--build-arg GROUP_ID=${BUILD_GID} \
		--build-arg GROUP_NAME=${BUILD_GNAME} \
		--build-arg USER_GECOS="${BUILD_GECOS}" \
		-f Dockerfile \
		.

run:
	docker run -it --rm \
		--volume ${SSH_AUTH_SOCK}:/ssh_agent --env SSH_AUTH_SOCK=/ssh_agent \
		--mount type=bind,source=${realpath .},target=/src \
		--mount type=bind,source=/home/tools,target=/home/tools \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CI_COMPILE_UBUNTU_TAG} \
		bash

push:
	@bash -c 'if [[ "${MCCI_CI_COMPILE_UBUNTU_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-,*|)$$ ]]; then \
		true; \
	else \
		echo "MCCI_CI_COMPILE_UBUNTU_VERSION must be of form v#.#.# or v#.#.#-pre#" ; \
		false; \
	fi'
	# tag before pushing to catch redundant operation
	git tag -a -m "Image ${MCCI_CI_COMPILE_UBUNTU_TAG}:${MCCI_CI_COMPILE_UBUNTU_VERSION}" "${MCCI_CI_COMPILE_UBUNTU_VERSION}"
	docker push ${MCCI_CI_COMPILE_UBUNTU_TAG}:latest
	docker push ${MCCI_CI_COMPILE_UBUNTU_TAG}:${MCCI_CI_COMPILE_UBUNTU_VERSION}
