# Rasa NLU/dialogue server.
#
# The model is trained during the image build, so the image is a
# self-contained artefact: the same image always serves the same model, and
# there is no train-on-boot delay or shared volume to keep in sync.
#
#   docker build -t healthbot-rasa -f Dockerfile .
#
# This image carries TensorFlow and is large (~2 GB) — that is Rasa 3.6's
# floor, not something this project adds. The action server is a separate,
# much smaller image; see Dockerfile.actions.
FROM python:3.10-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=120 \
    PIP_RETRIES=10

WORKDIR /app

# Build tools are needed for some Rasa wheels and are dropped afterwards.
RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
# Retry the whole install, not just individual requests. Rasa pulls a ~500 MB
# TensorFlow wheel with a pinned hash; on an unreliable link the download can
# complete but arrive corrupted, which fails hash verification and is not
# something pip's own --retries recovers from. Three clean attempts is enough
# to ride out a bad transfer without masking a genuinely broken pin.
RUN for attempt in 1 2 3; do \
        echo "pip install attempt $attempt"; \
        pip install -r requirements.txt && break; \
        if [ "$attempt" = "3" ]; then \
            echo "pip install failed after 3 attempts" >&2; exit 1; \
        fi; \
        sleep 15; \
    done \
    && apt-get purge -y build-essential \
    && apt-get autoremove -y

# ---------------------------------------------------------------------------
# Train
# ---------------------------------------------------------------------------
FROM base AS trainer

COPY config.yml domain.yml ./
COPY data ./data

# --fixed-model-name keeps the path predictable for the runtime stage.
RUN rasa train --fixed-model-name healthbot --out /models

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM base AS runtime

# Never run the server as root.
RUN useradd --create-home --uid 10001 rasa

COPY config.yml domain.yml endpoints.docker.yml credentials.docker.yml ./
COPY data ./data
COPY --from=trainer /models/healthbot.tar.gz /app/models/healthbot.tar.gz
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Set the execute bit here rather than relying on the checkout: Windows clones
# do not preserve the POSIX permission, and the image would fail to start.
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && chown -R rasa:rasa /app
USER rasa

EXPOSE 5005

# RASA_AUTH_TOKEN and RASA_CORS are read by docker-entrypoint.sh from the
# run-time environment, so the same image serves development and production
# without a rebuild. They are deliberately NOT declared with ENV here: a value
# baked into an image layer is visible to anyone who can pull it, and `docker
# build` rightly warns about secrets in ENV. See docker-compose.yml.

# The root route is unauthenticated, so it works as a probe whether or not an
# auth token is configured.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -fsS http://localhost:5005/ || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
