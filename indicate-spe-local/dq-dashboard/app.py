"""
INDICATE Data Quality Dashboard
Visualizes OMOP CDM data quality metrics
"""
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from sqlalchemy import create_engine, text
import os
from datetime import datetime

# Get env
DATABASE_HOST = os.getenv('DATABASE_HOST', 'omop-db')
DATABASE_PORT = os.getenv('DATABASE_PORT', '5432')
DATABASE_NAME = os.getenv('DATABASE_NAME', 'omop_cdm')
DATABASE_USER = os.getenv('DATABASE_USER', 'omop_user')
DATABASE_PASSWORD = os.getenv('DATABASE_PASSWORD', 'omop_password')

# Page configuration
st.set_page_config(
    page_title="INDICATE Data Quality Dashboard",
    page_icon="🏥",
    layout="wide"
)

# Database connection
@st.cache_resource
def get_engine():
    DATABASE_URL = f"postgresql://{os.getenv('DATABASE_USER')}:{os.getenv('DATABASE_PASSWORD')}@{os.getenv('DATABASE_HOST')}:{os.getenv('DATABASE_PORT')}/{os.getenv('DATABASE_NAME')}"
    return create_engine(DATABASE_URL)

engine = get_engine()

# Header
st.title("🏥 INDICATE Data Quality Dashboard")
st.markdown("**OMOP CDM v5.4** | Secure Processing Environment")
st.markdown("---")

# Sidebar
with st.sidebar:
    st.header("Navigation")
    page = st.radio(
        "Select View",
        ["Overview", "Patient Demographics", "Clinical Data", "Data Quality Metrics"]
    )
    
    st.markdown("---")
    st.markdown("### Data Info")
    st.markdown(f"**Date:** {datetime.now().strftime('%Y-%m-%d')}")
    st.markdown(f"**Database:** omop_cdm")

# Helper functions
@st.cache_data(ttl=60)
def run_query(query):
    """Execute SQL query and return DataFrame"""
    try:
        return pd.read_sql(query, engine)
    except Exception as e:
        st.error(f"Query failed: {str(e)}")
        return pd.DataFrame()

# Page: Overview
if page == "Overview":
    st.header("📊 Dataset Overview")
    
    col1, col2, col3, col4 = st.columns(4)
    
    # Total Patients
    df = run_query("SELECT COUNT(*) as count FROM cdm.person")
    with col1:
        st.metric("Total Patients", f"{df['count'].iloc[0]:,}")
    
    # Total Visits
    df = run_query("SELECT COUNT(*) as count FROM cdm.visit_occurrence")
    with col2:
        st.metric("Hospital Visits", f"{df['count'].iloc[0]:,}")
    
    # ICU Stays
    df = run_query("SELECT COUNT(*) as count FROM cdm.visit_detail")
    with col3:
        st.metric("ICU Stays", f"{df['count'].iloc[0]:,}")
    
    # Measurements
    df = run_query("SELECT COUNT(*) as count FROM cdm.measurement")
    with col4:
        st.metric("Measurements", f"{df['count'].iloc[0]:,}")
    
    st.markdown("---")
    
    # Data Completeness
    st.subheader("Data Completeness by Domain")
    
    query = """
    SELECT 
        'Condition' as domain, COUNT(*) as record_count FROM cdm.condition_occurrence
    UNION ALL
    SELECT 'Drug', COUNT(*) FROM cdm.drug_exposure
    UNION ALL
    SELECT 'Procedure', COUNT(*) FROM cdm.procedure_occurrence
    UNION ALL
    SELECT 'Measurement', COUNT(*) FROM cdm.measurement
    UNION ALL
    SELECT 'Observation', COUNT(*) FROM cdm.observation
    """
    df_domains = run_query(query)
    
    if not df_domains.empty:
        fig = px.bar(
            df_domains,
            x='domain',
            y='record_count',
            title='Records by Clinical Domain',
            labels={'domain': 'Domain', 'record_count': 'Record Count'},
            color='domain'
        )
        st.plotly_chart(fig, use_container_width=True)
    
    # Date Range
    st.subheader("Temporal Coverage")
    query = """
    SELECT 
        DATE_TRUNC('month', visit_start_date)::date as month,
        COUNT(*) as visit_count
    FROM cdm.visit_occurrence
    GROUP BY month
    ORDER BY month
    """
    df_temporal = run_query(query)
    
    if not df_temporal.empty:
        fig = px.line(
            df_temporal,
            x='month',
            y='visit_count',
            title='Visits Over Time',
            labels={'month': 'Month', 'visit_count': 'Number of Visits'}
        )
        st.plotly_chart(fig, use_container_width=True)

# Page: Patient Demographics
elif page == "Patient Demographics":
    st.header("👥 Patient Demographics")
    
    # Gender Distribution
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Gender Distribution")
        query = """
        SELECT 
            gender_source_value as gender,
            COUNT(*) as count
        FROM cdm.person
        GROUP BY gender_source_value
        """
        df_gender = run_query(query)
        
        if not df_gender.empty:
            fig = px.pie(
                df_gender,
                values='count',
                names='gender',
                title='Patients by Gender'
            )
            st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("Age Distribution")
        query = """
        SELECT 
            CASE 
                WHEN 2024 - year_of_birth < 40 THEN '< 40'
                WHEN 2024 - year_of_birth < 50 THEN '40-49'
                WHEN 2024 - year_of_birth < 60 THEN '50-59'
                WHEN 2024 - year_of_birth < 70 THEN '60-69'
                WHEN 2024 - year_of_birth < 80 THEN '70-79'
                ELSE '80+'
            END as age_group,
            COUNT(*) as count
        FROM cdm.person
        GROUP BY age_group
        ORDER BY age_group
        """
        df_age = run_query(query)
        
        if not df_age.empty:
            fig = px.bar(
                df_age,
                x='age_group',
                y='count',
                title='Patients by Age Group',
                labels={'age_group': 'Age Group', 'count': 'Patient Count'}
            )
            st.plotly_chart(fig, use_container_width=True)
    
    # Patient Summary Table
    st.subheader("Patient Summary")
    query = """
    SELECT 
        p.person_id,
        p.gender_source_value as gender,
        2024 - p.year_of_birth as age,
        COUNT(DISTINCT vo.visit_occurrence_id) as total_visits,
        COUNT(DISTINCT vd.visit_detail_id) as icu_stays,
        MIN(vo.visit_start_date) as first_visit,
        MAX(vo.visit_end_date) as last_visit
    FROM cdm.person p
    LEFT JOIN cdm.visit_occurrence vo ON p.person_id = vo.person_id
    LEFT JOIN cdm.visit_detail vd ON p.person_id = vd.person_id
    GROUP BY p.person_id, p.gender_source_value, p.year_of_birth
    ORDER BY p.person_id
    LIMIT 100
    """
    df_patients = run_query(query)
    
    if not df_patients.empty:
        st.dataframe(df_patients, use_container_width=True)

# Page: Clinical Data
elif page == "Clinical Data":
    st.header("🩺 Clinical Data Analysis")
    
    # Top Diagnoses
    st.subheader("Top 10 Diagnoses")
    query = """
    SELECT 
        c.concept_name as diagnosis,
        COUNT(DISTINCT co.person_id) as patient_count,
        COUNT(*) as occurrence_count
    FROM cdm.condition_occurrence co
    JOIN vocab.concept c ON co.condition_concept_id = c.concept_id
    WHERE c.concept_name IS NOT NULL
    GROUP BY c.concept_name
    ORDER BY patient_count DESC
    LIMIT 10
    """
    df_diagnoses = run_query(query)
    
    if not df_diagnoses.empty:
        fig = px.bar(
            df_diagnoses,
            x='patient_count',
            y='diagnosis',
            orientation='h',
            title='Most Common Diagnoses',
            labels={'patient_count': 'Number of Patients', 'diagnosis': 'Diagnosis'}
        )
        st.plotly_chart(fig, use_container_width=True)
    
    # Vital Signs Trends
    st.subheader("Vital Signs Distribution")
    
    measurement_type = st.selectbox(
        "Select Vital Sign",
        ["Heart Rate", "Blood Pressure (Systolic)", "Blood Pressure (Diastolic)", "SpO2", "Temperature"]
    )
    
    concept_map = {
        "Heart Rate": 3027018,
        "Blood Pressure (Systolic)": 3004249,
        "Blood Pressure (Diastolic)": 3012888,
        "SpO2": 3024171,
        "Temperature": 3020891
    }
    
    query = f"""
    SELECT 
        value_as_number as value,
        measurement_datetime::date as date
    FROM cdm.measurement
    WHERE measurement_concept_id = {concept_map[measurement_type]}
        AND value_as_number IS NOT NULL
    ORDER BY measurement_datetime
    LIMIT 1000
    """
    df_vitals = run_query(query)
    
    if not df_vitals.empty:
        col1, col2 = st.columns(2)
        
        with col1:
            fig = px.histogram(
                df_vitals,
                x='value',
                title=f'{measurement_type} Distribution',
                labels={'value': measurement_type, 'count': 'Frequency'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            fig = px.box(
                df_vitals,
                y='value',
                title=f'{measurement_type} Box Plot',
                labels={'value': measurement_type}
            )
            st.plotly_chart(fig, use_container_width=True)
    
    # ICU Procedures
    st.subheader("Common ICU Procedures")
    query = """
    SELECT 
        c.concept_name as procedure,
        COUNT(DISTINCT po.person_id) as patient_count
    FROM cdm.procedure_occurrence po
    JOIN vocab.concept c ON po.procedure_concept_id = c.concept_id
    WHERE c.concept_name IS NOT NULL
    GROUP BY c.concept_name
    ORDER BY patient_count DESC
    LIMIT 10
    """
    df_procedures = run_query(query)
    
    if not df_procedures.empty:
        st.dataframe(df_procedures, use_container_width=True)

# Page: Data Quality Metrics
elif page == "Data Quality Metrics":
    st.header("✅ Data Quality Metrics")
    
    # Completeness Metrics
    st.subheader("Data Completeness")
    
    col1, col2, col3 = st.columns(3)
    
    # Person completeness
    query = """
    SELECT 
        COUNT(*) as total,
        COUNT(year_of_birth) as has_birth_year,
        COUNT(gender_concept_id) as has_gender
    FROM cdm.person
    """
    df_person_complete = run_query(query)
    
    if not df_person_complete.empty:
        total = df_person_complete['total'].iloc[0]
        birth_pct = (df_person_complete['has_birth_year'].iloc[0] / total * 100)
        gender_pct = (df_person_complete['has_gender'].iloc[0] / total * 100)
        
        with col1:
            st.metric("Birth Year Completeness", f"{birth_pct:.1f}%")
        with col2:
            st.metric("Gender Completeness", f"{gender_pct:.1f}%")
    
    # Measurement completeness
    query = """
    SELECT 
        COUNT(*) as total,
        COUNT(value_as_number) as has_value,
        COUNT(unit_concept_id) as has_unit
    FROM cdm.measurement
    """
    df_measure_complete = run_query(query)
    
    if not df_measure_complete.empty:
        total = df_measure_complete['total'].iloc[0]
        if total > 0:
            value_pct = (df_measure_complete['has_value'].iloc[0] / total * 100)
            with col3:
                st.metric("Measurement Value Completeness", f"{value_pct:.1f}%")
    
    st.markdown("---")
    
    # Plausibility Checks
    st.subheader("Plausibility Checks")
    
    # Age distribution plausibility
    query = """
    SELECT 
        CASE 
            WHEN 2024 - year_of_birth < 0 THEN 'Invalid (Future birth)'
            WHEN 2024 - year_of_birth > 120 THEN 'Invalid (> 120 years)'
            WHEN 2024 - year_of_birth < 18 THEN 'Pediatric (< 18)'
            ELSE 'Valid adult'
        END as age_category,
        COUNT(*) as count
    FROM cdm.person
    GROUP BY age_category
    """
    df_age_check = run_query(query)
    
    if not df_age_check.empty:
        st.dataframe(df_age_check, use_container_width=True)
    
    # Vital signs plausibility
    st.subheader("Vital Signs Plausibility")
    query = """
    SELECT 
        'Heart Rate' as vital,
        COUNT(CASE WHEN value_as_number < 30 OR value_as_number > 220 THEN 1 END) as implausible,
        COUNT(*) as total,
        ROUND(100.0 * COUNT(CASE WHEN value_as_number < 30 OR value_as_number > 220 THEN 1 END) / COUNT(*), 2) as pct_implausible
    FROM cdm.measurement
    WHERE measurement_concept_id = 3027018
    UNION ALL
    SELECT 
        'Temperature (C)' as vital,
        COUNT(CASE WHEN value_as_number < 30 OR value_as_number > 45 THEN 1 END),
        COUNT(*),
        ROUND(100.0 * COUNT(CASE WHEN value_as_number < 30 OR value_as_number > 45 THEN 1 END) / COUNT(*), 2)
    FROM cdm.measurement
    WHERE measurement_concept_id = 3020891
    """
    df_vital_check = run_query(query)
    
    if not df_vital_check.empty:
        st.dataframe(df_vital_check, use_container_width=True)

# Footer
st.markdown("---")
st.markdown(
    "**INDICATE Project** | Data Quality Dashboard v0.1 | "
    f"Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
)
