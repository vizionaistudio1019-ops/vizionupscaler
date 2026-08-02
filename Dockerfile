FROM runpod/worker-comfyui:5.8.6-base

# ⚠️ La imagen base tiene DOS venvs: comfy-node-install instala en /comfyui/.venv, pero
# ComfyUI corre desde /opt/venv (es lo que está en el PATH). Instalar en el venv equivocado
# hacía que el build pasara y el nodo fallara en runtime con "No module named 'diffusers'".
ENV UV_LINK_MODE=copy

# Clono el nodo directo de GitHub (comfy-node-install depende de registry.comfy.org, que falló
# de forma intermitente) e instalo sus deps en el venv que ComfyUI realmente usa.
RUN git clone --depth 1 https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git \
      /comfyui/custom_nodes/seedvr2_videoupscaler \
    && uv pip install --python /opt/venv/bin/python \
       -r /comfyui/custom_nodes/seedvr2_videoupscaler/requirements.txt

# Assertion de build: si las deps no importan desde el venv real, el build falla acá y no
# descubrimos el problema recién al correr un job.
RUN /opt/venv/bin/python -c "import diffusers, omegaconf, rotary_embedding_torch; print('deps OK')"
