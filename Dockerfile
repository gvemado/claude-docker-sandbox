FROM docker/sandbox-templates:copilot

USER root

COPY claude-sandbox-entrypoint.sh /usr/local/bin/claude-sandbox-entrypoint

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

USER agent
RUN uv tool install 'awslabs.documentdb-mcp-server>=1.0.12' \
    && /home/agent/.local/bin/awslabs.documentdb-mcp-server --help

# Install Claude Code as the unprivileged runtime user.  Its configuration and
# credentials are supplied at runtime through the host's ~/.claude directory.
RUN npm install -g @anthropic-ai/claude-code \
    && claude --version
USER root

# AWS DocumentDB TLS certificate
COPY packages/global-bundle.pem /etc/ssl/certs/global-bundle.pem
RUN chmod 644 /etc/ssl/certs/global-bundle.pem

RUN mkdir -p /home/agent/workspace /home/agent/.claude \
    && printf '%s\n' \
        '#!/bin/sh' \
        'exec /usr/local/bin/uv tool run "$@"' \
        > /usr/local/bin/uvx \
    && chmod +x /usr/local/bin/uvx /usr/local/bin/claude-sandbox-entrypoint \
    && chown -R agent:agent /home/agent

ENV PATH="/home/agent/.local/bin:/usr/local/share/npm-global/bin:${PATH}"

WORKDIR /home/agent/workspace

ENTRYPOINT ["/usr/local/bin/claude-sandbox-entrypoint"]
CMD ["claude", "--dangerously-skip-permissions"]
