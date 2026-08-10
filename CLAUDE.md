# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single multi-stage `dockerfile` that builds [llama.cpp](https://github.com/ggml-org/llama.cpp) from source and packages `llama-server` into a slim runtime image, for deployment on an Unraid host. There is no application source code here — llama.cpp is cloned fresh from upstream at build time.

## Build

```
docker build -t llama-cpp-unraid -f dockerfile .
```

- **Must be built on the target Unraid host itself**, not on a Mac or in CI (e.g. GitHub Actions). The build uses `GGML_NATIVE=ON`, which compiles CPU optimizations for the exact machine doing the build. Building elsewhere produces a binary tuned for the wrong CPU.
- The `LLAMA_CPP_REF` build arg pins the llama.cpp git ref to check out (defaults to `master`): `--build-arg LLAMA_CPP_REF=<tag-or-commit>`.
- The target hardware is an Intel Core Ultra 7 255H with an Intel Arc 140T iGPU. `GGML_VULKAN=ON` enables GPU offload via Vulkan against that iGPU. There is intentionally no NPU build flag — llama.cpp doesn't make useful use of the NPU for GGUF serving, so don't add one.

## Runtime image

- Runtime stage is `debian:bookworm-slim` with only `libvulkan1`, `mesa-vulkan-drivers`, and `vulkan-tools` installed — no build toolchain, no copied source, just `/opt/llama/bin/` (llama.cpp's built `bin/` output) on `PATH`.
- `ENTRYPOINT` is `llama-server`; the container listens on port 8090 (`EXPOSE 8090`). Pass `llama-server` CLI flags (model path, host/port, context size, etc.) as `docker run` arguments — none are baked into the image.
- `models/` and `*.gguf` are gitignored — GGUF model weights are expected to be mounted into the container at runtime, not committed or baked into the image.

## Making changes

When editing the Dockerfile, preserve the two-stage split (builder vs. runtime) so the final image doesn't carry build tools or the llama.cpp source tree. If you add new build dependencies to the builder stage, check whether the runtime stage also needs a corresponding shared library.
