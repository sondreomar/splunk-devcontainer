FROM ghcr.io/astral-sh/uv:bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
ENV UV_PYTHON_INSTALL_DIR=/python
ENV UV_PYTHON_PREFERENCE=only-managed

RUN uv python install 3.9

FROM ghcr.io/sondreomar/splunk-devcontainer:latest-uf

COPY --from=builder /python /python

RUN ln -sf /python/cpython-3.9.*/bin/python3.9 /usr/local/bin/python3.9
