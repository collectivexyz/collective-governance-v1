ARG VERSION=stable-slim
FROM debian:${VERSION}

RUN export DEBIAN_FRONTEND=noninteractive && \
        apt update && \
        apt install -y -q --no-install-recommends \
        build-essential python3 python3-pip git

RUN apt clean
RUN rm -rf /var/lib/apt/lists/*


WORKDIR /tools
ENV WORKPATH=/tools

COPY requirements.txt .

RUN python3 -m pip install --upgrade pip
RUN if [ -f requirements.txt ]; then python3 -m pip install -r requirements.txt; fi

ADD . /site
WORKDIR /site

RUN pelican content --output /htmltmp

CMD cp -vr /htmltmp/* /html && pelican --listen --bind 0.0.0.0 /html

