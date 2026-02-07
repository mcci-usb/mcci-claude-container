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

define GET_SLUG
	percent_encode() {
		local s="$$1" c ;
		while [[ -n "$$s" ]]; do
			c="$${s:0:1}" ;
			if [[ "$$c" =~ [a-zA-Z0-9_/] ]]; then
				printf '%s' "$$c" ;
			else
				printf '%%%02X' "'$$c" ;
			fi ;
			s="$${s:1}" ;
		done
		} ;

	encoded="$$(percent_encode "${CURDIR}" | tr '/' '-')" ;
	echo "$$encoded"
endef

PROJECT_SLUG := ${shell ${GET_SLUG}}

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

BUILD_CONTAINER_CONTEXT := ${HOME}/.config/claude-container/${PROJECT_SLUG}
$(info BUILD_CONTAINER_CONTEXT=${BUILD_CONTAINER_CONTEXT})

PROJECT_WORKSPACE :=	${CURDIR}/workspace

PROJECT_MOUNTS :=	\
		--mount type=bind,source=${PROJECT_WORKSPACE},target=/workspace \
		--volume "${BUILD_CONTAINER_CONTEXT}/.claude:/home/${BUILD_UNAME}/.claude" \
		--volume "${BUILD_CONTAINER_CONTEXT}/.bashrc:/home/${BUILD_UNAME}/.bashrc:ro" \
		--volume "${BUILD_CONTAINER_CONTEXT}/.bash_aliases:/home/${BUILD_UNAME}/.bash_aliases:ro" \
		--volume "${CURDIR}/init-firewall-extra.txt:/usr/local/etc/init-firewall-extra.txt:ro" \
# end PROJECT_MOUNTS

run-setup:
	@mkdir -p "${BUILD_CONTAINER_CONTEXT}"
	@mkdir -p "${PROJECT_WORKSPACE}"
	@if [[ ! -f "${BUILD_CONTAINER_CONTEXT}/.bashrc" ]] && \
	    [[ -f "${HOME}/.bashrc" ]]; then \
			printf "\n" "initalize .bashrc" && \
			cp "${HOME}/.bashrc" "${BUILD_CONTAINER_CONTEXT}/.bashrc" ; \
	fi
	@if [[ ! -f "${BUILD_CONTAINER_CONTEXT}/.bash_aliases" ]] && \
	    [[ -f "${HOME}/.bash_aliases" ]] ; then \
		printf "\n" "initalize .bash_aliases" && \
		cp "${HOME}/.bash_aliases" "${BUILD_CONTAINER_CONTEXT}/.bash_aliases" ; \
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
