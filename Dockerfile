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

# ⚠️ Los pesos (17GB) viven en el Network Volume, pero el nodo SeedVR2 los busca SIEMPRE en
# /comfyui/models/SEEDVR2 (ruta hardcodeada, ignora extra_model_paths.yaml). Sin este symlink
# el nodo no los encuentra y se los baja de HuggingFace en cada worker nuevo: lento (~9 min),
# caro en ancho de banda y frágil — el 2026-08-03 HF empezó a limitar a 145kB/s y el job
# falló tras 13 min. El symlink queda colgando en build (el volumen no está montado todavía)
# y se resuelve al arrancar el worker.
RUN mkdir -p /comfyui/models \
    && rm -rf /comfyui/models/SEEDVR2 \
    && ln -s /runpod-volume/runpod-slim/ComfyUI/models/SEEDVR2 /comfyui/models/SEEDVR2

# Override de upload_image: appendeado al final del módulo rp_upload, así corre solo cuando
# el handler lo importa. (En sitecustomize.py rompía torch y tiraba los workers por OOM.)
COPY vizion_upload_patch.py /tmp/vizion_upload_patch.py
RUN cat /tmp/vizion_upload_patch.py >> /opt/venv/lib/python3.12/site-packages/runpod/serverless/utils/rp_upload.py \
    && rm /tmp/vizion_upload_patch.py

# Assertions de build: si algo de esto no se cumple, el build falla acá y no lo descubrimos
# recién con un worker crasheando en producción.
RUN /opt/venv/bin/python -c "import diffusers, omegaconf, rotary_embedding_torch; print('deps OK')" \
 && /opt/venv/bin/python -c "\
from runpod.serverless.utils import rp_upload; \
assert rp_upload.upload_image.__name__ == '_vizion_upload_image', rp_upload.upload_image; \
print('patch de upload OK')" \
 && /opt/venv/bin/python -c "\
import sys; assert 'torch' not in sys.modules; print('arranque limpio: torch no se importa antes de tiempo')" \
 && /opt/venv/bin/python -c "\
import os; t=os.readlink('/comfyui/models/SEEDVR2'); \
assert t=='/runpod-volume/runpod-slim/ComfyUI/models/SEEDVR2', t; \
print('symlink de pesos OK ->', t)"
