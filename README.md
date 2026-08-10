# llama-cpp-unraid

A Dockerfile that builds [llama.cpp](https://github.com/ggml-org/llama.cpp) for self-hosting local AI models on my Unraid server, running on a Ugreen iDX6011 Pro NAS (Intel Core Ultra 7 255H, Intel Arc 140T iGPU).

The NAS is shipped with the UGOS but I didn't find it served my purposes so I am running unRaid instead.  This is for those that would rather run unRaid, and this docker will allow you to host our own local LLM, taking advantage of the HW.

## What it does

- Builds `llama-server` from the latest llama.cpp source, compiled natively for the host CPU (`GGML_NATIVE=ON`).
- Enables Vulkan (`GGML_VULKAN=ON`) so inference can offload to the Arc 140T iGPU.
- Packages the result into a slim runtime image with just the Vulkan libraries needed to run it — no build tools, no source tree.
- Leveraging the NPU is specifically left out here. The intention is to enable NPU support later, specifically for specific OCR models for OCR abilities.

## Build

Because the build uses `GGML_NATIVE=ON`, it compiles CPU optimizations for whatever machine runs `docker build`. **Build this image on the Unraid server itself**, not on your laptop or in CI, or the binary will be tuned for the wrong CPU.

```bash
docker build -t llama-cpp-unraid -f dockerfile .
```

Optionally pin a specific llama.cpp version instead of `master`:

```bash
docker build -t llama-cpp-unraid -f dockerfile --build-arg LLAMA_CPP_REF=<tag-or-commit> .
```

## Run

```bash
docker run -d \
  --name llama-cpp \
  -p 8090:8090 \
  --device /dev/dri \
  -v /path/to/your/models:/models \
  llama-cpp-unraid \
  -m /models/your-model.gguf --host 0.0.0.0 --port 8090
```

- `--device /dev/dri` passes through the iGPU for Vulkan.
- Mount a directory containing your `.gguf` model files to `/models` (or wherever you like).
- Any `llama-server` flags can be appended after the image name — nothing is hardcoded except the entrypoint and exposed port.

On Unraid, this translates to setting the repository to your built image, adding a port mapping (8090 → 8090), a path mapping for your models directory, and passing the same flags via the container's extra parameters / post arguments.
