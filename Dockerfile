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

FROM oven/bun:1.4.4 AS build

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

# Headless Chromium used by the build step that pre-renders demo shaders.
RUN bunx playwright install --with-deps chromium

RUN bun run build

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 80
