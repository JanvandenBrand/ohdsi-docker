# INDICATE Example Study: ICU Cohort Characterization
# This R script performs basic cohort analysis on ICU patients

library(DatabaseConnector)
library(jsonlite)

db_host <- Sys.getenv("DATABASE_HOST")
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

# Connect to database
connection <- connect(connectionDetails)

# Query 1: ICU patient demographics
demographics_sql <- "
SELECT 
    gender_source_value as gender,
    2024 - year_of_birth as age,
    COUNT(DISTINCT p.person_id) as patient_count
FROM cdm.person p
INNER JOIN cdm.visit_detail vd ON p.person_id = vd.person_id
GROUP BY gender_source_value, year_of_birth
ORDER BY patient_count DESC
"

demographics <- querySql(connection, demographics_sql)

# Query 2: Common ICU diagnoses
diagnoses_sql <- "
SELECT 
    c.concept_name as diagnosis,
    c.vocabulary_id,
    COUNT(DISTINCT co.person_id) as patient_count
FROM cdm.condition_occurrence co
JOIN vocab.concept c ON co.condition_concept_id = c.concept_id
JOIN cdm.visit_detail vd ON co.visit_detail_id = vd.visit_detail_id
WHERE c.concept_name IS NOT NULL
GROUP BY c.concept_name, c.vocabulary_id
ORDER BY patient_count DESC
LIMIT 10
"

diagnoses <- querySql(connection, diagnoses_sql)

# Query 3: ICU length of stay statistics
los_sql <- "
SELECT 
    AVG(EXTRACT(EPOCH FROM (visit_detail_end_datetime - visit_detail_start_datetime))/86400) as avg_los_days,
    MIN(EXTRACT(EPOCH FROM (visit_detail_end_datetime - visit_detail_start_datetime))/86400) as min_los_days,
    MAX(EXTRACT(EPOCH FROM (visit_detail_end_datetime - visit_detail_start_datetime))/86400) as max_los_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (visit_detail_end_datetime - visit_detail_start_datetime))/86400) as median_los_days
FROM cdm.visit_detail
"

los_stats <- querySql(connection, los_sql)

# Query 4: Vital signs summary
vitals_sql <- "
SELECT 
    c.concept_name as measurement,
    COUNT(*) as measurement_count,
    AVG(m.value_as_number) as mean_value,
    STDDEV(m.value_as_number) as std_value,
    MIN(m.value_as_number) as min_value,
    MAX(m.value_as_number) as max_value
FROM cdm.measurement m
JOIN vocab.concept c ON m.measurement_concept_id = c.concept_id
WHERE m.measurement_concept_id IN (3027018, 3004249, 3012888, 3024171, 3020891)
    AND m.value_as_number IS NOT NULL
GROUP BY c.concept_name
ORDER BY measurement_count DESC
"

vitals <- querySql(connection, vitals_sql)

# Disconnect
disconnect(connection)

# Prepare results
results <- list(
    study_name = "ICU Cohort Characterization",
    study_type = "descriptive_analysis",
    execution_date = Sys.time(),
    cohort = list(
        total_icu_patients = nrow(demographics),
        demographics = demographics,
        age_summary = list(
            mean = mean(demographics$AGE, na.rm = TRUE),
            median = median(demographics$AGE, na.rm = TRUE),
            min = min(demographics$AGE, na.rm = TRUE),
            max = max(demographics$AGE, na.rm = TRUE)
        )
    ),
    clinical_characteristics = list(
        common_diagnoses = diagnoses,
        length_of_stay = los_stats,
        vital_signs = vitals
    ),
    metadata = list(
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        ohdsi_version = packageVersion("DatabaseConnector"),
        omop_cdm_version = "5.4"
    )
)

# Output results as JSON
cat(toJSON(results, pretty = TRUE, auto_unbox = TRUE))
