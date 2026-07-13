FROM debian:bookworm-slim

RUN apt update && apt install -y \
    bash \
    curl \
    gh \
    git \
    jq \
    make \
    sudo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN (type -p wget >/dev/null || (apt update && apt install wget -y)) \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install gh -y \
    && rm -rf /var/lib/apt/lists/*


# Install Node.js LTS system-wide via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Headless Chromium for Puppeteer-driven browser tests. Puppeteer's bundled
# Chrome is an x86_64 build that won't launch on this arm64 image, so use the
# distro's native browser and point Puppeteer at it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium \
    && rm -rf /var/lib/apt/lists/*
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PUPPETEER_SKIP_DOWNLOAD=1

# JDK 25 (latest LTS) for the Firebase Firestore/Auth emulators (they are Java
# processes). A current firebase-tools requires JDK 21+, which bookworm's own
# packages (default-jre and backports both cap at 17) don't provide, so install
# Adoptium Temurin's arm64 build from its apt repo. Building fetches from
# packages.adoptium.net — allow that egress if the build environment is
# restricted (the runtime pod's egress rules don't apply during docker build).
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
         | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg \
    && chmod go+r /etc/apt/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
         > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-25-jre \
    && rm -rf /var/lib/apt/lists/*

# Firebase CLI for running the emulators. Installed unpinned so the image gets a
# current release (which relies on the modern JDK above) rather than an old
# firebase-tools held back to stay compatible with an obsolete Java.
RUN npm install -g firebase-tools

# Google Cloud CLI (gcloud) from Google's official apt repo, so in-container
# flows can authenticate and call Google Cloud / Vertex AI. Building fetches
# from packages.cloud.google.com — allow that egress if the build environment
# is restricted (the runtime pod's egress rules don't apply during docker build).
RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-transport-https ca-certificates gnupg curl \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
         | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg \
    && chmod go+r /etc/apt/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
         > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-cloud-cli \
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
