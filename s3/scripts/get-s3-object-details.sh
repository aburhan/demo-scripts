#!/bin/bash

################################################################################
# S3 Object Details Extractor (Without S3 Inventory)
# 
# This script retrieves detailed information about all objects in an S3 bucket
# without using S3 Inventory. It queries S3 directly using AWS CLI.
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

BUCKET_NAME=""
OUTPUT_FORMAT="csv"

if [ "$#" -eq 1 ]; then
  if [[ "$1" == "csv" || "$1" == "json" || "$1" == "table" ]]; then
    OUTPUT_FORMAT="$1"
  else
    BUCKET_NAME="$1"
  fi
elif [ "$#" -eq 2 ]; then
  BUCKET_NAME="$1"
  OUTPUT_FORMAT="$2"
fi

if [ -z "$BUCKET_NAME" ]; then
    # If no argument, find the latest bucket using BUCKET_PREFIX
    log_info "Bucket name not provided, searching for the latest bucket with BUCKET_PREFIX..."
    
    BUCKET_PREFIX=${BUCKET_PREFIX:-mmb}
    
    # Find the latest bucket matching the prefix
    LATEST_BUCKET=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, \`$BUCKET_PREFIX\`)].Name" --output text | tr '\\t' '\\n' | sort -r | head -n 1)
    
    if [ -z "$LATEST_BUCKET" ]; then
        log_error "No bucket found with prefix: $BUCKET_PREFIX"
        log_error "You can either:"
        log_error "1. Run ./setup-s3-demo.sh to create a new bucket."
        log_error "2. Set the BUCKET_PREFIX environment variable correctly."
        log_error "3. Pass the bucket name as an argument: $0 <bucket-name>"
        exit 1
    fi
    
    BUCKET_NAME=$LATEST_BUCKET
    log_success "Automatically selected latest bucket: $BUCKET_NAME"
fi
OUTPUT_FILE="s3-inventory-${BUCKET_NAME}-$(date +%Y%m%d-%H%M%S).${OUTPUT_FORMAT}"

log_info "Analyzing bucket: $BUCKET_NAME"
log_info "Output format: $OUTPUT_FORMAT"

# Check if bucket exists and get its region
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log_error "Bucket $BUCKET_NAME does not exist or you don't have access"
    exit 1
fi

# Get bucket region
REGION=$(aws s3api get-bucket-location --bucket "$BUCKET_NAME" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
# AWS returns "None" for us-east-1
if [ "$REGION" = "None" ] || [ "$REGION" = "null" ] || [ -z "$REGION" ]; then
    REGION="us-east-1"
fi

# Use environment variable if set, otherwise use detected region
REGION=${AWS_REGION:-$REGION}

log_info "Bucket region: $REGION"

log_success "Bucket found and accessible"

# Get bucket versioning status
VERSIONING_STATUS=$(aws s3api get-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --query 'Status' \
    --output text 2>/dev/null || echo "Disabled")

log_info "Versioning status: $VERSIONING_STATUS"

# Function to get object details
get_object_details() {
    local bucket=$1
    local key=$2
    local version_id=$3
    
    local temp_file="/tmp/object_details_$$.json"
    
    # Get object metadata using head-object
    if [ -n "$version_id" ] && [ "$version_id" != "null" ]; then
        aws s3api head-object \
            --bucket "$bucket" \
            --key "$key" \
            --version-id "$version_id" \
            --region "$REGION" \
            --output json 2>/dev/null > "$temp_file" || echo "{}" > "$temp_file"
    else
        aws s3api head-object \
            --bucket "$bucket" \
            --key "$key" \
            --region "$REGION" \
            --output json 2>/dev/null > "$temp_file" || echo "{}" > "$temp_file"
    fi
    
    # Get tags
    local tags_json
    if [ -n "$version_id" ] && [ "$version_id" != "null" ]; then
        tags_json=$(aws s3api get-object-tagging \
            --bucket "$bucket" \
            --key "$key" \
            --version-id "$version_id" \
            --region "$REGION" \
            --query 'TagSet' \
            --output json 2>/dev/null || echo "[]")
    else
        tags_json=$(aws s3api get-object-tagging \
            --bucket "$bucket" \
            --key "$key" \
            --region "$REGION" \
            --query 'TagSet' \
            --output json 2>/dev/null || echo "[]")
    fi
    
    # Get ACL (subresource)
    local acl_json
    if [ -n "$version_id" ] && [ "$version_id" != "null" ]; then
        acl_json=$(aws s3api get-object-acl \
            --bucket "$bucket" \
            --key "$key" \
            --version-id "$version_id" \
            --region "$REGION" \
            --output json 2>/dev/null || echo "{}")
    else
        acl_json=$(aws s3api get-object-acl \
            --bucket "$bucket" \
            --key "$key" \
            --region "$REGION" \
            --output json 2>/dev/null || echo "{}")
    fi
    
    # Generate presigned URL (valid for 1 hour)
    local presigned_url
    presigned_url=$(aws s3 presign "s3://${bucket}/${key}" \
        --region "$REGION" \
        --expires-in 3600 2>/dev/null || echo "N/A")
    
    # Extract details from head-object
    local size=$(jq -r '.ContentLength // 0' "$temp_file")
    local last_modified=$(jq -r '.LastModified // "N/A"' "$temp_file")
    local etag=$(jq -r '.ETag // "N/A"' "$temp_file")
    local storage_class=$(jq -r '.StorageClass // "STANDARD"' "$temp_file")
    local content_type=$(jq -r '.ContentType // "N/A"' "$temp_file")
    local server_side_encryption=$(jq -r '.ServerSideEncryption // "None"' "$temp_file")
    local metadata=$(jq -c '.Metadata // {}' "$temp_file")
    local restore_status=$(jq -r '.Restore // "N/A"' "$temp_file")
    local replication_status=$(jq -r '.ReplicationStatus // "N/A"' "$temp_file")
    local object_lock_mode=$(jq -r '.ObjectLockMode // "N/A"' "$temp_file")
    local object_lock_retain_until=$(jq -r '.ObjectLockRetainUntilDate // "N/A"' "$temp_file")
    local legal_hold=$(jq -r '.ObjectLockLegalHoldStatus // "N/A"' "$temp_file")
    
    # Determine if object is archived
    local archive_status="Not Archived"
    if [[ "$storage_class" == "GLACIER"* ]] || [[ "$storage_class" == "DEEP_ARCHIVE" ]]; then
        archive_status="Archived"
        if [[ "$restore_status" != "N/A" ]]; then
            archive_status="Restoring/Restored"
        fi
    fi
    
    # Create JSON output
    cat << EOF
{
  "ObjectName": "$key",
  "Size": $size,
  "SizeHuman": "$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")",
  "LastModified": "$last_modified",
  "ETag": "$etag",
  "StorageClass": "$storage_class",
  "ContentType": "$content_type",
  "VersionId": "${version_id:-null}",
  "IsLatestVersion": ${is_latest:-true},
  "Encryption": "$server_side_encryption",
  "Metadata": $metadata,
  "Tags": $tags_json,
  "ACL": $acl_json,
  "PresignedURL": "$presigned_url",
  "ReplicationStatus": "$replication_status",
  "RestoreStatus": "$restore_status",
  "ArchiveStatus": "$archive_status",
  "ObjectLockMode": "$object_lock_mode",
  "ObjectLockRetainUntil": "$object_lock_retain_until",
  "LegalHold": "$legal_hold"
}
EOF
    
    rm -f "$temp_file"
}

# Function to create CSV header
create_csv_header() {
    echo "ObjectName,Size(Bytes),Size(Human),LastModified,StorageClass,ContentType,VersionId,IsLatest,Encryption,Metadata,Tags,ArchiveStatus,ReplicationStatus,PresignedURL"
}

# Function to convert JSON to CSV row
json_to_csv() {
    local json=$1
    
    local object_name=$(echo "$json" | jq -r '.ObjectName')
    local size=$(echo "$json" | jq -r '.Size')
    local size_human=$(echo "$json" | jq -r '.SizeHuman')
    local last_modified=$(echo "$json" | jq -r '.LastModified')
    local storage_class=$(echo "$json" | jq -r '.StorageClass')
    local content_type=$(echo "$json" | jq -r '.ContentType')
    local version_id=$(echo "$json" | jq -r '.VersionId')
    local is_latest=$(echo "$json" | jq -r '.IsLatestVersion')
    local encryption=$(echo "$json" | jq -r '.Encryption')
    local metadata=$(echo "$json" | jq -r '.Metadata | to_entries | map("\(.key)=\(.value)") | join("; ")')
    local tags=$(echo "$json" | jq -r '.Tags | map("\(.Key)=\(.Value)") | join("; ")')
    local archive=$(echo "$json" | jq -r '.ArchiveStatus')
    local replication=$(echo "$json" | jq -r '.ReplicationStatus')
    local presigned_url=$(echo "$json" | jq -r '.PresignedURL')
    
    echo "\"$object_name\",$size,\"$size_human\",\"$last_modified\",\"$storage_class\",\"$content_type\",\"$version_id\",$is_latest,\"$encryption\",\"$metadata\",\"$tags\",\"$archive\",\"$replication\",\"$presigned_url\""
}

# Main processing
log_info "Retrieving object list..."

if [ "$VERSIONING_STATUS" = "Enabled" ]; then
    log_info "Versioning is enabled - retrieving all versions"
    
    # Get all versions
    OBJECTS=$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output json)

    # Process versions
    VERSION_COUNT=$(echo "$OBJECTS" | jq '.Versions | length')
    DELETE_MARKER_COUNT=$(echo "$OBJECTS" | jq '.DeleteMarkers | length // 0')
    
    log_info "Found $VERSION_COUNT object versions and $DELETE_MARKER_COUNT delete markers"
    
else
    log_info "Versioning is disabled - retrieving current objects only"
    
    # Get current objects only
    OBJECTS=$(aws s3api list-objects-v2 \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output json)
    
    OBJECT_COUNT=$(echo "$OBJECTS" | jq '.Contents | length')
    log_info "Found $OBJECT_COUNT objects"
fi

# Initialize output
if [ "$OUTPUT_FORMAT" = "csv" ]; then
    create_csv_header
elif [ "$OUTPUT_FORMAT" = "json" ]; then
    echo "["
fi

# Process objects
log_info "Processing objects and gathering detailed information..."

FIRST_OBJECT=true

if [ "$VERSIONING_STATUS" = "Enabled" ]; then
    # Process all versions
    TOTAL_VERSIONS=$(echo "$OBJECTS" | jq '.Versions | length')
    CURRENT=0
    
    echo "$OBJECTS" | jq -c '.Versions[]' | while read -r obj; do
        CURRENT=$((CURRENT + 1))
        
        KEY=$(echo "$obj" | jq -r '.Key')
        VERSION_ID=$(echo "$obj" | jq -r '.VersionId')
        IS_LATEST=$(echo "$obj" | jq -r '.IsLatest')
        
        log_info "Processing [$CURRENT/$TOTAL_VERSIONS]: $KEY (version: ${VERSION_ID:0:8}...)"
        
        # Set is_latest for the function
        is_latest=$IS_LATEST
        
        DETAILS=$(get_object_details "$BUCKET_NAME" "$KEY" "$VERSION_ID")
        
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            if [ "$FIRST_OBJECT" = true ]; then
                FIRST_OBJECT=false
            else
                echo ","
            fi
            echo "$DETAILS"
        elif [ "$OUTPUT_FORMAT" = "csv" ]; then
            json_to_csv "$DETAILS"
        elif [ "$OUTPUT_FORMAT" = "table" ]; then
            echo "$DETAILS" | jq -r '[.ObjectName, .SizeHuman, .StorageClass, .VersionId, .IsLatestVersion] | @tsv'
        fi
    done
    
else
    # Process current objects only
    TOTAL_OBJECTS=$(echo "$OBJECTS" | jq '.Contents | length')
    CURRENT=0
    
    echo "$OBJECTS" | jq -c '.Contents[]' | while read -r obj; do
        CURRENT=$((CURRENT + 1))
        
        KEY=$(echo "$obj" | jq -r '.Key')
        
        log_info "Processing [$CURRENT/$TOTAL_OBJECTS]: $KEY"
        
        is_latest=true
        DETAILS=$(get_object_details "$BUCKET_NAME" "$KEY" "")
        
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            if [ "$FIRST_OBJECT" = true ]; then
                FIRST_OBJECT=false
            else
                echo ","
            fi
            echo "$DETAILS"
        elif [ "$OUTPUT_FORMAT" = "csv" ]; then
            json_to_csv "$DETAILS"
        elif [ "$OUTPUT_FORMAT" = "table" ]; then
            echo "$DETAILS" | jq -r '[.ObjectName, .SizeHuman, .StorageClass, .Tags | length, .ArchiveStatus] | @tsv'
        fi
    done
fi

if [ "$OUTPUT_FORMAT" = "json" ]; then
    echo "]"
fi

log_success "Processing complete!"

if [ "$OUTPUT_FORMAT" != "table" ]; then
    log_info "Results displayed above (redirect to file to save)"
fi

################################################################################
# Summary statistics
################################################################################

log_info "Generating summary statistics..."

# Get bucket-level information
BUCKET_SIZE=$(aws s3 ls "s3://${BUCKET_NAME}" --recursive --region "$REGION" --summarize 2>/dev/null | grep "Total Size" | awk '{print $3}')
BUCKET_OBJECT_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}" --recursive --region "$REGION" --summarize 2>/dev/null | grep "Total Objects" | awk '{print $3}')

cat >&2 << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Bucket:           $BUCKET_NAME
Region:           $REGION
Total Objects:    ${BUCKET_OBJECT_COUNT:-N/A}
Total Size:       $(numfmt --to=iec-i --suffix=B ${BUCKET_SIZE:-0} 2>/dev/null || echo "${BUCKET_SIZE:-0}B")
Versioning:       $VERSIONING_STATUS
Output Format:    $OUTPUT_FORMAT

TIP: Save output to file:
  $0 $BUCKET_NAME csv > migration-inventory.csv
  $0 $BUCKET_NAME json > migration-inventory.json
  
  Open CSV in Excel or Google Sheets for analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
