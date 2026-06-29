FROM rocker/shiny:4.4.2

# System deps for sf, tigris, tidygeocoder
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

# Install pak for faster parallel package installs
RUN Rscript -e "install.packages('pak', repos = 'https://r-lib.github.io/p/pak/stable/')"

# Install all R dependencies
RUN Rscript -e "pak::pak(c( \
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
    'readr' \
))"

# Install geodeterminants from GitHub
RUN Rscript -e "pak::pak('wchan05/geodeterminants')"

# Copy Shiny app
COPY shiny/ /srv/shiny-server/geodeterminants/

# Persistent data dir (API key + outputs)
RUN mkdir -p /srv/geodeterminants && chmod 777 /srv/geodeterminants

# Shiny server config: single-app mode on root path
RUN printf 'run_as shiny;\nserver {\n  listen 3838;\n  location / {\n    site_dir /srv/shiny-server/geodeterminants;\n    log_dir /var/log/shiny-server;\n    directory_index off;\n  }\n}\n' \
    > /etc/shiny-server/shiny-server.conf

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
