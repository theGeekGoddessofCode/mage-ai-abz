FROM python:3.10-bookworm
LABEL description="Deploy Mage on ECS"
USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

## System Packages
RUN \
  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
  curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
  apt-get -y update && \
  ACCEPT_EULA=Y apt-get -y install --no-install-recommends \
    # NFS dependencies
    nfs-common \
    # odbc dependencies
    msodbcsql18\
    unixodbc-dev \
    # R
    r-base && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

## R Packages
RUN \
  R -e "install.packages('pacman', repos='http://cran.us.r-project.org')" && \
  R -e "install.packages('renv', repos='http://cran.us.r-project.org')"

## Python Packages
RUN \
  pip3 install --no-cache-dir sparkmagic && \
  mkdir ~/.sparkmagic && \
  curl https://raw.githubusercontent.com/jupyter-incubator/sparkmagic/master/sparkmagic/example_config.json > ~/.sparkmagic/config.json && \
  sed -i 's/localhost:8998/host.docker.internal:9999/g' ~/.sparkmagic/config.json && \
  jupyter-kernelspec install --user "$(pip3 show sparkmagic | grep Location | cut -d' ' -f2)/sparkmagic/kernels/pysparkkernel"
# Mage integrations and other related packages

# Install oscrypto
RUN pip3 install --no-cache-dir "git+https://github.com/wbond/oscrypto.git@d5f3437ed24257895ae1edd9e503cfb352e635a8"

# Install singer-python
RUN pip3 install --no-cache-dir "git+https://github.com/mage-ai/singer-python.git#egg=singer-python"

# Install google-ads-python
RUN pip3 install --no-cache-dir "git+https://github.com/mage-ai/google-ads-python.git#egg=google-ads"

# Install dbt-mysql
RUN pip3 install --no-cache-dir "git+https://github.com/mage-ai/dbt-mysql.git#egg=dbt-mysql"

# Install dbt-synapse
RUN pip3 install --no-cache-dir "git+https://github.com/mage-ai/dbt-synapse.git#egg=dbt-synapse"

# Install mage-integrations
RUN pip3 install --no-cache-dir --timeout=500 "git+https://github.com/theGeekGoddessofCode/mage-ai-abz.git#egg=mage-integrations&subdirectory=mage_integrations"

# Mage
COPY ./mage_ai/server/constants.py /tmp/constants.py
RUN \
  tag=$(tail -n 1 /tmp/constants.py) && \
  VERSION=$(echo "$tag" | tr -d "'") && \
  pip3 install --no-cache-dir "mage-ai[all]==$VERSION" && \
  rm /tmp/constants.py

## Startup Script
COPY --chmod=+x ./scripts/install_other_dependencies.py ./scripts/run_app.sh /app/

ENV MAGE_DATA_DIR="/home/src/mage_data"
ENV PYTHONPATH="${PYTHONPATH}:/home/src"
WORKDIR /home/src
EXPOSE 6789
EXPOSE 7789

CMD ["/bin/sh", "-c", "/app/run_app.sh"]
