# Development toolbox: Ruby, Node and pnpm in one container, so contributors
# do not need to install the toolchain on the host. Used by bin/toolbox.
FROM docker.io/library/node:24-bookworm-slim AS node

FROM docker.io/library/ruby:3.4.4-bookworm

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack \
  && corepack enable --install-directory /usr/local/bin pnpm

RUN apt-get update \
  && apt-get install -y --no-install-recommends libvips42 postgresql-client \
  && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/bundle \
    COREPACK_HOME=/bundle/corepack \
    PNPM_HOME=/bundle/pnpm \
    XDG_CACHE_HOME=/bundle/cache

WORKDIR /app
