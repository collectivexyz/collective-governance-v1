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

## Rust
WORKDIR /rustup
ADD https://sh.rustup.rs /rustup/rustup.sh
RUN chmod 755 /rustup/rustup.sh
ENV USER=mr
USER mr
RUN /rustup/rustup.sh -y

## Foundry
RUN ~mr/.cargo/bin/cargo install --git https://github.com/foundry-rs/foundry --locked foundry-cli

FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
  git gnupg2 curl build-essential golang-go \  
  sudo ripgrep \
  ca-certificates apt-transport-https && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*


RUN useradd --create-home -s /bin/bash mr
RUN usermod -a -G sudo mr
RUN echo '%mr ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

## GO Ethereum Binaries
ARG ETH_VERSION=1.10.16
# abidump  abigen  bootnode  checkpoint-admin  clef  devp2p  ethkey  evm	faucet	geth  p2psim  puppeth  rlpdump
COPY --from=builder /go-ethereum/go-ethereum-${ETH_VERSION}/build/bin /usr/local/bin
COPY --chown=mr:mr --from=builder /home/mr/.cargo /home/mr/.cargo

ARG PROJECT=eth-governance-v1
WORKDIR /workspaces/${PROJECT}
RUN chown -R mr.mr .
COPY --chown=mr:mr . .
ENV USER=mr
USER mr
ENV PATH=${PATH}:~/.cargo/bin
#RUN ~mr/.cargo/bin/forge build --sizes
#RUN ~mr/.cargo/bin/forge test -vvv

CMD ~/mr/.cargo/bin/forge test -vvv
