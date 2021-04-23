FROM openanalytics/r-shiny

# install cron and R package dependencies
RUN apt-get update && apt-get install -y \
    cron \
    nano \
    tdsodbc \
    odbc-postgresql \
    libsqliteodbc \
    ## clean up
    && apt-get clean \ 
    && rm -rf /var/lib/apt/lists/ \ 
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
        apt-transport-https \
        curl \
        gnupg \
        unixodbc-dev \
 && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
 && curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install --yes --no-install-recommends msodbcsql17 \
 && install2.r odbc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/*
# Install dependency libraries
RUN apt-get update && apt-get install -y  \
            libxml2-dev \
            libudunits2-dev \
            libssh2-1-dev \
            libcurl4-openssl-dev \
            libsasl2-dev \
	        libv8-dev \
            libmariadbd-dev \  
            libmariadb-client-lgpl-dev \
            unixodbc-dev \
            libpq-dev \
            && rm -rf /var/lib/apt/lists/*

# install required R packages
RUN    R -e "install.packages(c('tidyverse', 'rmarkdown', 'flexdashboard', 'knitr', 'plotly', 'shiny', 'shinyWidgets', 'shinyjs', 'tidyquant', 'parsnip', 'timetk', 'xgboost', 'umap', 'broom', 'DBI', 'odbc', 'config'), dependencies = TRUE, repo='http://cran.r-project.org')"

# make new directory and copy the required files:
RUN mkdir -p /bin
COPY SP500_App.Rmd    /bin/SP500_App.Rmd
COPY demand_forecast.R    /bin/demand_forecast.R
COPY sp_500_index_tbl.rds    /bin/sp_500_index_tbl.rds
COPY config.yml    /bin/config.yml
ADD img    /bin/img
ADD css    /bin/css

# make all app files readable (solves issue when dev in Windows, but building in Ubuntu)
RUN chmod -R 755 /bin

# expose port on Docker container
EXPOSE 3838

# run flexdashboard as localhost and on exposed port in Docker container
CMD ["R", "-e", "rmarkdown::run('/bin/SP500_App.Rmd', shiny_args = list(port = 3838, host = '0.0.0.0'))"]