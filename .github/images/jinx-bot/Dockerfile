FROM rocker/r2u:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      xz-utils && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION=v20.19.0
RUN curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz" \
      -o /tmp/node.tar.xz && \
    mkdir -p /opt/node && \
    tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1 && \
    rm /tmp/node.tar.xz && \
    ln -sf /opt/node/bin/node /usr/local/bin/node && \
    ln -sf /opt/node/bin/npm /usr/local/bin/npm && \
    ln -sf /opt/node/bin/npx /usr/local/bin/npx

WORKDIR /opt/jinx

COPY DESCRIPTION NAMESPACE LICENSE ./
COPY R ./R
COPY inst ./inst
COPY man ./man

RUN for attempt in 1 2 3; do \
      Rscript -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/")' && break; \
      if [ "${attempt}" -eq 3 ]; then exit 1; fi; \
      sleep 10; \
    done

RUN for attempt in 1 2 3; do \
      Rscript -e 'pak::pak("local::.", ask = FALSE, upgrade = FALSE)' && break; \
      if [ "${attempt}" -eq 3 ]; then exit 1; fi; \
      sleep 10; \
    done

WORKDIR /work
