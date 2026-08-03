# Vizion Upscale — RunPod Serverless worker

Imagen ComfyUI + nodo SeedVR2, para el endpoint Serverless del agente Vizion Upscale.

Base: `runpod/worker-comfyui:5.8.6-base` (oficial, mantenido por RunPod).
Agrega: `seedvr2_videoupscaler` (nodo custom de `numz/ComfyUI-SeedVR2_VideoUpscaler`).

Los pesos del modelo (17GB) NO están en esta imagen — viven en el Network Volume
de RunPod (`1nygk6t2ol`), montado automáticamente en `/runpod-volume/models/SEEDVR2`
cuando el volumen está attacheado al endpoint.

Conectado a RunPod vía GitHub Integration — cualquier push a `main` reconstruye
la imagen del endpoint automáticamente.

<!-- retry build 2026-08-03T15:47:22Z -->
