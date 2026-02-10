# INDICATE Example Study: ICU Cohort Characterization
# This R script performs basic cohort analysis on ICU patients

library(DatabaseConnector)
library(jsonlite)

# Get database connection from environment
# For PostgreSQL, server format is: "host/database"
db_host <- Sys.getenv("DATABASE_HOST")
db_name <- Sys.getenv("DATABASE_NAME")
server_string <- paste0(db_host, "/", db_name)

# JDBC driver path (set in container environment)
jdbc_path <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER")
if (jdbc_path == "") {
    jdbc_path <- "/jdbc_drivers"
}

connectionDetails <- createConnectionDetails(
    dbms = "postgresql",
    server = server_string,
    port = as.integer(Sys.getenv("DATABASE_PORT")),
    user = Sys.getenv("DATABASE_USER"),
    password = Sys.getenv("DATABASE_PASSWORD"),
    pathToDriver = jdbc_path
)

# Connect to database
connection <- connect(connectionDetails)

# Query 1: ICU patient demographics (individual patients, not aggregated)
demographics_sql <- "
SELECT 
    p.person_id,
    p.gender_source_value as gender,
    2024 - p.year_of_birth as age
FROM cdm.person p
INNER JOIN cdm.visit_detail vd ON p.person_id = vd.person_id
ORDER BY p.person_id
"

demographics <- querySql(connection, demographics_sql)

# Convert column names to lowercase immediately after each query
names(demographics) <- tolower(names(demographics))

# Calculate age statistics from individual patients
age_stats <- list(
    mean = round(mean(demographics$age, na.rm = TRUE), 1),
    median = round(median(demographics$age, na.rm = TRUE), 1),
    min = min(demographics$age, na.rm = TRUE),
    max = max(demographics$age, na.rm = TRUE),
    sd = round(sd(demographics$age, na.rm = TRUE), 1)
)

# Create age groups for reporting
demographics$age_group <- cut(demographics$age, 
                               breaks = c(0, 40, 50, 60, 70, 80, 100),
                               labels = c("<40", "40-49", "50-59", "60-69", "70-79", "80+"),
                               right = FALSE)

# Aggregate demographics for reporting
demo_summary <- data.frame(
    gender = names(table(demographics$gender)),
    count = as.vector(table(demographics$gender))
)

age_group_summary <- data.frame(
    age_group = names(table(demographics$age_group)),
    count = as.vector(table(demographics$age_group))
)

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
names(diagnoses) <- tolower(names(diagnoses))

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
names(los_stats) <- tolower(names(los_stats))

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
names(vitals) <- tolower(names(vitals))

# Disconnect
disconnect(connection)

# Prepare results
results <- list(
    study_name = "ICU Cohort Characterization",
    study_type = "descriptive_analysis",
    execution_date = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    cohort = list(
        total_icu_patients = nrow(demographics),
        unique_patients = length(unique(demographics$person_id)),
        demographics_summary = list(
            by_gender = demo_summary,
            by_age_group = age_group_summary
        ),
        age_statistics = age_stats
    ),
    clinical_characteristics = list(
        common_diagnoses = diagnoses,
        length_of_stay = los_stats,
        vital_signs = vitals
    ),
    metadata = list(
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        ohdsi_version = as.character(packageVersion("DatabaseConnector")),
        omop_cdm_version = "5.4"
    )
)

# Output results as JSON
cat(toJSON(results, pretty = TRUE, auto_unbox = TRUE))