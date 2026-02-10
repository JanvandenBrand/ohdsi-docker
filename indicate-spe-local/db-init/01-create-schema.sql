-- OMOP CDM v5.4 PostgreSQL DDL
-- This script creates the core OMOP tables needed for a basic SPE test
-- Full schema available at: https://github.com/OHDSI/CommonDataModel

-- Create schemas
CREATE SCHEMA IF NOT EXISTS cdm;
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE SCHEMA IF NOT EXISTS results;

SET search_path TO cdm;

/*************************
 STANDARDIZED CLINICAL DATA
*************************/

-- PERSON: Demographics
CREATE TABLE person (
    person_id INTEGER NOT NULL,
    gender_concept_id INTEGER NOT NULL,
    year_of_birth INTEGER NOT NULL,
    month_of_birth INTEGER,
    day_of_birth INTEGER,
    birth_datetime TIMESTAMP,
    race_concept_id INTEGER NOT NULL,
    ethnicity_concept_id INTEGER NOT NULL,
    location_id INTEGER,
    provider_id INTEGER,
    care_site_id INTEGER,
    person_source_value VARCHAR(50),
    gender_source_value VARCHAR(50),
    gender_source_concept_id INTEGER,
    race_source_value VARCHAR(50),
    race_source_concept_id INTEGER,
    ethnicity_source_value VARCHAR(50),
    ethnicity_source_concept_id INTEGER
);

-- OBSERVATION_PERIOD: Enrollment periods
CREATE TABLE observation_period (
    observation_period_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    observation_period_start_date DATE NOT NULL,
    observation_period_end_date DATE NOT NULL,
    period_type_concept_id INTEGER NOT NULL
);

-- VISIT_OCCURRENCE: Patient encounters
CREATE TABLE visit_occurrence (
    visit_occurrence_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    visit_concept_id INTEGER NOT NULL,
    visit_start_date DATE NOT NULL,
    visit_start_datetime TIMESTAMP,
    visit_end_date DATE NOT NULL,
    visit_end_datetime TIMESTAMP,
    visit_type_concept_id INTEGER NOT NULL,
    provider_id INTEGER,
    care_site_id INTEGER,
    visit_source_value VARCHAR(50),
    visit_source_concept_id INTEGER,
    admitted_from_concept_id INTEGER,
    admitted_from_source_value VARCHAR(50),
    discharged_to_concept_id INTEGER,
    discharged_to_source_value VARCHAR(50),
    preceding_visit_occurrence_id INTEGER
);

-- VISIT_DETAIL: Detailed visit information (ICU stays)
CREATE TABLE visit_detail (
    visit_detail_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    visit_detail_concept_id INTEGER NOT NULL,
    visit_detail_start_date DATE NOT NULL,
    visit_detail_start_datetime TIMESTAMP,
    visit_detail_end_date DATE NOT NULL,
    visit_detail_end_datetime TIMESTAMP,
    visit_detail_type_concept_id INTEGER NOT NULL,
    provider_id INTEGER,
    care_site_id INTEGER,
    visit_detail_source_value VARCHAR(50),
    visit_detail_source_concept_id INTEGER,
    admitted_from_concept_id INTEGER,
    admitted_from_source_value VARCHAR(50),
    discharged_to_source_value VARCHAR(50),
    discharged_to_concept_id INTEGER,
    preceding_visit_detail_id INTEGER,
    parent_visit_detail_id INTEGER,
    visit_occurrence_id INTEGER NOT NULL
);

-- CONDITION_OCCURRENCE: Diagnoses
CREATE TABLE condition_occurrence (
    condition_occurrence_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    condition_concept_id INTEGER NOT NULL,
    condition_start_date DATE NOT NULL,
    condition_start_datetime TIMESTAMP,
    condition_end_date DATE,
    condition_end_datetime TIMESTAMP,
    condition_type_concept_id INTEGER NOT NULL,
    condition_status_concept_id INTEGER,
    stop_reason VARCHAR(20),
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    condition_source_value VARCHAR(50),
    condition_source_concept_id INTEGER,
    condition_status_source_value VARCHAR(50)
);

-- DRUG_EXPOSURE: Medications
CREATE TABLE drug_exposure (
    drug_exposure_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    drug_concept_id INTEGER NOT NULL,
    drug_exposure_start_date DATE NOT NULL,
    drug_exposure_start_datetime TIMESTAMP,
    drug_exposure_end_date DATE NOT NULL,
    drug_exposure_end_datetime TIMESTAMP,
    verbatim_end_date DATE,
    drug_type_concept_id INTEGER NOT NULL,
    stop_reason VARCHAR(20),
    refills INTEGER,
    quantity NUMERIC,
    days_supply INTEGER,
    sig TEXT,
    route_concept_id INTEGER,
    lot_number VARCHAR(50),
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    drug_source_value VARCHAR(50),
    drug_source_concept_id INTEGER,
    route_source_value VARCHAR(50),
    dose_unit_source_value VARCHAR(50)
);

-- PROCEDURE_OCCURRENCE: Procedures
CREATE TABLE procedure_occurrence (
    procedure_occurrence_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    procedure_concept_id INTEGER NOT NULL,
    procedure_date DATE NOT NULL,
    procedure_datetime TIMESTAMP,
    procedure_end_date DATE,
    procedure_end_datetime TIMESTAMP,
    procedure_type_concept_id INTEGER NOT NULL,
    modifier_concept_id INTEGER,
    quantity INTEGER,
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    procedure_source_value VARCHAR(50),
    procedure_source_concept_id INTEGER,
    modifier_source_value VARCHAR(50)
);

-- MEASUREMENT: Lab results and vitals (CRITICAL for ICU)
CREATE TABLE measurement (
    measurement_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    measurement_concept_id INTEGER NOT NULL,
    measurement_date DATE NOT NULL,
    measurement_datetime TIMESTAMP,
    measurement_time VARCHAR(10),
    measurement_type_concept_id INTEGER NOT NULL,
    operator_concept_id INTEGER,
    value_as_number NUMERIC,
    value_as_concept_id INTEGER,
    unit_concept_id INTEGER,
    range_low NUMERIC,
    range_high NUMERIC,
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    measurement_source_value VARCHAR(50),
    measurement_source_concept_id INTEGER,
    unit_source_value VARCHAR(50),
    unit_source_concept_id INTEGER,
    value_source_value VARCHAR(50),
    measurement_event_id INTEGER,
    meas_event_field_concept_id INTEGER
);

-- OBSERVATION: Additional clinical observations
CREATE TABLE observation (
    observation_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    observation_concept_id INTEGER NOT NULL,
    observation_date DATE NOT NULL,
    observation_datetime TIMESTAMP,
    observation_type_concept_id INTEGER NOT NULL,
    value_as_number NUMERIC,
    value_as_string VARCHAR(60),
    value_as_concept_id INTEGER,
    qualifier_concept_id INTEGER,
    unit_concept_id INTEGER,
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    observation_source_value VARCHAR(50),
    observation_source_concept_id INTEGER,
    unit_source_value VARCHAR(50),
    qualifier_source_value VARCHAR(50),
    value_source_value VARCHAR(50),
    observation_event_id INTEGER,
    obs_event_field_concept_id INTEGER
);

-- DEATH: Death records
CREATE TABLE death (
    person_id INTEGER NOT NULL,
    death_date DATE NOT NULL,
    death_datetime TIMESTAMP,
    death_type_concept_id INTEGER,
    cause_concept_id INTEGER,
    cause_source_value VARCHAR(50),
    cause_source_concept_id INTEGER
);

/*************************
 HEALTH SYSTEM DATA
*************************/

-- LOCATION
CREATE TABLE location (
    location_id INTEGER NOT NULL,
    address_1 VARCHAR(50),
    address_2 VARCHAR(50),
    city VARCHAR(50),
    state VARCHAR(2),
    zip VARCHAR(9),
    county VARCHAR(20),
    location_source_value VARCHAR(50),
    country_concept_id INTEGER,
    country_source_value VARCHAR(80),
    latitude NUMERIC,
    longitude NUMERIC
);

-- CARE_SITE: ICU, wards, etc.
CREATE TABLE care_site (
    care_site_id INTEGER NOT NULL,
    care_site_name VARCHAR(255),
    place_of_service_concept_id INTEGER,
    location_id INTEGER,
    care_site_source_value VARCHAR(50),
    place_of_service_source_value VARCHAR(50)
);

-- PROVIDER: Healthcare providers
CREATE TABLE provider (
    provider_id INTEGER NOT NULL,
    provider_name VARCHAR(255),
    npi VARCHAR(20),
    dea VARCHAR(20),
    specialty_concept_id INTEGER,
    care_site_id INTEGER,
    year_of_birth INTEGER,
    gender_concept_id INTEGER,
    provider_source_value VARCHAR(50),
    specialty_source_value VARCHAR(50),
    specialty_source_concept_id INTEGER,
    gender_source_value VARCHAR(50),
    gender_source_concept_id INTEGER
);

/*************************
 VOCABULARY TABLES
*************************/

SET search_path TO vocab;

CREATE TABLE concept (
    concept_id INTEGER NOT NULL,
    concept_name VARCHAR(255) NOT NULL,
    domain_id VARCHAR(20) NOT NULL,
    vocabulary_id VARCHAR(20) NOT NULL,
    concept_class_id VARCHAR(20) NOT NULL,
    standard_concept VARCHAR(1),
    concept_code VARCHAR(50) NOT NULL,
    valid_start_date DATE NOT NULL,
    valid_end_date DATE NOT NULL,
    invalid_reason VARCHAR(1)
);

CREATE TABLE vocabulary (
    vocabulary_id VARCHAR(20) NOT NULL,
    vocabulary_name VARCHAR(255) NOT NULL,
    vocabulary_reference VARCHAR(255),
    vocabulary_version VARCHAR(255),
    vocabulary_concept_id INTEGER NOT NULL
);

CREATE TABLE domain (
    domain_id VARCHAR(20) NOT NULL,
    domain_name VARCHAR(255) NOT NULL,
    domain_concept_id INTEGER NOT NULL
);

CREATE TABLE concept_class (
    concept_class_id VARCHAR(20) NOT NULL,
    concept_class_name VARCHAR(255) NOT NULL,
    concept_class_concept_id INTEGER NOT NULL
);

CREATE TABLE concept_relationship (
    concept_id_1 INTEGER NOT NULL,
    concept_id_2 INTEGER NOT NULL,
    relationship_id VARCHAR(20) NOT NULL,
    valid_start_date DATE NOT NULL,
    valid_end_date DATE NOT NULL,
    invalid_reason VARCHAR(1)
);

CREATE TABLE relationship (
    relationship_id VARCHAR(20) NOT NULL,
    relationship_name VARCHAR(255) NOT NULL,
    is_hierarchical VARCHAR(1) NOT NULL,
    defines_ancestry VARCHAR(1) NOT NULL,
    reverse_relationship_id VARCHAR(20) NOT NULL,
    relationship_concept_id INTEGER NOT NULL
);

CREATE TABLE concept_synonym (
    concept_id INTEGER NOT NULL,
    concept_synonym_name VARCHAR(1000) NOT NULL,
    language_concept_id INTEGER NOT NULL
);

CREATE TABLE concept_ancestor (
    ancestor_concept_id INTEGER NOT NULL,
    descendant_concept_id INTEGER NOT NULL,
    min_levels_of_separation INTEGER NOT NULL,
    max_levels_of_separation INTEGER NOT NULL
);

CREATE TABLE drug_strength (
    drug_concept_id INTEGER NOT NULL,
    ingredient_concept_id INTEGER NOT NULL,
    amount_value NUMERIC,
    amount_unit_concept_id INTEGER,
    numerator_value NUMERIC,
    numerator_unit_concept_id INTEGER,
    denominator_value NUMERIC,
    denominator_unit_concept_id INTEGER,
    box_size INTEGER,
    valid_start_date DATE NOT NULL,
    valid_end_date DATE NOT NULL,
    invalid_reason VARCHAR(1)
);

/*************************
 PRIMARY KEYS
*************************/

SET search_path TO cdm;

ALTER TABLE person ADD CONSTRAINT xpk_person PRIMARY KEY (person_id);
ALTER TABLE observation_period ADD CONSTRAINT xpk_observation_period PRIMARY KEY (observation_period_id);
ALTER TABLE visit_occurrence ADD CONSTRAINT xpk_visit_occurrence PRIMARY KEY (visit_occurrence_id);
ALTER TABLE visit_detail ADD CONSTRAINT xpk_visit_detail PRIMARY KEY (visit_detail_id);
ALTER TABLE condition_occurrence ADD CONSTRAINT xpk_condition_occurrence PRIMARY KEY (condition_occurrence_id);
ALTER TABLE drug_exposure ADD CONSTRAINT xpk_drug_exposure PRIMARY KEY (drug_exposure_id);
ALTER TABLE procedure_occurrence ADD CONSTRAINT xpk_procedure_occurrence PRIMARY KEY (procedure_occurrence_id);
ALTER TABLE measurement ADD CONSTRAINT xpk_measurement PRIMARY KEY (measurement_id);
ALTER TABLE observation ADD CONSTRAINT xpk_observation PRIMARY KEY (observation_id);
ALTER TABLE location ADD CONSTRAINT xpk_location PRIMARY KEY (location_id);
ALTER TABLE care_site ADD CONSTRAINT xpk_care_site PRIMARY KEY (care_site_id);
ALTER TABLE provider ADD CONSTRAINT xpk_provider PRIMARY KEY (provider_id);

SET search_path TO vocab;

ALTER TABLE concept ADD CONSTRAINT xpk_concept PRIMARY KEY (concept_id);
ALTER TABLE vocabulary ADD CONSTRAINT xpk_vocabulary PRIMARY KEY (vocabulary_id);
ALTER TABLE domain ADD CONSTRAINT xpk_domain PRIMARY KEY (domain_id);
ALTER TABLE concept_class ADD CONSTRAINT xpk_concept_class PRIMARY KEY (concept_class_id);
ALTER TABLE relationship ADD CONSTRAINT xpk_relationship PRIMARY KEY (relationship_id);

/*************************
 INDEXES (Essential for performance)
*************************/

SET search_path TO cdm;

CREATE INDEX idx_person_id ON person (person_id);
CREATE INDEX idx_gender ON person (gender_concept_id);
CREATE INDEX idx_observation_period_person ON observation_period (person_id);
CREATE INDEX idx_visit_person ON visit_occurrence (person_id);
CREATE INDEX idx_visit_concept ON visit_occurrence (visit_concept_id);
CREATE INDEX idx_condition_person ON condition_occurrence (person_id);
CREATE INDEX idx_condition_concept ON condition_occurrence (condition_concept_id);
CREATE INDEX idx_drug_person ON drug_exposure (person_id);
CREATE INDEX idx_drug_concept ON drug_exposure (drug_concept_id);
CREATE INDEX idx_procedure_person ON procedure_occurrence (person_id);
CREATE INDEX idx_measurement_person ON measurement (person_id);
CREATE INDEX idx_measurement_concept ON measurement (measurement_concept_id);
CREATE INDEX idx_observation_person ON observation (person_id);

SET search_path TO vocab;

CREATE INDEX idx_concept_code ON concept (concept_code);
CREATE INDEX idx_concept_vocabid ON concept (vocabulary_id);
CREATE INDEX idx_concept_domain_id ON concept (domain_id);
CREATE INDEX idx_concept_class_id ON concept (concept_class_id);
CREATE INDEX idx_concept_rel_id1 ON concept_relationship (concept_id_1);
CREATE INDEX idx_concept_rel_id2 ON concept_relationship (concept_id_2);
CREATE INDEX idx_concept_ancestor_id1 ON concept_ancestor (ancestor_concept_id);
CREATE INDEX idx_concept_ancestor_id2 ON concept_ancestor (descendant_concept_id);

-- Grant permissions
GRANT USAGE ON SCHEMA cdm TO omop_user;
GRANT USAGE ON SCHEMA vocab TO omop_user;
GRANT USAGE ON SCHEMA results TO omop_user;
GRANT SELECT ON ALL TABLES IN SCHEMA cdm TO omop_user;
GRANT SELECT ON ALL TABLES IN SCHEMA vocab TO omop_user;
GRANT ALL ON ALL TABLES IN SCHEMA results TO omop_user;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'OMOP CDM v5.4 schema created successfully';
    RAISE NOTICE 'Schemas: cdm (clinical data), vocab (vocabularies), results (analytics)';
END $$;
