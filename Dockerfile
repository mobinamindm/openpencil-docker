# syntax=docker/dockerfile:1
#
# Builds the OpenPencil web app from source at a pinned release tag and
# serves the static build with nginx.
#
#   Source:  https://github.com/open-pencil/open-pencil (MIT)
#   Output:  /src/dist (Vite static SPA), served on :80
#
# Bump OPENPENCIL_REF to upgrade. The build needs a headless Chromium because
# the demo document's shader fills are pre-rendered at build time.

# Pin the exact Bun build upstream uses (devcontainer .devcontainer/Dockerfile digest,
# bun 1.4.2, also the repo's packageManager pin). Newer Bun (1.4.4) breaks Vite's
# config loader with a 'vite-module-runner:import-meta-resolve' resolution error.
FROM oven/bun@sha256:9114c0580f1d939c4c8e2c968a3646ce7aebf6ee211c56f88d9239b97ea46fab AS build

ENV DEBIAN_FRONTEND=noninteractive

# git + git-lfs for cloning (the repo uses Git LFS)
RUN apt-get update \
 && apt-get install -y --no-install-recommends git git-lfs ca-certificates \
 && git lfs install --system \
 && rm -rf /var/lib/apt/lists/*

ARG OPENPENCIL_REF=v0.16.0

WORKDIR /src
RUN git clone --depth 1 --branch "${OPENPENCIL_REF}" \
        https://github.com/open-pencil/open-pencil.git .

RUN bun install --frozen-lockfile

# Playwright's default CDN (cdn.playwright.dev) geo-blocks this datacenter's
# IP range (HTTP 403 "not available in your location"). npmmirror serves the
# byte-identical browser builds, so point Playwright's downloader there.
ENV PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
ENV PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=180000

# Headless Chromium used by the build step that pre-renders demo shaders.
RUN bunx playwright install --with-deps chromium

# `bun run build` also runs the repo's full type-aware oxlint pass, which is a CI
# concern: it is extremely RAM-hungry and crashes Bun on small builders. Build the
# package artifacts and the web bundle only; upstream CI lints every release anyway.
RUN bun run build:packages && bunx vite build

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 80
