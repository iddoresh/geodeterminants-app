FROM rocker/shiny:4.4.2

# Use Posit Package Manager for pre-compiled Ubuntu binaries (~3-5 min build vs 20-40 min source)
# rocker/shiny:4.4.2 is based on Ubuntu 24.04 (Noble)
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest"

# System deps required by sf, tigris, tidygeocoder
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Install all R dependencies from binary repo (fast)
RUN Rscript -e "install.packages(c( \
    'pak', \
    'tidyverse', \
    'tibble', \
    'tidygeocoder', \
    'tidycensus', \
    'tigris', \
    'sf', \
    'readxl', \
    'shiny', \
    'bslib', \
    'DT', \
    'shinyjs', \
    'shinycssloaders', \
    'dplyr', \
    'readr', \
    'remotes' \
  ), repos = 'https://packagemanager.posit.co/cran/__linux__/noble/latest')"

# Install geodeterminants from GitHub via pak (already installed above)
RUN Rscript -e "pak::pak('wchan05/geodeterminants')"

# Copy Shiny app
COPY shiny/ /srv/shiny-server/geodeterminants/

# Data dir for local-mode API key persistence (ignored on hosted deployments)
RUN mkdir -p /srv/geodeterminants && chmod 777 /srv/geodeterminants

# Shiny server config: serve on root path
RUN printf 'run_as shiny;\nserver {\n  listen 3838;\n  location / {\n    site_dir /srv/shiny-server/geodeterminants;\n    log_dir /var/log/shiny-server;\n    directory_index off;\n  }\n}\n' \
    > /etc/shiny-server/shiny-server.conf

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
