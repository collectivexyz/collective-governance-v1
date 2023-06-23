FROM ghcr.io/collectivexyz/foundry:latest

ARG PROJECT=collective-governance-v1
WORKDIR /workspaces/${PROJECT}

RUN chown -R mr.mr .
COPY --chown=mr:mr . .
ENV USER=mr
USER mr

ENV PATH=${PATH}:~/.cargo/bin
RUN yarn install
RUN yarn prettier:check
RUN yarn hint
RUN FOUNDRY_PROFILE=fastbuild forge test -vvv --fail-fast
RUN forge geiger --check contracts/*

RUN bin/update_abi.sh
