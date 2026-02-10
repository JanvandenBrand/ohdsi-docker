#!/bin/bash
# INDICATE SPE Quick Start Script
# Automates the setup and validation of the local test environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=============================================="
echo "  INDICATE SPE Local Environment Setup"
echo "=============================================="
echo -e "${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Step 1: Check prerequisites
echo ""
echo "Step 1: Checking prerequisites..."
echo "--------------------------------"

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_status "Docker found: $DOCKER_VERSION"
else
    print_error "Docker not found. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_status "Docker Compose found: $COMPOSE_VERSION"
else
    print_error "Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

# Check disk space
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 50 ]; then
    print_warning "Low disk space: ${AVAILABLE_SPACE}GB available (50GB recommended)"
else
    print_status "Sufficient disk space: ${AVAILABLE_SPACE}GB available"
fi

# Check vocabularies
echo ""
echo "Step 2: Checking vocabulary files..."
echo "------------------------------------"

if [ -d "vocabularies" ] && [ -f "vocabularies/CONCEPT.csv" ]; then
    print_status "Vocabulary files found"
    VOCAB_SIZE=$(du -sh vocabularies | cut -f1)
    print_info "Vocabulary directory size: $VOCAB_SIZE"
else
    print_error "Vocabulary files not found in ./vocabularies/"
    echo ""
    echo "Please download vocabularies from https://athena.ohdsi.org/"
    echo "Required vocabularies: ATC, Gender, ICD10, LOINC, RxNorm, RxNorm Extension, SNOMED, UCUM"
    echo "Extract the downloaded zip to ./vocabularies/ directory"
    echo ""
    read -p "Press Enter when vocabularies are ready, or Ctrl+C to exit..."
fi

# Step 3: Build Docker images
echo ""
echo "Step 3: Building Docker images..."
echo "---------------------------------"
print_warning "This may take 10-20 minutes on first run..."

if docker-compose build; then
    print_status "Docker images built successfully"
else
    print_error "Failed to build Docker images"
    exit 1
fi

# Step 4: Start services
echo ""
echo "Step 4: Starting services..."
echo "----------------------------"

if docker-compose up -d; then
    print_status "Services started"
else
    print_error "Failed to start services"
    exit 1
fi

# Wait for database to be ready
echo ""
print_info "Waiting for database to be ready..."
sleep 10

MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose exec -T omop-db pg_isready -U omop_user -d omop_cdm &> /dev/null; then
        print_status "Database is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "Database failed to start"
    exit 1
fi

# Step 5: Load vocabularies
echo ""
echo "Step 5: Loading vocabularies..."
echo "-------------------------------"
print_warning "This may take 15-30 minutes..."

if docker-compose exec -T omop-db /docker-entrypoint-initdb.d/02-load-vocabularies.sh; then
    print_status "Vocabularies loaded successfully"
else
    print_error "Failed to load vocabularies"
    exit 1
fi

# Step 6: Load synthetic data
echo ""
echo "Step 6: Loading synthetic data..."
echo "---------------------------------"

if docker-compose exec -T omop-db /docker-entrypoint-initdb.d/03-load-synthetic-data.sh; then
    print_status "Synthetic data loaded successfully"
else
    print_error "Failed to load synthetic data"
    exit 1
fi

# Step 7: Test services
echo ""
echo "Step 7: Testing services..."
echo "---------------------------"

# Test Backend API
if curl -s -f http://localhost:8000/health > /dev/null; then
    print_status "Backend API is responding"
else
    print_error "Backend API is not responding"
fi

# Test Code Executor
if curl -s -f http://localhost:8001/health > /dev/null; then
    print_status "Code Executor is responding"
else
    print_error "Code Executor is not responding"
fi

# Test Dashboard
if curl -s -f http://localhost:8501 > /dev/null; then
    print_status "Data Quality Dashboard is responding"
else
    print_warning "Data Quality Dashboard may still be starting up"
fi

# Test Database
PATIENT_COUNT=$(docker-compose exec -T omop-db psql -U omop_user -d omop_cdm -t -c "SELECT COUNT(*) FROM cdm.person;" | xargs)
if [ "$PATIENT_COUNT" -gt 0 ]; then
    print_status "Database has $PATIENT_COUNT patients"
else
    print_warning "Database query returned unexpected count"
fi

# Summary
echo ""
echo -e "${GREEN}"
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo -e "${NC}"
echo ""
echo "Service URLs:"
echo "  • Backend API:        http://localhost:8000"
echo "  • Code Executor:      http://localhost:8001"
echo "  • DQ Dashboard:       http://localhost:8501"
echo "  • PostgreSQL:         localhost:5432"
echo ""
echo "Test the setup:"
echo "  curl http://localhost:8000/dataset/summary"
echo ""
echo "Run example study:"
echo "  See SETUP_GUIDE.md for detailed instructions"
echo ""
echo "View service logs:"
echo "  docker-compose logs -f"
echo ""
echo "Stop services:"
echo "  docker-compose down"
echo ""
echo -e "${BLUE}For detailed usage, see SETUP_GUIDE.md${NC}"
echo ""
