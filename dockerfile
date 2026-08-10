# syntax=docker/dockerfile:1

# Build this image ON THE UNRAID HOST so GGML_NATIVE targets the
# Intel Core Ultra 7 255H rather than the Mac or a GitHub Actions runner.
FROM debian:bookworm AS builder

ARG LLAMA_CPP_REF=master

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    glslc \
    libvulkan-dev \
    ninja-build \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone https://github.com/ggml-org/llama.cpp.git . \
 && git checkout "${LLAMA_CPP_REF}"

# Native x86 CPU optimization + Vulkan for the Intel Arc 140T iGPU.
# No Intel NPU build flag: llama.cpp does not use the NPU usefully for GGUF serving.
RUN cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DGGML_VULKAN=ON \
    -DLLAMA_BUILD_TESTS=OFF \
 && cmake --build build --parallel "$(nproc)"


FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/build/bin/ /opt/llama/bin/

ENV PATH="/opt/llama/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/llama/bin"

EXPOSE 8090

ENTRYPOINT ["llama-server"]