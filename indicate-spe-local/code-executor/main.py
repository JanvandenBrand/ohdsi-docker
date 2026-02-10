"""
INDICATE Code Executor
Securely executes R and Python analytics code against OMOP CDM
"""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
import subprocess
import os
import json
import logging
from pathlib import Path
import tempfile

# Database
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="INDICATE Code Executor",
    description="Secure execution environment for federated analytics",
    version="0.1.0"
)

# Configuration with defaults
DATABASE_HOST = os.getenv('DATABASE_HOST', 'omop-db')
DATABASE_PORT = os.getenv('DATABASE_PORT', '5432')
DATABASE_NAME = os.getenv('DATABASE_NAME', 'omop_cdm')
DATABASE_USER = os.getenv('DATABASE_USER', 'omop_user')
DATABASE_PASSWORD = os.getenv('DATABASE_PASSWORD', 'omop_password')

DATABASE_URL = f"postgresql://{DATABASE_USER}:{DATABASE_PASSWORD}@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_NAME}"

STUDIES_DIR = Path("/studies")
RESULTS_DIR = Path("/results")
EXECUTION_DIR = Path("/execution")

# Database engine
engine = create_engine(DATABASE_URL)

# Models
class ExecutionRequest(BaseModel):
    """Code execution request"""
    study_id: str
    execution_id: str
    parameters: Optional[Dict[str, Any]] = None
    timeout: int = Field(default=300, ge=10, le=3600)  # seconds

class ExecutionStatus(BaseModel):
    """Execution status response"""
    study_id: str
    execution_id: str
    status: str  # pending, running, completed, failed
    created_at: datetime
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    results_available: bool = False

# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Check database
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        
        # Check R installation
        r_check = subprocess.run(
            ["R", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        r_available = r_check.returncode == 0
        
        # Check Python
        python_available = True  # We're running Python
        
        return {
            "status": "healthy",
            "service": "code-executor",
            "database": "connected",
            "r_available": r_available,
            "python_available": python_available,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {
            "status": "unhealthy",
            "service": "code-executor",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "INDICATE Code Executor",
        "version": "0.1.0",
        "capabilities": ["R", "Python", "OHDSI"],
        "endpoints": {
            "health": "/health",
            "execute": "/execute",
            "test_r": "/test/r",
            "test_python": "/test/python"
        }
    }

# Test endpoints
@app.get("/test/database")
async def test_database_connection():
    """Test database connection and query OMOP data"""
    try:
        with engine.connect() as conn:
            # Test basic query
            result = conn.execute(text("SELECT COUNT(*) as count FROM cdm.person"))
            person_count = result.scalar()
            
            # Get sample data
            result = conn.execute(text("""
                SELECT 
                    p.person_id,
                    p.gender_source_value,
                    2024 - p.year_of_birth as age,
                    COUNT(DISTINCT vo.visit_occurrence_id) as visit_count
                FROM cdm.person p
                LEFT JOIN cdm.visit_occurrence vo ON p.person_id = vo.person_id
                GROUP BY p.person_id, p.gender_source_value, p.year_of_birth
                LIMIT 5
            """))
            sample_data = [dict(row._mapping) for row in result]
            
            return {
                "status": "success",
                "total_patients": person_count,
                "sample_data": sample_data
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database test failed: {str(e)}")

@app.get("/test/r")
async def test_r_execution():
    """Test R execution with OHDSI packages"""
    try:
        # Create test R script
        r_script = """
library(DatabaseConnector)
library(jsonlite)

# Connection details for PostgreSQL
# For PostgreSQL, server format is: "host/database"
db_host <- Sys.getenv("DATABASE_HOST")
db_port <- Sys.getenv("DATABASE_PORT")
db_name <- Sys.getenv("DATABASE_NAME")
server_string <- paste0(db_host, "/", db_name)

# JDBC driver path (from environment)
jdbc_path <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
if (jdbc_path == "") {
    jdbc_path <- "/jdbc_drivers"
}

connectionDetails <- createConnectionDetails(
    dbms = "postgresql",
    server = server_string,
    port = Sys.getenv("DATABASE_PORT"),
    user = Sys.getenv("DATABASE_USER"),
    password = Sys.getenv("DATABASE_PASSWORD"),
    pathToDriver = jdbc_path  # ✅ Now specified
)

# Connect and query
connection <- connect(connectionDetails)
result <- querySql(connection, "SELECT COUNT(*) as count FROM cdm.person")
disconnect(connection)

# Output as JSON
cat(toJSON(list(
    status = "success",
    r_version = paste(R.version$major, R.version$minor, sep="."),
    patient_count = as.integer(result$COUNT),
    ohdsi_available = TRUE
)))
"""
        
        # Write script to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.R', delete=False) as f:
            f.write(r_script)
            script_path = f.name
        
        try:
            # Execute R script
            result = subprocess.run(
                ["Rscript", script_path],
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ}
            )
            
            if result.returncode != 0:
                logger.error(f"R execution error: {result.stderr}")
                raise HTTPException(
                    status_code=500,
                    detail=f"R execution failed: {result.stderr}"
                )
            
            # Parse JSON output
            output = json.loads(result.stdout)
            return output
            
        finally:
            # Clean up temp file
            os.unlink(script_path)
    
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="R execution timed out")
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse R output: {result.stdout}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to parse R output: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"R test failed: {str(e)}")

@app.get("/test/python")
async def test_python_execution():
    """Test Python execution with database access"""
    try:
        import pandas as pd
        
        # Query using pandas
        query = "SELECT COUNT(*) as count FROM cdm.person"
        df = pd.read_sql(query, engine)
        
        return {
            "status": "success",
            "python_version": f"{os.sys.version_info.major}.{os.sys.version_info.minor}",
            "pandas_version": pd.__version__,
            "patient_count": int(df['count'].iloc[0])
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Python test failed: {str(e)}")

# Main execution endpoint
@app.post("/execute", response_model=ExecutionStatus)
async def execute_study(request: ExecutionRequest):
    """Execute a study on the OMOP CDM database"""
    try:
        logger.info(f"Executing study {request.study_id}, execution {request.execution_id}")
        
        # Create execution directory
        exec_dir = RESULTS_DIR / request.study_id / request.execution_id
        exec_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize status
        status = ExecutionStatus(
            study_id=request.study_id,
            execution_id=request.execution_id,
            status="running",
            created_at=datetime.utcnow()
        )
        
        # Save initial status
        status_file = exec_dir / "status.json"
        with open(status_file, "w") as f:
            json.dump(status.model_dump(mode='json'), f, indent=2, default=str)
        
        # Find study files
        study_dir = STUDIES_DIR / request.study_id
        if not study_dir.exists():
            raise HTTPException(status_code=404, detail="Study not found")
        
        # Look for R or Python scripts
        r_scripts = list(study_dir.glob("*.R"))
        py_scripts = list(study_dir.glob("*.py"))
        
        log_file = exec_dir / "execution.log"
        results = {}
        
        if r_scripts:
            # Execute R script
            logger.info(f"Executing R script: {r_scripts[0]}")
            results = await execute_r_script(
                r_scripts[0],
                exec_dir,
                log_file,
                request.parameters,
                request.timeout
            )
        elif py_scripts:
            # Execute Python script
            logger.info(f"Executing Python script: {py_scripts[0]}")
            results = await execute_python_script(
                py_scripts[0],
                exec_dir,
                log_file,
                request.parameters,
                request.timeout
            )
        else:
            # Run default cohort characterization
            logger.info("No custom script found, running default cohort analysis")
            results = await run_default_cohort_analysis(exec_dir, log_file)
        
        # Update status
        status.status = "completed"
        status.completed_at = datetime.utcnow()
        status.results_available = True
        
        # Save results
        results_file = exec_dir / "results.json"
        with open(results_file, "w") as f:
            json.dump(results, f, indent=2, default=str)
        
        # Save final status
        with open(status_file, "w") as f:
            json.dump(status.model_dump(mode='json'), f, indent=2, default=str)
        
        logger.info(f"Execution completed: {request.execution_id}")
        return status
    
    except Exception as e:
        logger.error(f"Execution failed: {str(e)}")
        
        # Update status to failed
        status.status = "failed"
        status.error_message = str(e)
        status.completed_at = datetime.utcnow()
        
        with open(status_file, "w") as f:
            json.dump(status.model_dump(mode='json'), f, indent=2, default=str)
        
        raise HTTPException(status_code=500, detail=f"Execution failed: {str(e)}")

async def execute_r_script(
    script_path: Path,
    exec_dir: Path,
    log_file: Path,
    parameters: Optional[Dict],
    timeout: int
) -> Dict:
    """Execute an R script"""
    try:
        with open(log_file, "w") as log:
            log.write(f"Executing R script: {script_path}\n")
            log.write(f"Parameters: {json.dumps(parameters)}\n\n")
            
            result = subprocess.run(
                ["Rscript", str(script_path)],
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=exec_dir,
                env={**os.environ}
            )
            
            log.write("=== STDOUT ===\n")
            log.write(result.stdout)
            log.write("\n=== STDERR ===\n")
            log.write(result.stderr)
            
            if result.returncode != 0:
                raise Exception(f"R script failed with code {result.returncode}: {result.stderr}")
        
        # Try to parse JSON output
        try:
            return json.loads(result.stdout)
        except:
            return {"output": result.stdout, "type": "text"}
    
    except subprocess.TimeoutExpired:
        raise Exception(f"R script execution timed out after {timeout} seconds")

async def execute_python_script(
    script_path: Path,
    exec_dir: Path,
    log_file: Path,
    parameters: Optional[Dict],
    timeout: int
) -> Dict:
    """Execute a Python script"""
    try:
        with open(log_file, "w") as log:
            log.write(f"Executing Python script: {script_path}\n")
            log.write(f"Parameters: {json.dumps(parameters)}\n\n")
            
            result = subprocess.run(
                ["python3", str(script_path)],
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=exec_dir,
                env={**os.environ}
            )
            
            log.write("=== STDOUT ===\n")
            log.write(result.stdout)
            log.write("\n=== STDERR ===\n")
            log.write(result.stderr)
            
            if result.returncode != 0:
                raise Exception(f"Python script failed with code {result.returncode}: {result.stderr}")
        
        # Try to parse JSON output
        try:
            return json.loads(result.stdout)
        except:
            return {"output": result.stdout, "type": "text"}
    
    except subprocess.TimeoutExpired:
        raise Exception(f"Python script execution timed out after {timeout} seconds")

async def run_default_cohort_analysis(exec_dir: Path, log_file: Path) -> Dict:
    """Run a default cohort characterization analysis"""
    try:
        import pandas as pd
        
        with open(log_file, "w") as log:
            log.write("Running default cohort analysis\n\n")
            
            # Demographics
            query = """
            SELECT 
                gender_source_value as gender,
                2024 - year_of_birth as age_group,
                COUNT(*) as patient_count
            FROM cdm.person
            GROUP BY gender_source_value, year_of_birth
            ORDER BY patient_count DESC
            """
            df_demographics = pd.read_sql(query, engine)
            log.write(f"Demographics: {len(df_demographics)} rows\n")
            
            # Visit statistics
            query = """
            SELECT 
                COUNT(DISTINCT person_id) as unique_patients,
                COUNT(*) as total_visits,
                AVG(EXTRACT(EPOCH FROM (visit_end_datetime - visit_start_datetime))/86400) as avg_los_days
            FROM cdm.visit_occurrence
            """
            df_visits = pd.read_sql(query, engine)
            log.write(f"Visit statistics calculated\n")
            
            # ICU statistics
            query = """
            SELECT 
                COUNT(*) as icu_stays,
                AVG(EXTRACT(EPOCH FROM (visit_detail_end_datetime - visit_detail_start_datetime))/86400) as avg_icu_los_days
            FROM cdm.visit_detail
            """
            df_icu = pd.read_sql(query, engine)
            log.write(f"ICU statistics calculated\n")
            
            # Top diagnoses
            query = """
            SELECT 
                c.concept_name as diagnosis,
                COUNT(DISTINCT co.person_id) as patient_count
            FROM cdm.condition_occurrence co
            JOIN vocab.concept c ON co.condition_concept_id = c.concept_id
            GROUP BY c.concept_name
            ORDER BY patient_count DESC
            LIMIT 10
            """
            df_diagnoses = pd.read_sql(query, engine)
            log.write(f"Top diagnoses: {len(df_diagnoses)} found\n")
        
        return {
            "analysis_type": "cohort_characterization",
            "demographics": df_demographics.to_dict(orient='records'),
            "visit_statistics": df_visits.to_dict(orient='records')[0],
            "icu_statistics": df_icu.to_dict(orient='records')[0],
            "top_diagnoses": df_diagnoses.to_dict(orient='records')
        }
    
    except Exception as e:
        logger.error(f"Default analysis failed: {str(e)}")
        raise Exception(f"Default cohort analysis failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
