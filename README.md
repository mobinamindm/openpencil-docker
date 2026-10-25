# openpencil-docker

Container build for the [OpenPencil](https://openpencil.dev/) web app
([open-pencil/open-pencil](https://github.com/open-pencil/open-pencil), MIT).

The Dockerfile clones the upstream repository at a pinned release tag, builds
the static web app with Bun, and serves the result with nginx.

## Upgrade

Change `OPENPENCIL_REF` in the `Dockerfile` to another release tag
(see upstream releases) and rebuild.

## Run locally

```sh
docker build -t openpencil .
docker run --rm -p 8080:80 openpencil
```
