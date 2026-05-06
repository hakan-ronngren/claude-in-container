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

# Create user 'claude' with passwordless sudo
RUN useradd -m -s /bin/bash claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude

ENV HOME=/home/claude
ENV PATH="/home/claude/.local/bin:$PATH"
ENV TEST_HOST=host.docker.internal

USER claude
WORKDIR /home/claude
ENTRYPOINT ["/bin/bash"]
