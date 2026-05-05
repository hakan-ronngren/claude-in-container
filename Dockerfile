FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    gh \
    git \
    jq \
    make \
    sudo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS system-wide via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code and pnpm globally
RUN npm install -g @anthropic-ai/claude-code

# Create user 'me' with passwordless sudo
RUN useradd -m -s /bin/bash me \
    && echo 'me ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/me

ENV HOME=/home/me
ENV TEST_HOST=host.docker.internal

USER me
WORKDIR /home/me
ENTRYPOINT ["/bin/bash"]
