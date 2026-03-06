FROM debian:bookworm-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    gh \
    git \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user 'me' with bash as default shell
RUN useradd -m -s /bin/bash me

# Switch to user 'me'
USER me
WORKDIR /home/me

# Install nvm
ENV NVM_DIR=/home/me/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Install a default Node.js LTS version (needed for Claude Code and pnpm)
# Users can install additional versions using nvm based on .nvmrc in their projects
RUN . "$NVM_DIR/nvm.sh" && nvm install --lts && nvm use --lts

# Install pnpm globally
RUN . "$NVM_DIR/nvm.sh" && npm install -g pnpm

# Install Claude Code CLI using the native installer
RUN curl -fsSL https://claude.ai/install.sh | bash

# Configure bash to load nvm and add .local/bin to PATH
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc \
    && echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use' >> ~/.bash_profile

# Set TEST_HOST environment variable to reach host services
ENV TEST_HOST=host.docker.internal

# Add .local/bin to PATH for claude command
ENV PATH="/home/me/.local/bin:$PATH"

# Set HOME to user 'me' home directory
ENV HOME=/home/me

# Run as user 'me' by default
USER me

# Set bash as the default shell
ENTRYPOINT ["/bin/bash"]
