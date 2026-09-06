ARG BASE_IMAGE=
# mcr.microsoft.com/devcontainers/base:2-jammy, pinned by multi-architecture
# manifest digest (linux/amd64, linux/arm64) so the tag cannot move underneath
# a reviewed configuration. Resolve a replacement from the publisher's own
# registry metadata, not from a local pull.
FROM ${BASE_IMAGE:-mcr.microsoft.com/devcontainers/base@sha256:55126de3b3e113096201055951b4cb717900bafb379c59dcbada65c49cd7ce22}

ARG NPM_CONFIG_REGISTRY=
ENV NPM_CONFIG_REGISTRY=${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org/}

ARG PIP_INDEX_URL=
ENV PIP_INDEX_URL=${PIP_INDEX_URL:-https://pypi.org/simple/}

ARG UV_DEFAULT_INDEX=
ENV UV_DEFAULT_INDEX=${UV_DEFAULT_INDEX:-https://pypi.org/simple}
