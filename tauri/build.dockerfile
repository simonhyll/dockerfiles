# docker build -f docker/tauri/build.dockerfile -o out .
######################
# Base
# Base dependencies for all images
######################
FROM node:20-bullseye-slim AS base
WORKDIR /app

# Ensure rustup/cargo is in the path
ENV PATH="/root/.cargo/bin:${PATH}"

# Arguments
ARG PNPM_VERSION="8.6.0"
ARG TAURI_DEPENDENCIES="libgtk-3-dev libwebkit2gtk-4.0-dev libappindicator3-dev librsvg2-dev patchelf libxss-dev"

# Install dependencies
RUN apt update \
    # General build stuff
    && apt install -y wget curl libssl-dev pkg-config build-essential ${TAURI_DEPENDENCIES} \
    # Install rust
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustup update \
    && mkdir -p src-tauri/.cargo \
    && echo '[registries.crates-io]\n\
    protocol = "sparse"\n'\
    >> src-tauri/.cargo/config.toml

######################
# Chef
# Installs cargo-chef
######################
FROM base AS chef
WORKDIR /app

RUN cargo install cargo-chef

######################
# Planner
# Prepares the recipe for the builder image
######################
FROM chef AS planner
COPY . .
RUN cd src-tauri && cargo chef prepare --recipe-path recipe.json

######################
# Builder
# Builds the dependencies
######################
FROM chef AS builder
COPY --from=planner /app/src-tauri/recipe.json recipe.json
RUN cargo chef cook --release

######################
# Final
######################
FROM base as final
WORKDIR /app

# Install PNPM
RUN corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && pnpm config set store-dir /usr/.pnpm-store

# Cache PNPM dependencies
COPY pnpm-lock.yaml .npmrc ./
RUN pnpm fetch

# Copy source code
COPY . .

# Install dependencies
RUN pnpm install -r --offline 

# Copy over the cached Rust dependencies
COPY --from=builder /app/target src-tauri/target

# Build
RUN pnpm tauri build

######################
# Bundle
# Bundles the final binary
######################
FROM scratch
COPY --from=final /app/src-tauri/target/release/bundle /bundle
