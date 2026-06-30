FROM rocker/shiny:4.4.2 AS shiny_stage

FROM rocker/geospatial:4.4.2

# Copy shiny-server from the official shiny image
COPY --from=shiny_stage /opt/shiny-server /opt/shiny-server
RUN ln -sf /opt/shiny-server/bin/shiny-server /usr/bin/shiny-server \
    && useradd -r -m shiny 2>/dev/null || true \
    && mkdir -p /var/log/shiny-server /srv/shiny-server /etc/shiny-server /var/lib/shiny-server/bookmarks \
    && chown -R shiny /var/log/shiny-server /var/lib/shiny-server

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

# Data dir for local-mode API key persistence (not used in hosted deployments)
RUN mkdir -p /srv/geodeterminants && chmod 777 /srv/geodeterminants

RUN printf 'run_as shiny;\nserver {\n  listen 3838;\n  location / {\n    site_dir /srv/shiny-server/geodeterminants;\n    log_dir /var/log/shiny-server;\n    directory_index off;\n  }\n}\n' \
    > /etc/shiny-server/shiny-server.conf

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
