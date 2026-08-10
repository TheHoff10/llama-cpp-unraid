# syntax=docker/dockerfile:1

# Build on the Unraid host so GGML_NATIVE targets the actual
# Intel Core Ultra 7 255H rather than a Mac or GitHub Actions runner.
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LLAMA_CPP_REF=master

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    glslang-tools \
    glslc \
    libvulkan-dev \
    ninja-build \
    pkg-config \
    spirv-headers \
    spirv-tools \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone https://github.com/ggml-org/llama.cpp.git . \
 && git checkout "${LLAMA_CPP_REF}"

# Native CPU build for the Core Ultra 7 255H plus Vulkan for its Arc 140T iGPU.
# The Intel NPU is deliberately not targeted; it is not a practical llama.cpp
# GGUF-serving backend.
RUN cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DGGML_VULKAN=ON \
    -DLLAMA_BUILD_TESTS=OFF \
 && cmake --build build --parallel "$(nproc)" \
 && cmake --install build --prefix /opt/llama


FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/llama/ /opt/llama/

RUN for binary in /opt/llama/bin/llama-server /opt/llama/bin/llama-bench; do \
      echo "Checking ${binary}"; \
      ldd "${binary}"; \
      ! ldd "${binary}" | grep -q "not found"; \
    done

ENV PATH="/opt/llama/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/llama/lib"

EXPOSE 8090

ENTRYPOINT ["llama-server"]