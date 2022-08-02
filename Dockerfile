FROM debian:stable-slim as builder

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
  git curl gnupg2 build-essential golang-go \
  ca-certificates apt-transport-https && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

## Go Ethereum
WORKDIR /go-ethereum
ARG ETH_VERSION=1.10.16
ADD https://github.com/ethereum/go-ethereum/archive/refs/tags/v${ETH_VERSION}.tar.gz /go-ethereum/${ETH_VERSION}.tar.gz
RUN tar -zxf ${ETH_VERSION}.tar.gz  -C /go-ethereum
WORKDIR /go-ethereum/go-ethereum-${ETH_VERSION}
RUN go mod download 
RUN go run build/ci.go install


RUN useradd --create-home -s /bin/bash mr
RUN usermod -a -G sudo mr
RUN echo '%mr ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

ADD https://sh.rustup.rs /rustup/rustup-init.sh
RUN chmod 755 /rustup/rustup-init.sh 

## Rust
WORKDIR /rustup
ENV USER=mr
USER mr
RUN /rustup/rustup-init.sh -y --default-toolchain stable --profile minimal

## Foundry
WORKDIR /foundry

# latest https://github.com/foundry-rs/foundry
RUN ~mr/.cargo/bin/cargo install --git https://github.com/foundry-rs/foundry#7bc3e60e --locked foundry-cli

FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
  git gnupg2 curl build-essential golang-go \  
  sudo ripgrep npm \
  ca-certificates apt-transport-https && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*


# RUN npm install npm -g
RUN npm install yarn -g

RUN useradd --create-home -s /bin/bash mr
RUN usermod -a -G sudo mr
RUN echo '%mr ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

## GO Ethereum Binaries
ARG ETH_VERSION=1.10.16
# abidump  abigen  bootnode  checkpoint-admin  clef  devp2p  ethkey  evm	faucet	geth  p2psim  puppeth  rlpdump
COPY --from=builder /go-ethereum/go-ethereum-${ETH_VERSION}/build/bin /usr/local/bin
COPY --chown=mr:mr --from=builder /home/mr/.cargo /home/mr/.cargo

ARG PROJECT=collective-governance-v1
WORKDIR /workspaces/${PROJECT}
RUN chown -R mr.mr .
COPY --chown=mr:mr . .
ENV USER=mr
USER mr
ENV PATH=${PATH}:~/.cargo/bin
RUN yarn install
RUN yarn lint
RUN ~mr/.cargo/bin/forge build --sizes
RUN ~mr/.cargo/bin/forge test -vvv

CMD ~/mr/.cargo/bin/forge test -vvv
