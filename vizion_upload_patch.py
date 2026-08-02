
# ─────────────────────────────────────────────────────────────────────────────
# VIZION UPSCALE — override de upload_image (se appendea a rp_upload.py)
#
# Por qué: RunPod corta la salida de un job async en 10MB. Un PNG 4K pesa 15-25MB
# y uno 8K supera los 60MB, así que la salida se descartaba y el job volvía
# "COMPLETED" sin imagen. Subimos directo a Supabase y devolvemos la URL pública.
#
# Por qué acá y no en sitecustomize.py: sitecustomize se ejecuta al arrancar
# CUALQUIER proceso de Python, antes de que CUDA se inicialice. Importar boto3 y el
# SDK de RunPod ahí rompía torch ("GPU is not available or incompatible with this
# PyTorch build") y tiraba los workers por OOM. Appendeado a este módulo, el código
# corre solo cuando el handler importa rp_upload, que es justo cuando hace falta.
# ─────────────────────────────────────────────────────────────────────────────
import os as _vz_os


def _vizion_upload_image(job_id, image_location, result_index=0, results_list=None):
    endpoint = _vz_os.environ.get("VIZION_S3_ENDPOINT")
    if not endpoint:  # sin config, comportamiento original
        return _vizion_original_upload_image(job_id, image_location, result_index, results_list)

    import boto3
    from botocore.config import Config as _VzConfig

    bucket = _vz_os.environ.get("VIZION_BUCKET", "upscale")
    public = _vz_os.environ.get("VIZION_PUBLIC_BASE", "").rstrip("/")
    key = f"{job_id}_{result_index}.png" if result_index else f"{job_id}.png"

    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        region_name=_vz_os.environ.get("VIZION_S3_REGION", "us-east-1"),
        aws_access_key_id=_vz_os.environ["VIZION_S3_KEY_ID"],
        aws_secret_access_key=_vz_os.environ["VIZION_S3_SECRET"],
        config=_VzConfig(signature_version="s3v4", retries={"max_attempts": 3, "mode": "standard"}),
    )
    with open(image_location, "rb") as _fh:
        client.put_object(
            Bucket=bucket,
            Key=key,
            Body=_fh,
            ContentType="image/png",
            CacheControl="public, max-age=31536000, immutable",
        )

    url = f"{public}/{bucket}/{key}"
    print(f"[vizion] subido a Supabase: {url}", flush=True)
    if results_list is not None:
        results_list[result_index] = url
    return url


_vizion_original_upload_image = upload_image  # noqa: F821  (definido arriba en este módulo)
upload_image = _vizion_upload_image
