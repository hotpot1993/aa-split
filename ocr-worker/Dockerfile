# 小票 OCR 微服务（RapidOCR + FastAPI）
FROM python:3.11-slim

WORKDIR /srv/ocr-worker

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    UPLOAD_MAX_BYTES=10485760

# rapidocr 依赖 opencv-python（带 GUI 依赖 libxcb/libgl），slim 镜像需补最小运行库
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libxcb1 libx11-6 libxext6 libsm6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app

# 构建期预下载 PP-OCRv5 mobile 模型（bake 进镜像，运行零外网依赖）
RUN rapidocr download_models --config app/config_ocr.yaml || echo "model pre-download skipped (will download at runtime)"

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
