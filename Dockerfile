# ====================================================
# BUILD STAGE: Install dependencies and compile agents
# ====================================================
FROM fedora:44 AS builder

# Install necessary system dependencies
RUN dnf install -y \
    bash \
    curl \
    openssl \
    tar \
    unzip \
    && dnf clean all

# Create non-root user pi
RUN useradd -m -s /bin/bash pi
RUN mkdir -p /workspace && chown pi /workspace

# Switch to pi user
USER pi

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/pi/.bun/bin:${PATH}"
ENV BUN_INSTALL="/home/pi/.bun"

# Install oh-my-pi globally
WORKDIR /workspace
RUN bun install -g @oh-my-pi/pi-coding-agent

# ====================================================
# RUNTIME STAGE: Minimal environment for execution
# ====================================================
FROM fedora-minimal:44 AS runtime

# Recreate minimal environment and user
RUN useradd -m -s /bin/bash pi
RUN mkdir -p /workspace && chown pi /workspace

# Runtime base stage: Minimal environment, inheriting from builder.
#{{ template for variant goes here }}

USER pi

# Copy bun installation artifacts from the builder stage
COPY --from=builder /home/pi/.bun /home/pi/.bun
# Re-establish PATH for the runtime
ENV PATH="/home/pi/.bun/bin:${PATH}"

WORKDIR /workspace
# Default command
CMD ["omp"]