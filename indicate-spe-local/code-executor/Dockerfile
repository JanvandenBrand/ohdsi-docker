FROM rocker/r-ver:4.3.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    libpq-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install R packages for OHDSI
RUN R -e "install.packages(c('remotes', 'renv', 'jsonlite', 'DBI', 'RPostgres', 'dplyr', 'tidyr'), repos='https://cloud.r-project.org/')"

# Install OHDSI packages
RUN R -e "remotes::install_github('OHDSI/DatabaseConnector')"
RUN R -e "remotes::install_github('OHDSI/SqlRender')"
RUN R -e "remotes::install_github('OHDSI/CohortGenerator')"
RUN R -e "remotes::install_github('OHDSI/FeatureExtraction')"

# Set up Python environment
WORKDIR /app

# Copy Python requirements
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create execution sandbox
RUN mkdir -p /execution /tmp_results && \
    chmod 777 /execution /tmp_results

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
