#!/bin/bash

################################################################################
# AWS S3 Migration Demo Setup Script
# 
# Creates S3 buckets with sample data to demonstrate migration scenarios.
# Generates test files and uploads them with tags and metadata.
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Configuration
configure_environment() {
    log_info "Configuring environment..."
    
    TIMESTAMP=$(date +%s)
    BUCKET_NAME="${BUCKET_PREFIX:-s3-migration-demo}-${TIMESTAMP}"
    
    REGION="${AWS_REGION:-us-east-1}"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    PROJECT_TAG="${PROJECT_TAG:-mmb}"
    COST_CENTER_TAG="${COST_CENTER_TAG:-123}"
    
    WORK_DIR="$HOME/s3-demo-files-${TIMESTAMP}"
    
    log_success "Environment configured"
    log_info "Bucket Name: ${BUCKET_NAME}"
    log_info "Region: ${REGION}"
}

# Create S3 bucket
create_bucket() {
    log_info "Creating S3 bucket..."
    
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    log_success "Created bucket: ${BUCKET_NAME}"
    
    # Tag bucket
    aws s3api put-bucket-tagging \
        --bucket "$BUCKET_NAME" \
        --tagging "TagSet=[{Key=project,Value=${PROJECT_TAG}},{Key=cost-center,Value=${COST_CENTER_TAG}}]"
    log_success "Tagged bucket"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    log_success "Enabled versioning"
}

# Generate test files
generate_files() {
    log_info "Generating test files..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Small files (1KB - 100KB)
    log_info "Generating small files (1-100KB)..."
    for i in {1..5}; do
        dd if=/dev/urandom of="small-file-${i}.bin" bs=1024 count=$((RANDOM % 100 + 1)) 2>/dev/null
    done
    
    # Medium files (1MB - 10MB)
    log_info "Generating medium files (1-10MB)..."
    for i in {1..5}; do
        dd if=/dev/urandom of="medium-file-${i}.bin" bs=1048576 count=$((RANDOM % 10 + 1)) 2>/dev/null
    done
    
    # Large files (10MB - 50MB)
    log_info "Generating large files (10-50MB)..."
    for i in {1..3}; do
        dd if=/dev/urandom of="large-file-${i}.bin" bs=1048576 count=$((RANDOM % 40 + 10)) 2>/dev/null
    done
    
    # Text files
    log_info "Creating text files..."
    echo "Migration demo document 1 - Project: ${PROJECT_TAG}" > document1.txt
    echo "Migration demo document 2 - Cost Center: ${COST_CENTER_TAG}" > document2.txt
    echo "Migration demo document 3 - Created: $(date)" > document3.txt
    
    # Create directory structure
    mkdir -p data/2024 data/2025 archives
    
    log_success "Generated $(ls -1 | wc -l) files"
    log_info "Total size: $(du -sh . | cut -f1)"
}

# Upload files
upload_files() {
    log_info "Uploading files to S3..."
    
    cd "$WORK_DIR"
    
    # Upload root level files
    log_info "Uploading root level files..."
    for file in *.bin *.txt; do
        if [ -f "$file" ]; then
            aws s3api put-object \
                --bucket "$BUCKET_NAME" \
                --key "$file" \
                --body "$file" \
                --storage-class STANDARD \
                --tagging "project=${PROJECT_TAG}&cost-center=${COST_CENTER_TAG}" \
                --metadata "uploaded-by=migration-demo,purpose=testing,timestamp=$(date +%s)" \
                > /dev/null
            log_success "Uploaded: $file"
        fi
    done
    
    # Organize files into folders
    log_info "Organizing files into folders..."
    mv small-file-* data/2024/ 2>/dev/null || true
    mv medium-file-* data/2025/ 2>/dev/null || true
    mv large-file-* archives/ 2>/dev/null || true
    
    # Upload 2024 data
    log_info "Uploading 2024 data..."
    for file in data/2024/*; do
        if [ -f "$file" ]; then
            aws s3api put-object \
                --bucket "$BUCKET_NAME" \
                --key "$file" \
                --body "$file" \
                --storage-class STANDARD \
                --tagging "project=${PROJECT_TAG}&cost-center=${COST_CENTER_TAG}&year=2024" \
                --metadata "year=2024,category=historical" \
                > /dev/null
            log_success "Uploaded: $file"
        fi
    done
    
    # Upload 2025 data
    log_info "Uploading 2025 data..."
    for file in data/2025/*; do
        if [ -f "$file" ]; then
            aws s3api put-object \
                --bucket "$BUCKET_NAME" \
                --key "$file" \
                --body "$file" \
                --storage-class STANDARD \
                --tagging "project=${PROJECT_TAG}&cost-center=${COST_CENTER_TAG}&year=2025" \
                --metadata "year=2025,category=current" \
                > /dev/null
            log_success "Uploaded: $file"
        fi
    done
    
    # Upload archives
    log_info "Uploading archives..."
    for file in archives/*; do
        if [ -f "$file" ]; then
            aws s3api put-object \
                --bucket "$BUCKET_NAME" \
                --key "$file" \
                --body "$file" \
                --storage-class GLACIER \
                --tagging "project=${PROJECT_TAG}&cost-center=${COST_CENTER_TAG}&type=archive" \
                --metadata "type=archive,retention=long-term" \
                > /dev/null
            log_success "Uploaded: $file"
        fi
    done
    
    log_success "All files uploaded"
    aws s3 ls "s3://${BUCKET_NAME}" --recursive --human-readable
}

# Create summary
create_summary() {
    SUMMARY_FILE="$HOME/s3-migration-demo-${TIMESTAMP}.txt"
    
    cat > "$SUMMARY_FILE" <<EOF
AWS S3 Migration Demo Setup
===========================
Date: $(date)

BUCKET INFORMATION
------------------
Bucket Name: ${BUCKET_NAME}
Region: ${REGION}
Tags: project=${PROJECT_TAG}, cost-center=${COST_CENTER_TAG}

NEXT STEPS
----------
1. Extract object details for migration (CSV format):
   ./get-s3-object-details.sh ${BUCKET_NAME} csv > migration-inventory.csv

2. Clean up when done:
   ./cleanup-s3-demo.sh ${BUCKET_NAME}

BUCKET URL
----------
https://s3.console.aws.amazon.com/s3/buckets/${BUCKET_NAME}
EOF
    
    log_success "Summary saved: ${SUMMARY_FILE}"
    cat "$SUMMARY_FILE"
}

# Cleanup temp
cleanup_temp() {
    if [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

# Main
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         AWS S3 Migration Demo Setup                        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    configure_environment
    
    echo ""
    log_warning "This will create AWS resources that incur costs."
    read -p "Continue? (yes/no): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    create_bucket
    echo ""
    generate_files
    echo ""
    upload_files
    echo ""
    cleanup_temp
    echo ""
    create_summary
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    SETUP COMPLETE                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log_success "Bucket created: ${BUCKET_NAME}"
    log_info "Next: ./get-s3-object-details.sh ${BUCKET_NAME} csv > migration-inventory.csv
    echo ""
}

main "$@"
