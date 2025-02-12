#!/bin/bash

# Exit on error
set -e

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Check required environment variables
if [ -z "$MONGODB_URI" ] || [ -z "$S3_BUCKET_NAME" ] || [ -z "$BACKUP_PREFIX" ]; then
    echo "Error: Required environment variables are not set"
    echo "Please ensure MONGODB_URI, S3_BUCKET_NAME, and BACKUP_PREFIX are set"
    exit 1
fi

# Set default backup retention if not specified
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

# Create timestamp for backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${BACKUP_PREFIX}_${TIMESTAMP}.gz"
BACKUP_PATH="/backup/${BACKUP_NAME}"

echo "Starting MongoDB backup at $(date)"
echo "Backup file: ${BACKUP_NAME}"

# Create backup using mongodump
echo "Creating backup..."
mongodump --uri="${MONGODB_URI}" --gzip --archive="${BACKUP_PATH}"

# Upload to S3
echo "Uploading to S3..."
aws s3 cp "${BACKUP_PATH}" "s3://${S3_BUCKET_NAME}/${BACKUP_PREFIX}/${BACKUP_NAME}"

# Clean up local backup
echo "Cleaning up local backup..."
rm -f "${BACKUP_PATH}"

# Delete old backups from S3
echo "Cleaning up old backups..."
RETENTION_DATE=$(date -d "${BACKUP_RETENTION_DAYS} days ago" +%Y-%m-%d)
aws s3 ls "s3://${S3_BUCKET_NAME}/${BACKUP_PREFIX}/" | while read -r line; do
    BACKUP_DATE=$(echo "$line" | awk '{print $1}')
    BACKUP_FILE=$(echo "$line" | awk '{print $4}')
    if [[ "${BACKUP_DATE}" < "${RETENTION_DATE}" ]]; then
        echo "Deleting old backup: ${BACKUP_FILE}"
        aws s3 rm "s3://${S3_BUCKET_NAME}/${BACKUP_PREFIX}/${BACKUP_FILE}"
    fi
done

echo "Backup completed successfully at $(date)"
