#!/usr/bin/env python3
"""
INDICATE Example Study: Sepsis Patient Analysis
Analyzes outcomes and characteristics of ICU patients with sepsis
"""
import os
import json
import pandas as pd
from sqlalchemy import create_engine
from datetime import datetime

# Database connection
DATABASE_URL = (
    f"postgresql://{os.getenv('DATABASE_USER')}:"
    f"{os.getenv('DATABASE_PASSWORD')}@"
    f"{os.getenv('DATABASE_HOST')}:"
    f"{os.getenv('DATABASE_PORT')}/"
    f"{os.getenv('DATABASE_NAME')}"
)

engine = create_engine(DATABASE_URL)

def get_sepsis_cohort():
    """Identify patients with sepsis diagnosis"""
    query = """
    SELECT DISTINCT
        co.person_id,
        p.gender_source_value as gender,
        2024 - p.year_of_birth as age,
        co.condition_start_date as sepsis_date,
        vo.visit_occurrence_id,
        vo.visit_start_date,
        vo.visit_end_date
    FROM cdm.condition_occurrence co
    JOIN cdm.person p ON co.person_id = p.person_id
    JOIN cdm.visit_occurrence vo ON co.visit_occurrence_id = vo.visit_occurrence_id
    WHERE co.condition_concept_id = 132797  -- Sepsis concept
    """
    return pd.read_sql(query, engine)

def get_vital_signs(person_ids):
    """Get vital signs for cohort"""
    person_list = ','.join(map(str, person_ids))
    query = f"""
    SELECT 
        m.person_id,
        c.concept_name as measurement,
        m.value_as_number as value,
        m.measurement_datetime,
        m.visit_occurrence_id
    FROM cdm.measurement m
    JOIN vocab.concept c ON m.measurement_concept_id = c.concept_id
    WHERE m.person_id IN ({person_list})
        AND m.measurement_concept_id IN (3027018, 3004249, 3012888, 3024171, 3020891)
        AND m.value_as_number IS NOT NULL
    ORDER BY m.person_id, m.measurement_datetime
    """
    return pd.read_sql(query, engine)

def get_lab_results(person_ids):
    """Get lab results for cohort"""
    person_list = ','.join(map(str, person_ids))
    query = f"""
    SELECT 
        m.person_id,
        c.concept_name as lab_test,
        m.value_as_number as value,
        m.measurement_date,
        m.visit_occurrence_id
    FROM cdm.measurement m
    JOIN vocab.concept c ON m.measurement_concept_id = c.concept_id
    WHERE m.person_id IN ({person_list})
        AND m.measurement_concept_id IN (3006140, 3016723, 3000963)  -- Lactate, Creatinine, WBC
        AND m.value_as_number IS NOT NULL
    ORDER BY m.person_id, m.measurement_date
    """
    return pd.read_sql(query, engine)

def calculate_mortality(person_ids):
    """Calculate mortality for cohort"""
    person_list = ','.join(map(str, person_ids))
    query = f"""
    SELECT 
        person_id,
        death_date
    FROM cdm.death
    WHERE person_id IN ({person_list})
    """
    return pd.read_sql(query, engine)

def main():
    """Main analysis function"""
    
    # Get sepsis cohort
    cohort = get_sepsis_cohort()
    
    if cohort.empty:
        print(json.dumps({
            "error": "No sepsis patients found in database",
            "study_name": "Sepsis Analysis"
        }))
        return
    
    person_ids = cohort['person_id'].tolist()
    
    # Demographic analysis
    demographics = {
        "total_patients": len(cohort),
        "gender_distribution": cohort['gender'].value_counts().to_dict(),
        "age_statistics": {
            "mean": float(cohort['age'].mean()),
            "median": float(cohort['age'].median()),
            "min": int(cohort['age'].min()),
            "max": int(cohort['age'].max()),
            "std": float(cohort['age'].std())
        }
    }
    
    # Get vital signs
    vitals = get_vital_signs(person_ids)
    
    # Analyze vital signs by measurement type
    vital_analysis = {}
    if not vitals.empty:
        for measurement in vitals['measurement'].unique():
            subset = vitals[vitals['measurement'] == measurement]
            vital_analysis[measurement] = {
                "count": len(subset),
                "mean": float(subset['value'].mean()),
                "std": float(subset['value'].std()),
                "min": float(subset['value'].min()),
                "max": float(subset['value'].max())
            }
    
    # Get lab results
    labs = get_lab_results(person_ids)
    
    # Analyze labs
    lab_analysis = {}
    if not labs.empty:
        for lab_test in labs['lab_test'].unique():
            subset = labs[labs['lab_test'] == lab_test]
            lab_analysis[lab_test] = {
                "count": len(subset),
                "mean": float(subset['value'].mean()),
                "std": float(subset['value'].std()),
                "min": float(subset['value'].min()),
                "max": float(subset['value'].max())
            }
    
    # Calculate mortality
    deaths = calculate_mortality(person_ids)
    mortality_rate = len(deaths) / len(cohort) * 100 if len(cohort) > 0 else 0
    
    # Length of stay
    cohort['los_days'] = (pd.to_datetime(cohort['visit_end_date']) - 
                          pd.to_datetime(cohort['visit_start_date'])).dt.days
    
    # Compile results
    results = {
        "study_name": "Sepsis Patient Analysis",
        "study_type": "cohort_analysis",
        "execution_date": datetime.now().isoformat(),
        "cohort": {
            "definition": "Patients with sepsis diagnosis (concept_id: 132797)",
            "demographics": demographics
        },
        "clinical_characteristics": {
            "vital_signs": vital_analysis,
            "laboratory_results": lab_analysis
        },
        "outcomes": {
            "mortality": {
                "deaths": len(deaths),
                "mortality_rate_percent": round(mortality_rate, 2)
            },
            "length_of_stay": {
                "mean_days": float(cohort['los_days'].mean()),
                "median_days": float(cohort['los_days'].median()),
                "min_days": int(cohort['los_days'].min()),
                "max_days": int(cohort['los_days'].max())
            }
        },
        "metadata": {
            "python_version": f"{os.sys.version_info.major}.{os.sys.version_info.minor}",
            "pandas_version": pd.__version__,
            "omop_cdm_version": "5.4"
        }
    }
    
    # Output as JSON
    print(json.dumps(results, indent=2, default=str))

if __name__ == "__main__":
    main()