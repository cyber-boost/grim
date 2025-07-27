FROM ubuntu:22.04 as builder

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV GRIM_ROOT=/opt/grim-reaper
ENV GRIM_LICENSE=FREE
ENV GRIM_REAPER=FALSE

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    golang-go \
    rustc \
    cargo \
    php \
    composer \
    openjdk-17-jdk \
    maven \
    ruby \
    gem \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create grim user and directories
RUN useradd -m -u 1000 grim && \
    mkdir -p $GRIM_ROOT && \
    chown -R grim:grim $GRIM_ROOT

# Switch to grim user
USER grim
WORKDIR $GRIM_ROOT

# Download and extract Grim Reaper
RUN curl -fsSL https://get.grim.so/latest.tar.gz | tar -xzf - --strip-components=2

# Build components
RUN cd go_grim && go build -o ../bin/grim-compression . && \
    cd ../py_grim && python3 -m pip install --user . && \
    cd ../js_grim && npm install --production && \
    cd ../rs_grim && cargo build --release && cp target/release/grim-reaper ../bin/

# Make scripts executable
RUN find . -name "*.sh" -exec chmod +x {} \; && \
    chmod +x bin/* && \
    chmod +x throne/* && \
    chmod +x sh_grim/*

# Production stage
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV GRIM_ROOT=/opt/grim-reaper
ENV GRIM_LICENSE=FREE
ENV GRIM_REAPER=FALSE
ENV PATH=$GRIM_ROOT/bin:$GRIM_ROOT/throne:$PATH

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    rsync \
    openssl \
    ca-certificates \
    python3 \
    python3-pip \
    nodejs \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Create grim user
RUN useradd -m -u 1000 grim && \
    mkdir -p $GRIM_ROOT /home/grim/.graveyard && \
    chown -R grim:grim $GRIM_ROOT /home/grim/.graveyard

# Copy built application
COPY --from=builder --chown=grim:grim $GRIM_ROOT $GRIM_ROOT

# Switch to grim user
USER grim
WORKDIR /home/grim

# Create volume mount points
VOLUME ["/data", "/backups", "/home/grim/.graveyard"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD grim health || exit 1

# Default command
ENTRYPOINT ["grim"]
CMD ["help"]

# Labels
LABEL org.opencontainers.image.title="Grim Reaper"
LABEL org.opencontainers.image.description="Death-defying data protection - Unified backup, monitoring, and security system"
LABEL org.opencontainers.image.url="https://grim.so"
LABEL org.opencontainers.image.source="https://github.com/cyber-boost/grim"
LABEL org.opencontainers.image.vendor="CyberBoost LLC"
LABEL org.opencontainers.image.licenses="BBL"
LABEL org.opencontainers.image.version="1.0.36" 