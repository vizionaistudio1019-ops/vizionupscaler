"""
Vizion Upscale — sube el resultado directo a Supabase Storage.

Por qué: RunPod tiene un tope de 10MB para la salida de un job async. Un PNG de 4K
pesa 15-25MB y uno de 8K supera los 60MB, así que la salida se descartaba en silencio
y el job volvía "COMPLETED" sin imagen.

Cómo: worker-comfyui llama a rp_upload.upload_image(job_id, path) cuando existe
BUCKET_ENDPOINT_URL. Reemplazamos esa función por una que sube a Supabase Storage
(S3-compatible) y devuelve la URL pública permanente. Así la imagen nunca viaja por
n8n — que corre en un server de 4GB y ya se quedó sin memoria dos veces.

Python importa sitecustomize automáticamente al arrancar, así que no hace falta
tocar el handler de upstream (menos drift con el repo original).

Env necesarias:
  BUCKET_ENDPOINT_URL      -> cualquier valor no vacío; activa la rama S3 del handler
  VIZION_S3_ENDPOINT       -> https://<ref>.storage.supabase.co/storage/v1/s3
  VIZION_S3_REGION         -> región del proyecto Supabase (ej: eu-central-1)
  VIZION_S3_KEY_ID         -> access key id (Storage → S3 Access Keys)
  VIZION_S3_SECRET         -> secret access key
  VIZION_PUBLIC_BASE       -> https://<ref>.supabase.co/storage/v1/object/public
  VIZION_BUCKET            -> bucket destino (default: upscale)
"""
import os

if os.environ.get("VIZION_S3_ENDPOINT"):
    try:
        import boto3
        from botocore.config import Config
        from runpod.serverless.utils import rp_upload

        _BUCKET = os.environ.get("VIZION_BUCKET", "upscale")
        _PUBLIC = os.environ.get("VIZION_PUBLIC_BASE", "").rstrip("/")

        def _vizion_upload_image(job_id, image_location, result_index=0, results_list=None):
            key = f"{job_id}_{result_index}.png" if result_index else f"{job_id}.png"

            client = boto3.client(
                "s3",
                endpoint_url=os.environ["VIZION_S3_ENDPOINT"],
                region_name=os.environ.get("VIZION_S3_REGION", "us-east-1"),
                aws_access_key_id=os.environ["VIZION_S3_KEY_ID"],
                aws_secret_access_key=os.environ["VIZION_S3_SECRET"],
                config=Config(signature_version="s3v4", retries={"max_attempts": 3, "mode": "standard"}),
            )
            with open(image_location, "rb") as fh:
                client.put_object(
                    Bucket=_BUCKET,
                    Key=key,
                    Body=fh,
                    ContentType="image/png",
                    CacheControl="public, max-age=31536000, immutable",
                )

            url = f"{_PUBLIC}/{_BUCKET}/{key}"
            print(f"[vizion] subido a Supabase: {url}", flush=True)
            if results_list is not None:
                results_list[result_index] = url
            return url

        rp_upload.upload_image = _vizion_upload_image
        print("[vizion] rp_upload.upload_image -> Supabase Storage", flush=True)
    except Exception as exc:  # nunca romper el arranque del worker por esto
        print(f"[vizion] no se pudo aplicar el patch de upload: {exc}", flush=True)
