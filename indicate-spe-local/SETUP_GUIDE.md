# INDICATE SPE Local Test Environment - Setup Guide

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Database Setup](#database-setup)
4. [Testing the Environment](#testing-the-environment)
5. [Running Example Studies](#running-example-studies)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 22.04 (native or WSL2)
- **RAM**: Minimum 8GB, recommended 16GB
- **Disk Space**: 50GB free (for vocabularies and Docker images)
- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher

### Verify Prerequisites

```bash
# Check Docker installation
docker --version
# Expected: Docker version 20.10.x or higher

# Check Docker Compose
docker-compose --version
# Expected: Docker Compose version v2.x.x or higher

# Check available disk space
df -h
# Ensure at least 50GB free

# Check available memory
free -h
# Ensure at least 8GB RAM
```

---

## Initial Setup

### Step 1: Create Project Directory

```bash
# Create and navigate to project directory
mkdir -p ~/indicate-spe-local
cd ~/indicate-spe-local

# Verify you're in the correct directory
pwd
# Should show: /home/your-username/indicate-spe-local
```

### Step 2: Download OMOP Vocabularies from Athena

1. **Go to Athena OHDSI**: https://athena.ohdsi.org/
2. **Sign in** (create free account if needed)
3. **Select Vocabularies**:
   - ✅ ATC
   - ✅ Gender
   - ✅ ICD10
   - ✅ LOINC
   - ✅ RxNorm
   - ✅ RxNorm Extension
   - ✅ SNOMED
4. **Click "Download Vocabularies"**
5. **Download the .zip file** (usually takes 5-10 minutes)
6. **Extract to the vocabularies directory**:

```bash
# Create vocabularies directory
mkdir -p ~/indicate-spe-local/vocabularies

# Extract downloaded vocabularies (adjust filename)
unzip ~/Downloads/vocabulary_download_v5_*.zip -d ~/indicate-spe-local/vocabularies/

# Verify files are present
ls -lh ~/indicate-spe-local/vocabularies/
# Should see: CONCEPT.csv, VOCABULARY.csv, DOMAIN.csv, etc.
```

### Step 3: Verify Project Structure

```bash
cd ~/indicate-spe-local

# Check structure
tree -L 2
```

Expected structure:
```
indicate-spe-local/
├── docker-compose.yml
├── README.md
├── SETUP_GUIDE.md (this file)
├── db-init/
│   ├── 01-create-schema.sql
│   ├── 02-load-vocabularies.sh
│   └── 03-load-synthetic-data.sh
├── vocabularies/
│   ├── CONCEPT.csv
│   ├── VOCABULARY.csv
│   └── ... (other vocabulary files)
├── backend-api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
├── code-executor/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
├── dq-dashboard/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
└── studies/
    ├── example-cohort-study/
    └── example-sepsis-study/
```

---

## Database Setup

### Step 4: Build Docker Images

This will take 10-20 minutes on first run as it downloads base images and installs dependencies.

```bash
cd ~/indicate-spe-local

# Build all services
docker-compose build --progress=plain

# Monitor build progress
# You should see:
# - omop-db: Using postgres:15-alpine
# - backend-api: Installing Python dependencies
# - code-executor: Installing R and Python packages (longest step)
# - dq-dashboard: Installing Streamlit
```

**Expected Output**:
```
[+] Building 1234.5s (45/45) FINISHED
 => [backend-api] ...
 => [code-executor] ... 
 => [dq-dashboard] ...
Successfully built
```

### Step 5: Start Services

```bash
# Start all services in detached mode
docker-compose up -d

# Check service status
docker-compose ps
```

**Expected Output**:
```
NAME                    STATUS              PORTS
indicate-omop-db        Up (healthy)        0.0.0.0:5432->5432/tcp
indicate-backend-api    Up                  0.0.0.0:8000->8000/tcp
indicate-code-executor  Up                  0.0.0.0:8001->8001/tcp
indicate-dq-dashboard   Up                  0.0.0.0:8501->8501/tcp
```

### Step 6: Load Vocabularies

This step loads ~5GB of vocabulary data and takes 15-30 minutes.

```bash
# Execute vocabulary loading script inside database container
docker-compose exec omop-db /docker-entrypoint-initdb.d/02-load-vocabularies.sh
```

**What to expect**:
- Script will check for vocabulary files
- Load each vocabulary table (CONCEPT is largest ~10M rows)
- Show summary of loaded vocabularies
- Display total concept count

**Expected Final Output**:
```
=========================================
Vocabularies loaded successfully!
=========================================
Total concepts loaded: 5,234,567
```

### Step 7: Load Synthetic Data

```bash
# Load synthetic ICU patient data
docker-compose exec omop-db /docker-entrypoint-initdb.d/03-load-synthetic-data.sh
```

**Expected Output**:
```
=========================================
Synthetic Data Summary
=========================================
Patients                       | 10
Hospital Visits                | 10
ICU Stays                      | 5
Diagnoses                      | 7
Measurements (Vitals/Labs)     | 21
Procedures                     | 4
Medications                    | 5
=========================================
Synthetic data loaded successfully!
=========================================
```

---

## Testing the Environment

### Step 8: Test Database Connection

```bash
# Test direct PostgreSQL connection
docker-compose exec omop-db psql -U omop_user -d omop_cdm -c "SELECT COUNT(*) FROM cdm.person;"

# Expected output:
#  count 
# -------
#     10
# (1 row)
```

### Step 9: Test Backend API

```bash
# Test health endpoint
curl http://localhost:8000/health

# Expected output (formatted):
{
  "status": "healthy",
  "service": "backend-api",
  "database": "connected",
  "timestamp": "2026-02-06T10:30:00.000000"
}

# Get dataset summary
curl http://localhost:8000/dataset/summary

# Expected output:
{
  "total_patients": 10,
  "total_visits": 10,
  "icu_stays": 5,
  "date_range": {
    "earliest": "2024-01-05",
    "latest": "2024-03-30"
  },
  "available_domains": [
    "Condition",
    "Drug",
    "Procedure",
    "Measurement"
  ]
}
```

### Step 10: Test Code Executor

```bash
# Test health
curl http://localhost:8001/health

# Expected output:
{
  "status": "healthy",
  "service": "code-executor",
  "database": "connected",
  "r_available": true,
  "python_available": true,
  ...
}

# Test database connection
curl http://localhost:8001/test/database

# Test R execution (takes a few seconds)
curl http://localhost:8001/test/r

# Expected output:
{
  "status": "success",
  "r_version": "4.3",
  "patient_count": 10,
  "ohdsi_available": true
}

# Test Python execution
curl http://localhost:8001/test/python

# Expected output:
{
  "status": "success",
  "python_version": "3.11",
  "pandas_version": "2.1.4",
  "patient_count": 10
}
```

### Step 11: Open Data Quality Dashboard

```bash
# Dashboard is available at:
# http://localhost:8501

# Open in browser (WSL2):
wslview http://localhost:8501

# Or on native Linux:
xdg-open http://localhost:8501
```

**What you should see**:
- Overview page with patient counts
- Domain completeness charts
- Temporal coverage visualization

---

## Running Example Studies

### Study 1: ICU Cohort Characterization (R)

```bash
# Register the study
curl -X POST http://localhost:8000/studies \
  -F "study_file=@studies/example-cohort-study/cohort_analysis.R" \
  -F "study_name=ICU Cohort Characterization" \
  -F "description=Basic demographic and clinical analysis of ICU patients" \
  -F "researcher=Test User" \
  -F "institution=Test Hospital"

# Example output
{
  "study_id":"7646e647-8193-4593-ba1c-23a0a19b7a63",
  "study_name":"cohort_analysis.R",
  "description":"",
  "study_type":"cohort_analysis",
  "researcher":"Test Researcher",
  "institution":"Test Institution",
  "created_at":"2026-02-10T09:15:01.622344"
}

# Save the returned study_id (e.g., "abc-123-def-456")
STUDY_ID=<paste-your-study-id> 
echo "Study ID: $STUDY_ID"

# Execute the study
EXEC_RESPONSE=$(curl -s -X POST http://localhost:8000/studies/$STUDY_ID/execute)
EXECUTION_ID=$(echo $EXEC_RESPONSE | grep -o '"execution_id":"[^"]*"' | cut -d'"' -f4)
echo "Execution ID: $EXECUTION_ID"

# Check execution status (wait 30-60 seconds)
curl http://localhost:8000/studies/$STUDY_ID/executions/$EXECUTION_ID/status

# Download results file
curl http://localhost:8000/studies/$STUDY_ID/executions/$EXECUTION_ID/results > results.json

# View formatted results
cat results.json | jq '.'

# See the execution logs (helpful for debugging)
curl http://localhost:8000/studies/$STUDY_ID/executions/$EXECUTION_ID/logs


```

**Expected Results Structure**:
```json
{
  "study_name": "ICU Cohort Characterization",
  "cohort": {
    "total_icu_patients": 10,
    "demographics": [...],
    "age_summary": {
      "mean": 58.5,
      "median": 60,
      ...
    }
  },
  "clinical_characteristics": {
    "common_diagnoses": [...],
    "length_of_stay": {...},
    "vital_signs": {...}
  }
}
```

### Study 2: Sepsis Analysis (Python)

```bash
# Make Python script executable
chmod +x studies/example-sepsis-study/sepsis_analysis.py

# Register and execute (similar to Study 1)
curl -X POST http://localhost:8000/studies \
  -F "study_file=@studies/example-sepsis-study/sepsis_analysis.py" \
  -F "study_name=Sepsis Patient Analysis" \
  -F "description=Analysis of sepsis patients in ICU" \
  -F "researcher=Test User" \
  -F "institution=Test Hospital"

# Execute and retrieve results (follow same pattern as Study 1)
```

## Troubleshooting

### Issue: Vocabularies Not Loading

**Symptoms**: 
```
ERROR: Vocabulary files not found in /vocabularies
```

**Solution**:
```bash
# Verify vocabulary files exist
ls -lh vocabularies/

# Check file names (must be uppercase CSV)
# CONCEPT.csv, VOCABULARY.csv, etc.

# Restart database to retry
docker-compose restart omop-db
```

### Issue: Port Already in Use

**Symptoms**:
```
Error: bind: address already in use
```

**Solution**:
```bash
# Check what's using the port
sudo lsof -i :5432  # PostgreSQL
sudo lsof -i :8000  # Backend API
sudo lsof -i :8001  # Code Executor
sudo lsof -i :8501  # Dashboard

# Either stop the conflicting service or change ports in docker-compose.yml
```

### Issue: Code Executor R Test Fails

**Symptoms**:
```
R execution failed: package 'DatabaseConnector' not found
```

**Solution**:
```bash
# Rebuild code-executor with --no-cache
docker-compose build --no-cache code-executor

# Restart service
docker-compose up -d code-executor
```

### Issue: Database Connection Refused

**Symptoms**:
```
connection to server ... failed: Connection refused
```

**Solution**:
```bash
# Check database health
docker-compose ps omop-db

# View database logs
docker-compose logs omop-db

# Restart if needed
docker-compose restart omop-db

# Wait for health check
docker-compose ps
# STATUS should show "(healthy)"
```

### Issue: Out of Memory

**Symptoms**:
```
killed
oom-killer
```

**Solution**:
```bash
# Check Docker memory limit
docker info | grep Memory

# Increase Docker Desktop memory (WSL2):
# Settings → Resources → Memory → 8GB or higher

# Or stop other containers
docker ps
docker stop <other-containers>
```

### Viewing Logs

```bash
# View all logs
docker-compose logs

# View specific service
docker-compose logs backend-api
docker-compose logs code-executor
docker-compose logs omop-db

# Follow logs in real-time
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100
```

### Complete Reset

If you need to start fresh:

```bash
# Stop and remove everything
docker-compose down -v

# Remove results
rm -rf results/* 


# Rebuild and restart
docker-compose build --no-cache
docker-compose up -d

# Reload vocabularies and synthetic data
# (Follow Steps 6-7 again)
```

---

## Next Steps

### Adding Your Own Data

1. **Export your ICU data** to OMOP CDM format
2. **Create SQL insert scripts** or CSV files
3. **Load into database**:
   ```bash
   docker-compose exec -T omop-db psql -U omop_user -d omop_cdm < your-data.sql
   ```

### Creating Custom Studies

1. **Write R or Python script** that:
   - Connects to database using environment variables
   - Queries OMOP tables
   - Outputs results as JSON to stdout

2. **Test locally**:
   ```bash
   docker-compose exec code-executor Rscript /studies/your-study/script.R
   ```

3. **Register and execute** via API (see Study examples)

### Integrating with INDICATE Hub

The local SPE is designed to simulate the production environment. To integrate:

1. **Configure federated analytics endpoint** in Backend API
2. **Implement study approval workflow**
3. **Add encryption for results**
4. **Set up automated study execution queue**

---

## Architecture Validation

This setup validates the following components from the INDICATE architecture:

✅ **Data Platform**:
- OMOP CDM Database (PostgreSQL)
- Standard vocabularies loaded

✅ **Secure Processing Environment**:
- Code Execution Engine (R & Python)
- Backend API for orchestration
- Dataset Definition (OMOP schema)
- Data Quality Assurance (Dashboard)

✅ **External Interface**:
- API Management (REST API)
- Data Quality Dashboard (Web UI)

🔜 **Not Yet Implemented** (Future Enhancements):
- Federated Analytics Node (INDICATE Hub integration)
- Waveform Database (high-frequency physiological data)
- Advanced security (encryption at rest, audit logging)
- Real-time monitoring and alerting

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Docker logs: `docker-compose logs`
3. Refer to INDICATE documentation in project knowledge base
4. Contact INDICATE technical team

---

**Last Updated**: 2026-02-06
**Version**: 0.1.0
**Tested On**: Ubuntu 22.04 LTS with Docker 24.0.7
