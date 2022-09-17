FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y -q --no-install-recommends \
    python3 python3-pip

RUN apt clean
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /docs
COPY site/requirements.txt .

RUN python3 -m pip install --upgrade pip
RUN if [ -f requirements.txt ]; then python3 -m pip install -r requirements.txt; fi

COPY . .

RUN sphinx-build -b html site site/_build/html

CMD cp -vr site/_build/html/* /html 

