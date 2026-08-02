FROM runpod/worker-comfyui:5.8.6-base

# UV_LINK_MODE=copy evita el bug de hardlinks de uv que rompe paquetes entre capas de Docker.
ENV UV_LINK_MODE=copy

# Instalo el nodo clonando directo de GitHub — comfy-node-install depende del catálogo online
# (registry.comfy.org), que estuvo fallando de forma intermitente.
RUN (command -v git || (apt-get update && apt-get install -y --no-install-recommends git)) \
    && git clone --depth 1 https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git \
    /comfyui/custom_nodes/seedvr2_videoupscaler \
    && /comfyui/.venv/bin/python -m pip install --no-cache-dir \
       -r /comfyui/custom_nodes/seedvr2_videoupscaler/requirements.txt
