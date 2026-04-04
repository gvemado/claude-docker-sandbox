FROM docker/sandbox-templates:copilot

USER root

COPY container-entrypoint.sh /usr/local/bin/copilot-sandbox-entrypoint

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/agent/workspace /home/agent/.copilot \
    && printf '%s\n' '#!/bin/sh' 'exec /usr/local/bin/uv tool run "$@"' > /usr/local/bin/uvx \
    && chmod +x /usr/local/bin/uvx /usr/local/bin/copilot-sandbox-entrypoint \
    && chown -R agent:agent /home/agent

WORKDIR /home/agent/workspace

ENTRYPOINT ["/usr/local/bin/copilot-sandbox-entrypoint"]
CMD ["copilot"]
