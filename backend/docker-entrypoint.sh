#!/bin/sh
# Start the Rasa server with run-time security settings.
#
# CORS and the auth token are deliberately NOT baked into the image. The
# development default of `--cors "*"` with no authentication is fine on a
# laptop and is not something a published image should carry, so both are
# supplied by the environment and the container refuses to start wide open
# unless told to.
set -eu

ARGS="run --enable-api --port 5005 --model /app/models/healthbot.tar.gz --endpoints endpoints.docker.yml --credentials credentials.docker.yml"

if [ -n "${RASA_CORS:-}" ]; then
    ARGS="$ARGS --cors ${RASA_CORS}"
fi

if [ -n "${RASA_AUTH_TOKEN:-}" ]; then
    ARGS="$ARGS --auth-token ${RASA_AUTH_TOKEN}"
elif [ "${RASA_ALLOW_UNAUTHENTICATED:-false}" != "true" ]; then
    echo "ERROR: RASA_AUTH_TOKEN is not set." >&2
    echo "The REST webhook would accept requests from anyone who can reach this" >&2
    echo "port. Set RASA_AUTH_TOKEN, or set RASA_ALLOW_UNAUTHENTICATED=true to" >&2
    echo "run without it on a trusted network." >&2
    exit 1
fi

if [ -n "${RASA_LOG_LEVEL:-}" ]; then
    ARGS="$ARGS --log-level ${RASA_LOG_LEVEL}"
fi

# shellcheck disable=SC2086
exec rasa $ARGS "$@"
