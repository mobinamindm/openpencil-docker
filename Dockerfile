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
FROM oven/bun:1.4.2 AS build

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

# registry.npmjs.org is slow/unreliable from this datacenter; npmmirror serves
# identical npm tarballs and is consistently fast here.
RUN bun install --frozen-lockfile --registry https://registry.npmmirror.com

# Playwright's default CDN (cdn.playwright.dev) geo-blocks this datacenter's
# IP range (HTTP 403 "not available in your location"). npmmirror serves the
# byte-identical browser builds, so point Playwright's downloader there.
ENV PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright
ENV PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT=180000

# Headless Chromium used by the build step that pre-renders demo shaders.
RUN bunx playwright install --with-deps chromium

# Debian's nodejs (20.19+/22+) for running Vite itself.
RUN apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# tsdown lists `unrun` as an *optional* peer dependency. Bun does not install
# optional peers (and its on-the-fly auto-install is not reliable inside a build),
# so tsdown would fail with "Failed to import module 'unrun'". Pin it explicitly.
RUN bun add --dev unrun --registry https://registry.npmmirror.com

# `bun run build` also runs the repo's full type-aware oxlint pass, which is a CI
# concern (RAM-hungry, and crashes Bun on small builders); we build package
# artifacts + the web bundle only, and upstream CI lints every release anyway.
#
# Vite MUST run on real Node: its `vite` bin carries a Node shebang (that is how
# upstream CI runs it), and forcing Bun's runtime (bunx) breaks Vite 8's config
# loader with "Cannot find package 'vite-module-runner:import-meta-resolve'".
RUN bun run build:packages && "$(command -v node || command -v nodejs)" ./node_modules/vite/bin/vite.js build

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 80
