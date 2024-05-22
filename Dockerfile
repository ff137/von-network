FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
  apt-file \
  ca-certificates \
  gnupg \
  software-properties-common \
  curl \
  git \
  build-essential \
  libssl-dev \
  libzmq3-dev \
  pkg-config \
  tzdata \
  python3.12 \
  python3.12-venv \
  python3.12-dev \
  python3-pip

# Install rustup and set up the stable toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup default stable

RUN apt-file update

# Update apt-file and locate OpenSSL files
RUN export OPENSSL_LIB_DIR=$(apt-file list libssl-dev | grep 'libssl.a' | awk '{ print $2 }' | xargs dirname | head -n 1) && \
  export OPENSSL_INCLUDE_DIR=$(apt-file list libssl-dev | grep '/openssl/' | awk '{ print $2 }' | xargs dirname | head -n 1) && \
  echo "OPENSSL_LIB_DIR=$OPENSSL_LIB_DIR" && \
  echo "OPENSSL_INCLUDE_DIR=$OPENSSL_INCLUDE_DIR"

# Clone the indy-sdk repo and build from source
RUN git clone https://github.com/ff137/indy-sdk.git && \
  cd indy-sdk && \
  git checkout update && \
  cd libindy && \
  cargo build --release && \
  cp target/release/libindy.so /usr/local/lib/ && \
  ldconfig

ENV LOG_LEVEL=${LOG_LEVEL:-info}
ENV RUST_LOG=${RUST_LOG:-warning}

COPY config /config
COPY server/requirements.txt /server/requirements.txt

# Create a virtual environment and install dependencies
RUN python3.12 -m venv /app/venv
ENV PATH="/app/venv/bin:${PATH}"
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r /server/requirements.txt --upgrade

ENV HOME=/home/indy
WORKDIR $HOME

# Create indy user and group
RUN groupadd -r indy && useradd -r -g indy indy

# Copy indy_config.py to /etc/indy
COPY --chown=indy:indy indy_config.py /etc/indy/

# Copy all remaining files to the home directory of indy user
COPY --chown=indy:indy . $HOME

RUN chmod +x scripts/init_genesis.sh

RUN mkdir -p $HOME/cli-scripts && \
  chmod -R ug+rw $HOME/cli-scripts
