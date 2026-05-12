FROM rocker/r2u:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/jinx

COPY DESCRIPTION NAMESPACE LICENSE ./
COPY R ./R
COPY inst ./inst
COPY man ./man

RUN Rscript -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/")'
RUN Rscript -e 'pak::pak("local::.", ask = FALSE)'

WORKDIR /work
