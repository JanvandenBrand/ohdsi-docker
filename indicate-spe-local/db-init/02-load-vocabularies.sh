#!/bin/bash
# Script to load OMOP vocabularies from Athena download
# This script should be run after you've downloaded vocabularies from athena.ohdsi.org

set -e

VOCAB_DIR="/vocabularies"
PSQL="psql -U $POSTGRES_USER -d $POSTGRES_DB"

echo "========================================="
echo "Loading OMOP Vocabularies from Athena"
echo "========================================="

# Check if vocabulary files exist
if [ ! -f "$VOCAB_DIR/CONCEPT.csv" ]; then
    echo "ERROR: Vocabulary files not found in $VOCAB_DIR"
    echo "Please download vocabularies from https://athena.ohdsi.org/"
    echo "Required vocabularies: ATC, Gender, ICD10, LOINC, RxNorm, RxNorm Extension, SNOMED"
    echo "Extract the downloaded zip file to ./vocabularies/ directory"
    exit 1
fi

echo "Vocabulary files found. Starting load..."

# Set search path
$PSQL -c "SET search_path TO vocab;"

# Load CONCEPT table (largest table, will take a few minutes)
echo "Loading CONCEPT table..."
$PSQL -c "\COPY vocab.concept FROM '$VOCAB_DIR/CONCEPT.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load VOCABULARY table
echo "Loading VOCABULARY table..."
$PSQL -c "\COPY vocab.vocabulary FROM '$VOCAB_DIR/VOCABULARY.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load DOMAIN table
echo "Loading DOMAIN table..."
$PSQL -c "\COPY vocab.domain FROM '$VOCAB_DIR/DOMAIN.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load CONCEPT_CLASS table
echo "Loading CONCEPT_CLASS table..."
$PSQL -c "\COPY vocab.concept_class FROM '$VOCAB_DIR/CONCEPT_CLASS.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load CONCEPT_RELATIONSHIP table (large table)
echo "Loading CONCEPT_RELATIONSHIP table..."
$PSQL -c "\COPY vocab.concept_relationship FROM '$VOCAB_DIR/CONCEPT_RELATIONSHIP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load RELATIONSHIP table
echo "Loading RELATIONSHIP table..."
$PSQL -c "\COPY vocab.relationship FROM '$VOCAB_DIR/RELATIONSHIP.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load CONCEPT_SYNONYM table
echo "Loading CONCEPT_SYNONYM table..."
$PSQL -c "\COPY vocab.concept_synonym FROM '$VOCAB_DIR/CONCEPT_SYNONYM.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load CONCEPT_ANCESTOR table (large table, creates hierarchy)
echo "Loading CONCEPT_ANCESTOR table..."
$PSQL -c "\COPY vocab.concept_ancestor FROM '$VOCAB_DIR/CONCEPT_ANCESTOR.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Load DRUG_STRENGTH table
echo "Loading DRUG_STRENGTH table..."
$PSQL -c "\COPY vocab.drug_strength FROM '$VOCAB_DIR/DRUG_STRENGTH.csv' WITH DELIMITER E'\t' CSV HEADER QUOTE E'\b';"

# Verify loaded vocabularies
echo ""
echo "========================================="
echo "Vocabulary Load Summary"
echo "========================================="

$PSQL -c "
SELECT 
    v.vocabulary_id,
    v.vocabulary_name,
    v.vocabulary_version,
    COUNT(c.concept_id) as concept_count
FROM vocab.vocabulary v
LEFT JOIN vocab.concept c ON v.vocabulary_id = c.vocabulary_id
GROUP BY v.vocabulary_id, v.vocabulary_name, v.vocabulary_version
ORDER BY v.vocabulary_id;
"

echo ""
echo "Total concepts loaded:"
$PSQL -t -c "SELECT COUNT(*) FROM vocab.concept;"

echo ""
echo "========================================="
echo "Vocabularies loaded successfully!"
echo "========================================="
