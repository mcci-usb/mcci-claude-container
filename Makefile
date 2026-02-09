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
#   See LICENSE.md for license information.
#
# Author:
#   Terry Moore, MCCI Corporation   February 2026
#
# Revision History:
#   0.1.0  Wed Feb 04 2026 23:10:08  tmm
#       Module created.
#
##############################################################################

SHELL := /bin/bash

MCCI_CLAUDE_CONTAINER_VERSION=v0.1.0
MCCI_CLAUDE_CONTAINER_LOCAL_TAG=mcci-claude-container

# For pushing, require explicit repo (no default)
# MCCI_CLAUDE_CONTAINER_REPO must be set to push, e.g.:
#   make push MCCI_CLAUDE_CONTAINER_REPO=ghcr.io/mcci-usb/mcci-claude-container

# defaults
BUILD_UNAME ?= ${LOGNAME}
BUILD_UID ?= $(shell grep '^${LOGNAME}:' /etc/passwd | cut -d: -f3)
$(message BUILD_UID: ${BUILD_UID})
BUILD_GECOS ?= $(shell grep '^${LOGNAME}:' /etc/passwd | cut -d: -f5 | cut -d, -f1)
BUILD_GID ?= $(shell grep '^${LOGNAME}:' /etc/passwd | cut -d: -f4)
BUILD_GNAME ?= $(shell getent group ${BUILD_GID} | cut -d: -f1)
BUILD_USER_EMAIL ?= $(shell git config --global user.email)

build:	Dockerfile
	cd $(dir Dockerfile)
	docker build \
		-t ${MCCI_CLAUDE_CONTAINER_LOCAL_TAG}:latest \
		-t ${MCCI_CLAUDE_CONTAINER_LOCAL_TAG}:${MCCI_CLAUDE_CONTAINER_VERSION} \
		$(if ${MCCI_CLAUDE_CONTAINER_REPO},-t ${MCCI_CLAUDE_CONTAINER_REPO}:latest) \
		$(if ${MCCI_CLAUDE_CONTAINER_REPO},-t ${MCCI_CLAUDE_CONTAINER_REPO}:${MCCI_CLAUDE_CONTAINER_VERSION}) \
		--build-arg USER_ID=${BUILD_UID} \
		--build-arg USER_NAME=${BUILD_UNAME} \
		--build-arg GROUP_ID=${BUILD_GID} \
		--build-arg GROUP_NAME=${BUILD_GNAME} \
		--build-arg USER_GECOS="${BUILD_GECOS}" \
		--build-arg USER_EMAIL="${BUILD_USER_EMAIL}" \
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
		--volume "${CURDIR}/init-firewall-extra-domains.conf:/usr/local/etc/init-firewall-extra-domains.conf:ro" \
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
			printf "%s\n" "initalize .bashrc" && \
			cp "${HOME}/.bashrc" "${PROJECT_CONTEXT}/.bashrc" ; \
	fi
	@if [[ ! -f "${PROJECT_CONTEXT}/.bash_aliases" ]] && \
	    [[ -f "${HOME}/.bash_aliases" ]] ; then \
		printf "%s\n" "initalize .bash_aliases" && \
		cp "${HOME}/.bash_aliases" "${PROJECT_CONTEXT}/.bash_aliases" ; \
	fi
	@if [[ ! -f "${PROJECT_CONTEXT}/.bash_history" ]] ; then \
		printf "%s\n" "initalize empty .bash_history" && \
		touch "${PROJECT_CONTEXT}/.bash_history" ; \
	fi
	@if [[ ! -f "${PROJECT_CONTEXT}/.claude.json" ]] ; then \
		printf "%s\n" "initalize empty .claude.json" && \
		touch "${PROJECT_CONTEXT}/.claude.json" ; \
	fi
	@if [[ ! -f "${CURDIR}/init-firewall-extra-domains.conf" ]] ; then \
		printf "%s\n" "initalize empty init-firewall-extra-domains.conf" && \
		touch "${CURDIR}/init-firewall-extra-domains.conf" ; \
	fi

run:	run-setup
	docker run -it --rm \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		${PROJECT_MOUNTS} \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CLAUDE_CONTAINER_LOCAL_TAG} \
		bash --init-file /usr/local/bin/read-bashrc-init-firewall.sh

run-ssh: run-setup
	docker run -it --rm \
		--cap-add=NET_ADMIN \
		--cap-add=NET_RAW \
		--volume ${SSH_AUTH_SOCK}:/ssh_agent --env SSH_AUTH_SOCK=/ssh_agent \
		${PROJECT_MOUNTS} \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CLAUDE_CONTAINER_LOCAL_TAG} \
		bash --init-file /usr/local/bin/read-bashrc-init-firewall.sh

run-ssh-nofw: run-setup
	docker run -it --rm \
		--volume ${SSH_AUTH_SOCK}:/ssh_agent --env SSH_AUTH_SOCK=/ssh_agent \
		${PROJECT_MOUNTS} \
		--memory-swap=-1 \
		--ulimit core=-1 \
		${MCCI_CLAUDE_CONTAINER_LOCAL_TAG} \
		bash

push:
	@if [ -z "${MCCI_CLAUDE_CONTAINER_REPO}" ]; then \
		echo "ERROR: you must set MCCI_CLAUDE_CONTAINER_REPO before pushing"; \
		echo "  e.g.: make push MCCI_CLAUDE_CONTAINER_REPO=ghcr.io/mcci-usb/mcci-claude-container"; \
		exit 1; \
	fi
	@bash -c 'if [[ "${MCCI_CLAUDE_CONTAINER_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-.+)?$$ ]]; then \
		true; \
	else \
		echo "MCCI_CLAUDE_CONTAINER_VERSION must be of form v#.#.# or v#.#.#-pre#" ; \
		false; \
	fi'
	# tag before pushing to catch redundant operation
	git tag -a -m "Image ${MCCI_CLAUDE_CONTAINER_REPO}:${MCCI_CLAUDE_CONTAINER_VERSION}" "${MCCI_CLAUDE_CONTAINER_VERSION}"
	docker push ${MCCI_CLAUDE_CONTAINER_REPO}:latest
	docker push ${MCCI_CLAUDE_CONTAINER_REPO}:${MCCI_CLAUDE_CONTAINER_VERSION}

#### end of file ####
