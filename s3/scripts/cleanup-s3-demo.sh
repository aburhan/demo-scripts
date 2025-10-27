#!/bin/bash

################################################################################
# AWS S3 Migration Demo Cleanup Script
# 
# Removes S3 buckets and objects created by setup-s3-demo.sh
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

# Usage
if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name>"
    echo ""
    echo "Example:"
    echo "  $0 s3-migration-demo-1234567890"
    echo ""
    echo "To list buckets:"
    echo "  aws s3 ls"
    exit 1
fi

BUCKET_NAME=$1

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          AWS S3 Migration Demo Cleanup                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if bucket exists
log_info "Checking bucket: $BUCKET_NAME"

if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log_error "Bucket does not exist or is not accessible"
    exit 1
fi

log_success "Bucket found"

# Count objects
OBJECT_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}" --recursive | wc -l)
log_info "Found $OBJECT_COUNT objects in bucket"

# Confirm deletion
echo ""
log_warning "This will DELETE the bucket and all $OBJECT_COUNT objects!"
log_warning "Bucket: $BUCKET_NAME"
echo ""
read -p "Are you sure? Type 'DELETE' to confirm: " -r
echo ""

if [ "$REPLY" != "DELETE" ]; then
    log_info "Cleanup cancelled"
    exit 0
fi

# Delete all objects and versions
log_info "Deleting all objects and versions..."

# Delete object versions
if aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" | grep -q "Enabled"; then
    log_info "Versioning is enabled, deleting all versions..."
    
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true
    
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true
fi

# Delete regular objects
aws s3 rm "s3://${BUCKET_NAME}" --recursive --quiet

log_success "Objects deleted"

# Delete bucket
log_info "Deleting bucket..."
aws s3 rb "s3://${BUCKET_NAME}"

log_success "Bucket deleted"

# Cleanup local files
log_info "Cleaning up local files..."
rm -f "$HOME"/s3-migration-demo-*.txt 2>/dev/null || true
log_success "Local files cleaned"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 CLEANUP COMPLETE                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
log_success "Bucket $BUCKET_NAME has been deleted"
echo ""
