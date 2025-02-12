#!/bin/bash

# Ensure script fails on any error
set -e

# Fix potential Windows line endings in .env
if command -v dos2unix >/dev/null 2>&1; then
    dos2unix ./.env >/dev/null 2>&1 || true
fi

# Load environment variables
set -a
source ./.env
set +a

# Validate required environment variables
if [ -z "$MONGODB_URI" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$S3_BUCKET_NAME" ]; then
    echo "Error: Missing required environment variables"
    exit 1
fi

# Function to test MongoDB connection with retries
test_mongodb_connection() {
    local max_attempts=5
    local attempt=1
    local wait_time=10

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: Testing MongoDB connection..."
        if mongosh --eval "db.runCommand({ping: 1})" "${MONGODB_URI}" >/dev/null 2>&1; then
            echo "MongoDB connection successful!"
            return 0
        fi
        echo "Connection failed. Waiting ${wait_time} seconds before retry..."
        sleep $wait_time
        attempt=$((attempt + 1))
        wait_time=$((wait_time * 2))
    done

    echo "Error: Could not connect to MongoDB after $max_attempts attempts"
    return 1
}

# Test MongoDB connection
if ! test_mongodb_connection; then
    exit 1
fi

# Test AWS credentials
echo "Testing AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: Invalid AWS credentials"
    exit 1
fi

# Get the latest backup file
echo "Searching for latest backup..."
LATEST_BACKUP=$(aws s3api list-objects \
    --bucket "${S3_BUCKET_NAME}" \
    --prefix "${BACKUP_PREFIX}/" \
    --output json \
    | jq -r '.Contents | sort_by(.LastModified) | last | .Key')

if [ -z "${LATEST_BACKUP}" ]; then
    echo "Error: No backup found in S3 bucket"
    exit 1
fi

echo "Found latest backup: ${LATEST_BACKUP}"

# Create temporary directory for backup
TEMP_DIR=$(mktemp -d)
BACKUP_PATH="${TEMP_DIR}/backup.gz"

# Download the backup
echo "Downloading backup from S3..."
if ! aws s3 cp "s3://${S3_BUCKET_NAME}/${LATEST_BACKUP}" "${BACKUP_PATH}"; then
    echo "Error: Failed to download backup from S3"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

echo "Backup downloaded successfully"

# Verify backup file
if [ ! -s "${BACKUP_PATH}" ]; then
    echo "Error: Downloaded backup file is empty"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Restore the backup
echo "Starting database restore..."
if ! mongorestore --uri="${MONGODB_URI}" --gzip --archive="${BACKUP_PATH}" --drop; then
    echo "Error: Database restore failed"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

echo "Database restored successfully"

# Clean up
rm -rf "${TEMP_DIR}"
echo "Restore process completed successfully"
