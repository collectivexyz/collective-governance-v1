FROM ghcr.io/collectivexyz/foundry:latest

ARG PROJECT=collective-governance-v1
WORKDIR /workspaces/${PROJECT}
RUN chown -R mr.mr .
COPY --chown=mr:mr . .
ENV USER=mr
USER mr
ENV PATH=${PATH}:~/.cargo/bin
RUN yarn install
RUN yarn hint
RUN ~mr/.cargo/bin/forge test -vvv --gas-report

RUN bin/update_abi.sh
