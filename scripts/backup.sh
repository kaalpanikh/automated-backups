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

# Create timestamp for backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.gz"
BACKUP_PATH="/tmp/${BACKUP_FILE}"

echo "Starting MongoDB backup at ${TIMESTAMP}"

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

# Create backup using mongodump
echo "Creating MongoDB backup..."
if ! mongodump --uri="${MONGODB_URI}" --gzip --archive="${BACKUP_PATH}"; then
    echo "Error: MongoDB backup failed"
    rm -f "${BACKUP_PATH}"
    exit 1
fi

echo "MongoDB backup created successfully"

# Test AWS credentials
echo "Testing AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: Invalid AWS credentials"
    rm -f "${BACKUP_PATH}"
    exit 1
fi

# Upload to AWS S3
echo "Uploading backup to S3"
if ! aws s3 cp "${BACKUP_PATH}" "s3://${S3_BUCKET_NAME}/${BACKUP_PREFIX}/${BACKUP_FILE}"; then
    echo "Error: Failed to upload backup to S3"
    rm -f "${BACKUP_PATH}"
    exit 1
fi

echo "Backup uploaded successfully to S3"

# Clean up local backup file
rm -f "${BACKUP_PATH}"

# Delete old backups (older than BACKUP_RETENTION_DAYS)
echo "Cleaning up old backups"
aws s3api list-objects \
    --bucket "${S3_BUCKET_NAME}" \
    --prefix "${BACKUP_PREFIX}/" \
    --output json \
    | jq -r ".Contents[] | select(.LastModified < \"$(date -d "-${BACKUP_RETENTION_DAYS} days" -Iseconds)\") | .Key" \
    | while read -r key; do
        if [ ! -z "$key" ]; then
            aws s3 rm "s3://${S3_BUCKET_NAME}/${key}"
            echo "Deleted old backup: ${key}"
        fi
    done

echo "Backup process completed successfully"
