##############################################################################
#
# Module: Makefile
#
# Purpose:
#	Procedures for building/running docker container from this directory
#
# Version:
#   V0.1.0 Wed Feb 04 2026 23:10:08  tmm   Edit level 1
#
# Copyright notice:
#   This file copyright (C) 2026 by:
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
#   0.1.0  Wed Feb 04 2026 23:10:08  tmm
#       Add MCCI module header
#
##############################################################################

SHELL := /bin/bash

MCCI_CLAUDE_UBUNTU_TAG=gitlab-x.mcci.com:10001/mcci/tools/containers/mcci-claude-ubuntu
MCCI_CLAUDE_UBUNTU_VERSION=v0.1.0

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
		-t ${MCCI_CLAUDE_UBUNTU_TAG}:latest \
		-t ${MCCI_CLAUDE_UBUNTU_TAG}:${MCCI_CLAUDE_UBUNTU_VERSION} \
		-t mcci-claude-ubuntu \
		--build-arg USER_ID=${BUILD_UID} \
		--build-arg USER_NAME=${BUILD_UNAME} \
		--build-arg GROUP_ID=${BUILD_GID} \
		--build-arg GROUP_NAME=${BUILD_GNAME} \
		--build-arg USER_GECOS="${BUILD_GECOS}" \
		-f Dockerfile \
		.

PROJECT_CONTEXT := ${CURDIR}/.context

PROJECT_WORKSPACE :=	${CURDIR}/workspace

PROJECT_MOUNTS :=	\
		--mount type=bind,source=${PROJECT_WORKSPACE},target=/workspace \
		--volume "${PROJECT_CONTEXT}/.cache:/home/${BUILD_UNAME}/.cache" \
		--volume "${PROJECT_CONTEXT}/.claude:/home/${BUILD_UNAME}/.claude" \
		--volume "${PROJECT_CONTEXT}/.bashrc:/home/${BUILD_UNAME}/.bashrc:ro" \
		--volume "${PROJECT_CONTEXT}/.bash_aliases:/home/${BUILD_UNAME}/.bash_aliases:ro" \
		--volume "${PROJECT_CONTEXT}/.bash_history:/home/${BUILD_UNAME}/.bash_history" \
		--volume "${PROJECT_CONTEXT}/.claude.json:/home/${BUILD_UNAME}/.claude.json" \
		--volume "${CURDIR}/init-firewall-extra.txt:/usr/local/etc/init-firewall-extra.txt:ro" \
# end PROJECT_MOUNTS

# if we don't set up the files that we're mounting in, Docker will
# create a directory. And if we don't create .claude in the
# context, the created directory will have the wrong permissions.
run-setup:
	@mkdir -p "${PROJECT_CONTEXT}"
	@mkdir -p "${PROJECT_WORKSPACE}"
	@mkdir -p "${PROJECT_CONTEXT}/.claude" "${PROJECT_CONTEXT}/.cache"
	@if [[ ! -f "${PROJECT_CONTEXT}/.bashrc" ]] && \
	    [[ -f "${HOME}/.bashrc" ]]; then \
			printf "\n" "initalize .bashrc" && \
			cp "${HOME}/.bashrc" "${PROJECT_CONTEXT}/.bashrc" ; \
	fi
	@if [[ ! -f "${PROJECT_CONTEXT}/.bash_aliases" ]] && \
	    [[ -f "${HOME}/.bash_aliases" ]] ; then \
		printf "\n" "initalize .bash_aliases" && \
		cp "${HOME}/.bash_aliases" "${PROJECT_CONTEXT}/.bash_aliases" ; \
	fi
	@if [[ ! -f "${PROJECT_CONTEXT}/.bash_history" ]] ; then \
		printf "\n" "initalize empty .bash_history" && \
		touch "${PROJECT_CONTEXT}/.bash_history" ; \
	fi
	@if [[ ! -f "${PROJECT_CONTEXT}/.claude.json" ]] ; then \
		printf "\n" "initalize empty .claude.json" && \
		touch "${PROJECT_CONTEXT}/.claude.json" ; \
	fi
	@if [[ ! -f "${CURDIR}/init-firewall-extra.txt" ]] ; then \
		printf "\n" "initalize empty init-firewall-extra.txt" && \
		touch "${CURDIR}/init-firewall-extra.txt" ; \
	fi

run:	run-setup
	docker run -it --rm \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		${PROJECT_MOUNTS} \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CLAUDE_UBUNTU_TAG} \
		bash --init-file /usr/local/bin/read-bashrc-init-firewall.sh

run-ssh: run-setup
	docker run -it --rm \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		--volume ${SSH_AUTH_SOCK}:/ssh_agent --env SSH_AUTH_SOCK=/ssh_agent \
		${PROJECT_MOUNTS} \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CLAUDE_UBUNTU_TAG} \
		bash --init-file /usr/local/bin/read-bashrc-init-firewall.sh

run-ssh-nofw: run-setup
	docker run -it --rm \
		--volume ${SSH_AUTH_SOCK}:/ssh_agent --env SSH_AUTH_SOCK=/ssh_agent \
		${PROJECT_MOUNTS} \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CLAUDE_UBUNTU_TAG} \
		bash

push:
	@bash -c 'if [[ "${MCCI_CLAUDE_UBUNTU_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-,*|)$$ ]]; then \
		true; \
	else \
		echo "MCCI_CLAUDE_UBUNTU_VERSION must be of form v#.#.# or v#.#.#-pre#" ; \
		false; \
	fi'
	# tag before pushing to catch redundant operation
	git tag -a -m "Image ${MCCI_CLAUDE_UBUNTU_TAG}:${MCCI_CLAUDE_UBUNTU_VERSION}" "${MCCI_CLAUDE_UBUNTU_VERSION}"
	docker push ${MCCI_CLAUDE_UBUNTU_TAG}:latest
	docker push ${MCCI_CLAUDE_UBUNTU_TAG}:${MCCI_CLAUDE_UBUNTU_VERSION}

#### end of file ####
