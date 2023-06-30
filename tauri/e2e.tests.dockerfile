# docker build -f docker/tauri/e2e.tests.dockerfile -t throwaway .
# This dockerfile assumes you're using pnpm and node.js 20
# You can either change the ARGs here at the top of the file, or you can pass them as arguments when you run the command
# Also, in its current state, it assumes your project structure places your Tauri "src-tauri" in e.g. "crates/my_backend"
# You should have a wdio.conf.js to configure your testing as well
  
ARG CRATE=YOUR_CRATE_HERE
ARG TAURI_DEPENDENCIES="build-essential curl libappindicator3-dev libgtk-3-dev librsvg2-dev libssl-dev libwebkit2gtk-4.1-dev wget libappimage-dev"
ARG EXTRA_DEPENDENCIES="webkit2gtk-driver xvfb"
ARG PNPM_VERSION="8.6.5"

FROM rust:1.70-slim-bookworm AS chef
WORKDIR /app
ARG TAURI_DEPENDENCIES
ARG EXTRA_DEPENDENCIES
ARG PNPM_VERSION
RUN apt update \
    && apt install -yq ${TAURI_DEPENDENCIES} \
    && apt install -yq git openssh-client libssl-dev pkg-config ${EXTRA_DEPENDENCIES} \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt install -yq nodejs \
    && corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && pnpm config set store-dir /usr/.pnpm-store \
    && cargo install cargo-chef tauri-driver

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
ARG CRATE
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --tests -p ${CRATE}
COPY . .
RUN cargo test -p ${CRATE}
RUN ln -s /usr/local/cargo $HOME/.cargo
WORKDIR /app/crates/${CRATE}
RUN pnpm i
RUN xvfb-run pnpm test

FROM scratch
COPY --from=builder /app/recipe.json recipe.json
