# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile for vigra (C++ computer vision / image-processing library).
# Builds ON TOP of the org C/C++ base image (ghcr.io/mayhemheroes/base).
#
# Build (from the repo root):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) \
#       -t vigra-commit:test .

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (not ENV) — clang rejects empty value.
ARG SOURCE_DATE_EPOCH

# Sanitizer override: base exports SANITIZER_FLAGS (ASan+UBSan, halting) as default.
# Declare WITHOUT a default so the base ENV flows through to build.sh when not passed.
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# Install image format dev libs needed by vigra's impex (BMP/GIF/PNM built-in; rest optional).
# repro-sources-list.sh pins apt sources to SOURCE_DATE_EPOCH for reproducibility (from base).
USER root
RUN [ -n "$SOURCE_DATE_EPOCH" ] && repro-sources-list.sh || true ; \
    apt-get update && apt-get install -yq --no-install-recommends \
        libjpeg-dev libpng-dev libtiff-dev \
    && rm -rf /var/lib/apt/lists/*
USER mayhem

WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

# Run functional test suite at build time (a failing suite fails the image build).
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
