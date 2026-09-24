FROM docker/sandbox-templates:copilot

USER root

COPY container-entrypoint.sh /usr/local/bin/copilot-sandbox-entrypoint

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-client \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install MySQL MCP server
COPY packages/mysql-mcp-server_1.7.1_linux_arm64.tar.gz /tmp/mysql-mcp-server.tar.gz

RUN mkdir -p /tmp/mysql-mcp \
    && tar -xzf /tmp/mysql-mcp-server.tar.gz -C /tmp/mysql-mcp \
    && find /tmp/mysql-mcp -type f -name 'mysql-mcp-server' -exec cp {} /usr/local/bin/mysql-mcp-server \; \
    && chmod +x /usr/local/bin/mysql-mcp-server \
    && rm -rf /tmp/mysql-mcp /tmp/mysql-mcp-server.tar.gz \
    && /usr/local/bin/mysql-mcp-server --version

# Install AWS DocumentDB MCP server
# Install AWS DocumentDB MCP server

USER agent
RUN uv tool install 'awslabs.documentdb-mcp-server>=1.0.12' \
    && /home/agent/.local/bin/awslabs.documentdb-mcp-server --help
USER root

# AWS DocumentDB TLS certificate
COPY packages/global-bundle.pem /etc/ssl/certs/global-bundle.pem
RUN chmod 644 /etc/ssl/certs/global-bundle.pem

RUN mkdir -p /home/agent/workspace /home/agent/.copilot \
    && printf '%s\n' \
        '#!/bin/sh' \
        'exec /usr/local/bin/uv tool run "$@"' \
        > /usr/local/bin/uvx \
    && chmod +x /usr/local/bin/uvx /usr/local/bin/copilot-sandbox-entrypoint \
    && chown -R agent:agent /home/agent

WORKDIR /home/agent/workspace

ENTRYPOINT ["/usr/local/bin/copilot-sandbox-entrypoint"]
CMD ["copilot"]