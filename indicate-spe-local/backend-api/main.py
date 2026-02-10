"""
INDICATE Backend API
Manages study registration, execution, and result retrieval
"""
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
import httpx
import os
import json
import uuid
from pathlib import Path

# Database
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

app = FastAPI(
    title="INDICATE Backend API",
    description="API for managing federated analytics studies in the SPE",
    version="0.1.0"
)

# Configuration from environment
DATABASE_HOST = os.getenv('DATABASE_HOST', 'omop-db')
DATABASE_PORT = os.getenv('DATABASE_PORT', '5432')
DATABASE_NAME = os.getenv('DATABASE_NAME', 'omop_cdm')
DATABASE_USER = os.getenv('DATABASE_USER', 'omop_user')
DATABASE_PASSWORD = os.getenv('DATABASE_PASSWORD', 'omop_password')

DATABASE_URL = f"postgresql://{os.getenv('DATABASE_USER')}:{os.getenv('DATABASE_PASSWORD')}@{os.getenv('DATABASE_HOST')}:{os.getenv('DATABASE_PORT')}/{os.getenv('DATABASE_NAME')}"
CODE_EXECUTION_URL = os.getenv('CODE_EXECUTION_URL', 'http://code-executor:8001')

# Directories
STUDIES_DIR = Path("/studies")
RESULTS_DIR = Path("/results")
STUDIES_DIR.mkdir(exist_ok=True)
RESULTS_DIR.mkdir(exist_ok=True)

# Database engine
engine = create_engine(DATABASE_URL)

# Models
class StudyPackage(BaseModel):
    """Study package metadata"""
    study_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    study_name: str
    description: Optional[str] = None
    study_type: str = Field(default="cohort_analysis")  # cohort_analysis, federated_learning
    researcher: str
    institution: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

class StudyExecution(BaseModel):
    """Study execution request"""
    study_id: str
    execution_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    parameters: Optional[Dict[str, Any]] = None

class StudyStatus(BaseModel):
    """Study execution status"""
    study_id: str
    execution_id: str
    status: str  # pending, running, completed, failed
    created_at: datetime
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None

class DatasetSummary(BaseModel):
    """OMOP CDM dataset summary"""
    total_patients: int
    total_visits: int
    icu_stays: int
    date_range: Dict[str, str]
    available_domains: List[str]

# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Check database connection
        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()
        
        return {
            "status": "healthy",
            "service": "backend-api",
            "database": "connected",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "backend-api",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "INDICATE Backend API",
        "version": "0.1.0",
        "endpoints": {
            "health": "/health",
            "dataset": "/dataset/summary",
            "studies": "/studies",
            "execute": "/studies/{study_id}/execute",
            "results": "/studies/{study_id}/results"
        }
    }

# Dataset endpoints
@app.get("/dataset/summary", response_model=DatasetSummary)
async def get_dataset_summary():
    """Get summary statistics of the OMOP CDM dataset"""
    try:
        with engine.connect() as conn:
            # Count patients
            result = conn.execute(text("SELECT COUNT(*) FROM cdm.person"))
            total_patients = result.scalar()
            
            # Count visits
            result = conn.execute(text("SELECT COUNT(*) FROM cdm.visit_occurrence"))
            total_visits = result.scalar()
            
            # Count ICU stays
            result = conn.execute(text("SELECT COUNT(*) FROM cdm.visit_detail"))
            icu_stays = result.scalar()
            
            # Get date range
            result = conn.execute(text("""
                SELECT 
                    MIN(visit_start_date)::text as earliest,
                    MAX(visit_end_date)::text as latest
                FROM cdm.visit_occurrence
            """))
            date_range_row = result.fetchone()
            date_range = {
                "earliest": date_range_row[0] if date_range_row else None,
                "latest": date_range_row[1] if date_range_row else None
            }
            
            # Check available domains
            available_domains = []
            domain_checks = {
                "Condition": "SELECT COUNT(*) FROM cdm.condition_occurrence",
                "Drug": "SELECT COUNT(*) FROM cdm.drug_exposure",
                "Procedure": "SELECT COUNT(*) FROM cdm.procedure_occurrence",
                "Measurement": "SELECT COUNT(*) FROM cdm.measurement",
                "Observation": "SELECT COUNT(*) FROM cdm.observation"
            }
            
            for domain, query in domain_checks.items():
                result = conn.execute(text(query))
                if result.scalar() > 0:
                    available_domains.append(domain)
        
        return DatasetSummary(
            total_patients=total_patients,
            total_visits=total_visits,
            icu_stays=icu_stays,
            date_range=date_range,
            available_domains=available_domains
        )
    
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Study management endpoints
@app.post("/studies", response_model=StudyPackage)
async def register_study(
    study_file: UploadFile = File(...),
    study_name: str = "",
    description: str = "",
    researcher: str = "Test Researcher",
    institution: str = "Test Institution"
):
    """Register a new study package"""
    try:
        study_id = str(uuid.uuid4())
        study_dir = STUDIES_DIR / study_id
        study_dir.mkdir(exist_ok=True)
        
        # Save uploaded file
        file_path = study_dir / study_file.filename
        with open(file_path, "wb") as f:
            content = await study_file.read()
            f.write(content)
        
        # Create metadata
        metadata = StudyPackage(
            study_id=study_id,
            study_name=study_name or study_file.filename,
            description=description,
            researcher=researcher,
            institution=institution
        )
        
        # Save metadata
        metadata_path = study_dir / "metadata.json"
        with open(metadata_path, "w") as f:
            json.dump(metadata.model_dump(mode='json'), f, indent=2, default=str)
        
        return metadata
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to register study: {str(e)}")

@app.get("/studies")
async def list_studies() -> List[StudyPackage]:
    """List all registered studies"""
    studies = []
    for study_dir in STUDIES_DIR.iterdir():
        if study_dir.is_dir():
            metadata_path = study_dir / "metadata.json"
            if metadata_path.exists():
                with open(metadata_path) as f:
                    metadata = json.load(f)
                    studies.append(StudyPackage(**metadata))
    return studies

@app.get("/studies/{study_id}")
async def get_study(study_id: str) -> StudyPackage:
    """Get study metadata"""
    metadata_path = STUDIES_DIR / study_id / "metadata.json"
    if not metadata_path.exists():
        raise HTTPException(status_code=404, detail="Study not found")
    
    with open(metadata_path) as f:
        metadata = json.load(f)
    return StudyPackage(**metadata)

# Study execution endpoints
@app.post("/studies/{study_id}/execute", response_model=StudyStatus)
async def execute_study(study_id: str, execution: Optional[StudyExecution] = None):
    """Execute a study on the local OMOP CDM database"""
    try:
        # Check if study exists
        study_dir = STUDIES_DIR / study_id
        if not study_dir.exists():
            raise HTTPException(status_code=404, detail="Study not found")
        
        execution_id = str(uuid.uuid4()) if not execution else execution.execution_id
        
        # Forward to code executor
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{CODE_EXECUTION_URL}/execute",
                json={
                    "study_id": study_id,
                    "execution_id": execution_id,
                    "parameters": execution.parameters if execution else {}
                },
                timeout=300.0  # 5 minutes timeout
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Code executor error: {response.text}"
                )
            
            result = response.json()
        
        return StudyStatus(**result)
    
    except httpx.HTTPError as e:
        raise HTTPException(status_code=503, detail=f"Code executor unavailable: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Execution failed: {str(e)}")

@app.get("/studies/{study_id}/executions")
async def list_executions(study_id: str) -> List[Dict[str, Any]]:
    """List all executions for a study"""
    results_dir = RESULTS_DIR / study_id
    if not results_dir.exists():
        return []
    
    executions = []
    for execution_dir in results_dir.iterdir():
        if execution_dir.is_dir():
            status_file = execution_dir / "status.json"
            if status_file.exists():
                with open(status_file) as f:
                    executions.append(json.load(f))
    
    return executions

@app.get("/studies/{study_id}/executions/{execution_id}/status")
async def get_execution_status(study_id: str, execution_id: str) -> StudyStatus:
    """Get execution status"""
    status_file = RESULTS_DIR / study_id / execution_id / "status.json"
    if not status_file.exists():
        raise HTTPException(status_code=404, detail="Execution not found")
    
    with open(status_file) as f:
        status_data = json.load(f)
    return StudyStatus(**status_data)

@app.get("/studies/{study_id}/executions/{execution_id}/results")
async def get_execution_results(study_id: str, execution_id: str):
    """Get execution results"""
    results_file = RESULTS_DIR / study_id / execution_id / "results.json"
    if not results_file.exists():
        raise HTTPException(status_code=404, detail="Results not found")
    
    return FileResponse(results_file)

@app.get("/studies/{study_id}/executions/{execution_id}/logs")
async def get_execution_logs(study_id: str, execution_id: str):
    """Get execution logs"""
    logs_file = RESULTS_DIR / study_id / execution_id / "execution.log"
    if not logs_file.exists():
        raise HTTPException(status_code=404, detail="Logs not found")
    
    return FileResponse(logs_file)

# Data quality endpoints
@app.get("/quality/achilles")
async def run_achilles_analysis():
    """Trigger ACHILLES data quality analysis"""
    # This would typically call OHDSI Achilles
    # For now, return a placeholder
    return {
        "status": "not_implemented",
        "message": "ACHILLES analysis will be implemented in code executor"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
