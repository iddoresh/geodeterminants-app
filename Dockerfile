FROM rocker/shiny:4.4.2 AS shiny_stage

FROM rocker/geospatial:4.4.2

# Copy shiny-server from the official shiny image
COPY --from=shiny_stage /opt/shiny-server /opt/shiny-server
RUN ln -sf /opt/shiny-server/bin/shiny-server /usr/bin/shiny-server \
    && mkdir -p /var/log/shiny-server /srv/shiny-server /etc/shiny-server /var/lib/shiny-server/bookmarks

# Install remaining packages from GitHub (CRAN blocked in sandbox; remotes pre-installed in geospatial)
# Dependencies for all packages are already present in rocker/geospatial
RUN Rscript -e "\
  remotes::install_github('rstudio/DT', dependencies=FALSE, upgrade='never'); \
  remotes::install_github('daattali/shinyjs', dependencies=FALSE, upgrade='never'); \
  remotes::install_github('daattali/shinycssloaders', dependencies=FALSE, upgrade='never'); \
  remotes::install_github('walkerke/tigris', dependencies=FALSE, upgrade='never'); \
  remotes::install_github('jessecambon/tidygeocoder', dependencies=FALSE, upgrade='never'); \
  remotes::install_github('walkerke/tidycensus', dependencies=FALSE, upgrade='never'); \
  remotes::install_github('wchan05/geodeterminants', dependencies=FALSE, upgrade='never')"

COPY shiny/ /srv/shiny-server/geodeterminants/

# Download supplemental datasets (AQI, RFEI, EJ Index, pct_unionized modules)
# Fails gracefully — those 4 modules unavailable if download fails, other 8 still work
RUN Rscript -e "\
  tryCatch({ \
    url <- 'https://drive.usercontent.google.com/download?id=1OMHsyaFPNGa8Vu68rrrLKSg1Gqu94Prb&export=download&confirm=t'; \
    dest <- '/tmp/gd.zip'; \
    download.file(url, dest, quiet=TRUE, method='libcurl'); \
    unzip(dest, exdir='/srv/shiny-server/geodeterminants', overwrite=TRUE); \
    d <- '/srv/shiny-server/geodeterminants'; \
    if (!dir.exists(file.path(d,'geodeterminants_datasets')) && dir.exists(file.path(d,'datasets'))) \
      file.rename(file.path(d,'datasets'), file.path(d,'geodeterminants_datasets')); \
    file.remove(dest); \
    cat('[OK] geodeterminants_datasets downloaded\n') \
  }, error=function(e) { \
    cat('[WARN] dataset download failed:', conditionMessage(e), '\n'); \
    cat('[WARN] AQI, RFEI, EJ Index, pct_unionized modules will not run\n') \
  })"

# Data dir for local-mode API key persistence (not used in hosted deployments)
RUN mkdir -p /srv/geodeterminants && chmod 777 /srv/geodeterminants

RUN printf 'server {\n  listen 10000;\n  location / {\n    site_dir /srv/shiny-server/geodeterminants;\n    log_dir /var/log/shiny-server;\n    directory_index off;\n  }\n}\n' \
    > /etc/shiny-server/shiny-server.conf

EXPOSE 10000

CMD ["/usr/bin/shiny-server"]
