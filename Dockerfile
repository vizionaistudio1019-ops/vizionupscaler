FROM runpod/worker-comfyui:5.8.6-base

# UV_LINK_MODE=copy evita el bug de hardlinks de uv que rompe paquetes entre capas de Docker
# (causaba "ModuleNotFoundError: No module named 'diffusers'" en runtime, aunque el install
# se veía exitoso en el build).
ENV UV_LINK_MODE=copy

RUN comfy-node-install seedvr2_videoupscaler

# Reinstalo las deps del nodo con pip normal (no uv) directo en el venv de ComfyUI, para
# garantizar que persistan de verdad en la capa final.
RUN /comfyui/.venv/bin/python -m pip install --no-cache-dir \
    diffusers transformers accelerate peft rotary_embedding_torch omegaconf opencv-python gguf
