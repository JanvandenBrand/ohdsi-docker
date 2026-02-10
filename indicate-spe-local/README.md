# INDICATE SPE Local Test Environment

This is a fully containerized test environment for the INDICATE Secure Processing Environment (SPE), designed for local testing on Ubuntu 22 (including WSL).

## Architecture Components

Based on the Data Provider Architecture diagram, this setup includes:

1. **OMOP Database** (PostgreSQL 15) - OMOP CDM v5.4 with synthetic patient data
2. **Backend API** (Python/FastAPI) - Study management and execution coordination
3. **Code Executor** (Python/R) - Secure container for running analytics code
4. **Data Quality Dashboard** (Streamlit) - OHDSI Data Quality checks

## Prerequisites

- Ubuntu 22.04 (native or WSL)
- Docker Engine installed
- Docker Compose installed
- At least 8GB RAM available
- 50GB free disk space (for vocabularies and data)

## Directory Structure

```
indicate-spe-local/
├── docker-compose.yml          # Main orchestration file
├── db-init/                    # PostgreSQL initialization scripts
│   ├── 01-create-schema.sql    # OMOP CDM v5.4 DDL
│   ├── 02-load-vocabularies.sh # Vocabulary loader
│   └── 03-load-synthetic-data.sh
├── vocabularies/               # OMOP vocabularies from Athena (you provide)
├── synthetic-data/             # Generated synthetic patient data
├── backend-api/                # Backend API service
├── code-executor/              # Code execution service
├── dq-dashboard/               # Data quality dashboard
├── studies/                    # Study packages (input)
└── results/                    # Study results (output)
```

## Setup Instructions

### Step 1: Clone/Create Project Structure
```bash
mkdir -p indicate-spe-local
cd indicate-spe-local
```

### Step 2: Download OMOP Vocabularies
1. Go to https://athena.ohdsi.org/
2. Select vocabularies: ATC, Gender, ICD10, LOINC, RxNorm, RxNorm Extension, SNOMED, UCUM
3. Download and extract to `./vocabularies/` directory

### Step 3: Build and Start Services
```bash
# Build all containers
docker-compose build

# Start all services
docker-compose up -d

# Check service health
docker-compose ps
```

### Step 4: Verify Installation
```bash
# Check database
docker-compose exec omop-db psql -U omop_user -d omop_cdm -c "SELECT COUNT(*) FROM concept;"

# Check backend API
curl http://localhost:8000/health

# Check code executor
curl http://localhost:8001/health
```

## Service Endpoints

- **PostgreSQL Database**: localhost:5432
- **Backend API**: http://localhost:8000
- **Code Executor**: http://localhost:8001
- **DQ Dashboard**: http://localhost:8501

## Next Steps

Follow the step-by-step setup guide to:
1. Initialize OMOP CDM schema
2. Load vocabularies
3. Generate synthetic patient data
4. Test study execution

## Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v
```
