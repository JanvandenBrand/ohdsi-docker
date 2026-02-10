#!/bin/bash
# Script to generate and load synthetic OMOP data for ICU testing
# Uses R with Eunomia package or creates minimal synthetic dataset

set -e

PSQL="psql -U $POSTGRES_USER -d $POSTGRES_DB"
SYNTH_DIR="/tmp"

echo "========================================="
echo "Generating Synthetic OMOP Data"
echo "========================================="

# Create synthetic data directory if it doesn't exist
mkdir -p $SYNTH_DIR

# Generate synthetic data using SQL (minimal ICU dataset)
# This creates a simple test dataset with 10 ICU patients

cat > $SYNTH_DIR/synthetic_data.sql << 'EOF'
-- Synthetic ICU Patient Data for INDICATE Testing
-- 10 patients with ICU stays, vital signs, labs, and diagnoses

SET search_path TO cdm;

-- Insert synthetic CARE_SITE (ICU)
INSERT INTO care_site (care_site_id, care_site_name, place_of_service_concept_id, care_site_source_value) VALUES
(1, 'Medical ICU', 8717, 'MICU'),
(2, 'Surgical ICU', 8717, 'SICU'),
(3, 'Cardiac ICU', 8717, 'CICU');

-- Insert synthetic PROVIDER
INSERT INTO provider (provider_id, provider_name, specialty_concept_id, care_site_id, specialty_source_value) VALUES
(1, 'Dr. Smith', 38004446, 1, 'Critical Care'),
(2, 'Dr. Johnson', 38004446, 2, 'Critical Care'),
(3, 'Dr. Williams', 38004446, 3, 'Cardiology');

-- Insert 10 synthetic patients (mixed gender, ages 40-85)
INSERT INTO person (person_id, gender_concept_id, year_of_birth, month_of_birth, day_of_birth, race_concept_id, ethnicity_concept_id, person_source_value, gender_source_value) VALUES
(1, 8507, 1960, 3, 15, 8527, 38003564, 'P001', 'M'),  -- Male, 66yo
(2, 8532, 1975, 7, 22, 8527, 38003564, 'P002', 'F'),  -- Female, 51yo
(3, 8507, 1955, 11, 8, 8527, 38003564, 'P003', 'M'),  -- Male, 71yo
(4, 8532, 1968, 2, 14, 8527, 38003564, 'P004', 'F'),  -- Female, 58yo
(5, 8507, 1982, 9, 30, 8527, 38003564, 'P005', 'M'),  -- Male, 44yo
(6, 8532, 1950, 5, 19, 8527, 38003564, 'P006', 'F'),  -- Female, 76yo
(7, 8507, 1972, 12, 3, 8527, 38003564, 'P007', 'M'),  -- Male, 54yo
(8, 8532, 1965, 8, 27, 8527, 38003564, 'P008', 'F'),  -- Female, 61yo
(9, 8507, 1978, 4, 11, 8527, 38003564, 'P009', 'M'),  -- Male, 48yo
(10, 8532, 1958, 10, 6, 8527, 38003564, 'P010', 'F'); -- Female, 68yo

-- Insert observation periods (enrollment)
INSERT INTO observation_period (observation_period_id, person_id, observation_period_start_date, observation_period_end_date, period_type_concept_id) VALUES
(1, 1, '2024-01-01', '2024-12-31', 44814724),
(2, 2, '2024-01-01', '2024-12-31', 44814724),
(3, 3, '2024-01-01', '2024-12-31', 44814724),
(4, 4, '2024-01-01', '2024-12-31', 44814724),
(5, 5, '2024-01-01', '2024-12-31', 44814724),
(6, 6, '2024-01-01', '2024-12-31', 44814724),
(7, 7, '2024-01-01', '2024-12-31', 44814724),
(8, 8, '2024-01-01', '2024-12-31', 44814724),
(9, 9, '2024-01-01', '2024-12-31', 44814724),
(10, 10, '2024-01-01', '2024-12-31', 44814724);

-- Insert hospital visits with ICU stays (January-March 2024)
INSERT INTO visit_occurrence (visit_occurrence_id, person_id, visit_concept_id, visit_start_date, visit_start_datetime, visit_end_date, visit_end_datetime, visit_type_concept_id, care_site_id) VALUES
(1, 1, 9201, '2024-01-05', '2024-01-05 08:30:00', '2024-01-12', '2024-01-12 14:00:00', 44818517, 1),
(2, 2, 9201, '2024-01-10', '2024-01-10 12:15:00', '2024-01-18', '2024-01-18 09:30:00', 44818517, 1),
(3, 3, 9201, '2024-01-15', '2024-01-15 18:45:00', '2024-01-28', '2024-01-28 16:20:00', 44818517, 2),
(4, 4, 9201, '2024-02-01', '2024-02-01 22:10:00', '2024-02-09', '2024-02-09 11:45:00', 44818517, 1),
(5, 5, 9201, '2024-02-05', '2024-02-05 14:30:00', '2024-02-11', '2024-02-11 10:15:00', 44818517, 3),
(6, 6, 9201, '2024-02-12', '2024-02-12 09:20:00', '2024-02-25', '2024-02-25 15:30:00', 44818517, 2),
(7, 7, 9201, '2024-02-20', '2024-02-20 16:40:00', '2024-02-27', '2024-02-27 12:00:00', 44818517, 1),
(8, 8, 9201, '2024-03-01', '2024-03-01 11:25:00', '2024-03-14', '2024-03-14 14:50:00', 44818517, 2),
(9, 9, 9201, '2024-03-08', '2024-03-08 20:15:00', '2024-03-15', '2024-03-15 09:00:00', 44818517, 3),
(10, 10, 9201, '2024-03-15', '2024-03-15 13:50:00', '2024-03-30', '2024-03-30 16:30:00', 44818517, 1);

-- Insert ICU stay details (subset of hospital visits)
INSERT INTO visit_detail (visit_detail_id, person_id, visit_detail_concept_id, visit_detail_start_date, visit_detail_start_datetime, visit_detail_end_date, visit_detail_end_datetime, visit_detail_type_concept_id, care_site_id, visit_occurrence_id) VALUES
(1, 1, 32037, '2024-01-05', '2024-01-05 09:00:00', '2024-01-08', '2024-01-08 14:00:00', 44818517, 1, 1),
(2, 2, 32037, '2024-01-10', '2024-01-10 13:00:00', '2024-01-15', '2024-01-15 10:00:00', 44818517, 1, 2),
(3, 3, 32037, '2024-01-15', '2024-01-15 19:00:00', '2024-01-25', '2024-01-25 12:00:00', 44818517, 2, 3),
(4, 4, 32037, '2024-02-01', '2024-02-01 23:00:00', '2024-02-06', '2024-02-06 08:00:00', 44818517, 1, 4),
(5, 5, 32037, '2024-02-05', '2024-02-05 15:00:00', '2024-02-09', '2024-02-09 11:00:00', 44818517, 3, 5);

-- Insert common ICU diagnoses
-- Sepsis (concept_id: 132797), Pneumonia (concept_id: 255848), Acute respiratory failure (concept_id: 4329847)
-- Heart failure (concept_id: 316139), Acute kidney injury (concept_id: 197320)
INSERT INTO condition_occurrence (condition_occurrence_id, person_id, condition_concept_id, condition_start_date, condition_start_datetime, condition_type_concept_id, visit_occurrence_id) VALUES
(1, 1, 132797, '2024-01-05', '2024-01-05 08:30:00', 32020, 1),  -- Sepsis
(2, 1, 255848, '2024-01-05', '2024-01-05 08:30:00', 32020, 1),  -- Pneumonia
(3, 2, 4329847, '2024-01-10', '2024-01-10 12:15:00', 32020, 2), -- Acute respiratory failure
(4, 3, 316139, '2024-01-15', '2024-01-15 18:45:00', 32020, 3),  -- Heart failure
(5, 3, 197320, '2024-01-16', '2024-01-16 10:00:00', 32020, 3),  -- Acute kidney injury
(6, 4, 132797, '2024-02-01', '2024-02-01 22:10:00', 32020, 4),  -- Sepsis
(7, 5, 4329847, '2024-02-05', '2024-02-05 14:30:00', 32020, 5); -- Acute respiratory failure

-- Insert vital signs measurements (Heart Rate, Blood Pressure, SpO2, Temperature)
-- Heart Rate (3027018), Systolic BP (3004249), Diastolic BP (3012888), SpO2 (3024171), Temperature (3020891)

-- Patient 1 vital signs (ICU stay days)
INSERT INTO measurement (measurement_id, person_id, measurement_concept_id, measurement_date, measurement_datetime, measurement_type_concept_id, value_as_number, unit_concept_id, visit_occurrence_id, visit_detail_id) VALUES
-- Day 1
(1, 1, 3027018, '2024-01-05', '2024-01-05 10:00:00', 44818702, 105, 8541, 1, 1),  -- Heart rate: 105 bpm
(2, 1, 3004249, '2024-01-05', '2024-01-05 10:00:00', 44818702, 142, 8876, 1, 1),  -- SBP: 142 mmHg
(3, 1, 3012888, '2024-01-05', '2024-01-05 10:00:00', 44818702, 88, 8876, 1, 1),   -- DBP: 88 mmHg
(4, 1, 3024171, '2024-01-05', '2024-01-05 10:00:00', 44818702, 92, 8554, 1, 1),   -- SpO2: 92%
(5, 1, 3020891, '2024-01-05', '2024-01-05 10:00:00', 44818702, 38.2, 586323, 1, 1), -- Temp: 38.2°C
-- Day 2
(6, 1, 3027018, '2024-01-06', '2024-01-06 08:00:00', 44818702, 98, 8541, 1, 1),
(7, 1, 3004249, '2024-01-06', '2024-01-06 08:00:00', 44818702, 135, 8876, 1, 1),
(8, 1, 3012888, '2024-01-06', '2024-01-06 08:00:00', 44818702, 82, 8876, 1, 1),
(9, 1, 3024171, '2024-01-06', '2024-01-06 08:00:00', 44818702, 95, 8554, 1, 1),
(10, 1, 3020891, '2024-01-06', '2024-01-06 08:00:00', 44818702, 37.8, 586323, 1, 1);

-- Patient 2 vital signs
INSERT INTO measurement (measurement_id, person_id, measurement_concept_id, measurement_date, measurement_datetime, measurement_type_concept_id, value_as_number, unit_concept_id, visit_occurrence_id, visit_detail_id) VALUES
(11, 2, 3027018, '2024-01-10', '2024-01-10 14:00:00', 44818702, 88, 8541, 2, 2),
(12, 2, 3004249, '2024-01-10', '2024-01-10 14:00:00', 44818702, 118, 8876, 2, 2),
(13, 2, 3012888, '2024-01-10', '2024-01-10 14:00:00', 44818702, 75, 8876, 2, 2),
(14, 2, 3024171, '2024-01-10', '2024-01-10 14:00:00', 44818702, 89, 8554, 2, 2),
(15, 2, 3020891, '2024-01-10', '2024-01-10 14:00:00', 44818702, 37.1, 586323, 2, 2);

-- Insert lab results (common ICU labs)
-- Lactate (concept_id: 3006140), Creatinine (concept_id: 3016723), WBC (concept_id: 3000963)
INSERT INTO measurement (measurement_id, person_id, measurement_concept_id, measurement_date, measurement_datetime, measurement_type_concept_id, value_as_number, unit_concept_id, visit_occurrence_id) VALUES
(101, 1, 3006140, '2024-01-05', '2024-01-05 11:00:00', 44818702, 3.2, 8753, 1),  -- Lactate: 3.2 mmol/L
(102, 1, 3016723, '2024-01-05', '2024-01-05 11:00:00', 44818702, 1.8, 8840, 1),  -- Creatinine: 1.8 mg/dL
(103, 1, 3000963, '2024-01-05', '2024-01-05 11:00:00', 44818702, 15.2, 8795, 1), -- WBC: 15.2 K/uL
(104, 2, 3006140, '2024-01-10', '2024-01-10 15:00:00', 44818702, 2.1, 8753, 2),
(105, 2, 3016723, '2024-01-10', '2024-01-10 15:00:00', 44818702, 1.2, 8840, 2),
(106, 2, 3000963, '2024-01-10', '2024-01-10 15:00:00', 44818702, 12.8, 8795, 2);

-- Insert common ICU procedures
-- Mechanical ventilation (4230167), Central line insertion (4272240)
INSERT INTO procedure_occurrence (procedure_occurrence_id, person_id, procedure_concept_id, procedure_date, procedure_datetime, procedure_type_concept_id, visit_occurrence_id) VALUES
(1, 1, 4230167, '2024-01-05', '2024-01-05 10:30:00', 38000275, 1),  -- Mechanical ventilation
(2, 1, 4272240, '2024-01-05', '2024-01-05 09:45:00', 38000275, 1),  -- Central line
(3, 2, 4230167, '2024-01-10', '2024-01-10 13:30:00', 38000275, 2),
(4, 3, 4272240, '2024-01-15', '2024-01-15 19:30:00', 38000275, 3);

-- Insert common ICU medications
-- Norepinephrine (1335471), Propofol (739138), Fentanyl (1819229)
INSERT INTO drug_exposure (drug_exposure_id, person_id, drug_concept_id, drug_exposure_start_date, drug_exposure_start_datetime, drug_exposure_end_date, drug_exposure_end_datetime, drug_type_concept_id, visit_occurrence_id) VALUES
(1, 1, 1335471, '2024-01-05', '2024-01-05 11:00:00', '2024-01-07', '2024-01-07 08:00:00', 38000177, 1), -- Norepinephrine
(2, 1, 739138, '2024-01-05', '2024-01-05 10:00:00', '2024-01-08', '2024-01-08 06:00:00', 38000177, 1),  -- Propofol
(3, 1, 1819229, '2024-01-05', '2024-01-05 10:00:00', '2024-01-12', '2024-01-12 14:00:00', 38000177, 1), -- Fentanyl
(4, 2, 739138, '2024-01-10', '2024-01-10 14:00:00', '2024-01-15', '2024-01-15 10:00:00', 38000177, 2),
(5, 3, 1335471, '2024-01-16', '2024-01-16 08:00:00', '2024-01-20', '2024-01-20 12:00:00', 38000177, 3);

EOF

echo "Loading synthetic data into database..."
$PSQL -f $SYNTH_DIR/synthetic_data.sql

# Verify data load
echo ""
echo "========================================="
echo "Synthetic Data Summary"
echo "========================================="

$PSQL -c "
SET search_path TO cdm;

SELECT 
    'Patients' as entity, COUNT(*) as count FROM person
UNION ALL
SELECT 'Hospital Visits', COUNT(*) FROM visit_occurrence
UNION ALL
SELECT 'ICU Stays', COUNT(*) FROM visit_detail
UNION ALL
SELECT 'Diagnoses', COUNT(*) FROM condition_occurrence
UNION ALL
SELECT 'Measurements (Vitals/Labs)', COUNT(*) FROM measurement
UNION ALL
SELECT 'Procedures', COUNT(*) FROM procedure_occurrence
UNION ALL
SELECT 'Medications', COUNT(*) FROM drug_exposure;
"

echo ""
echo "Sample ICU patient data:"
$PSQL -c "
SET search_path TO cdm;

SELECT 
    p.person_id,
    p.gender_source_value as gender,
    2024 - p.year_of_birth as age,
    vo.visit_start_date as admission_date,
    vo.visit_end_date as discharge_date,
    c.care_site_name as icu_unit
FROM person p
JOIN visit_occurrence vo ON p.person_id = vo.person_id
JOIN care_site c ON vo.care_site_id = c.care_site_id
ORDER BY vo.visit_start_date
LIMIT 5;
"

echo ""
echo "========================================="
echo "Synthetic data loaded successfully!"
echo "========================================="
