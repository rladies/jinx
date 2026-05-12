FROM rocker/r2u:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

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
