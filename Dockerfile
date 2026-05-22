FROM pytorch/pytorch:2.9.1-cuda12.8-cudnn9-runtime

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt

RUN pip install -U pip && \
    pip install -r /app/requirements.txt

COPY scripts/bootstrap.sh /app/scripts/bootstrap.sh

RUN chmod +x /app/scripts/bootstrap.sh

CMD ["/app/scripts/bootstrap.sh"]
