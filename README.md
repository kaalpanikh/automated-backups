# Automated MongoDB Backups

Automated backup system for MongoDB databases with AWS S3 storage, implementing the [roadmap.sh Automated DB Backups project](https://roadmap.sh/projects/automated-backups).

## Project Overview

This project implements an automated backup system for MongoDB databases that:
- Creates compressed backups every 12 hours using `mongodump`
- Stores backups in AWS S3 (instead of Cloudflare R2)
- Maintains a 7-day backup retention policy
- Provides easy restore functionality
- Includes comprehensive logging and error handling

### Key Features

- **Automated Backups**: Runs every 12 hours via cron job
- **Compression**: Uses gzip to minimize storage space
- **Cloud Storage**: AWS S3 integration with configurable bucket and prefix
- **Retention Policy**: Automatically removes backups older than 7 days
- **Restore Capability**: Simple script to restore from the latest backup
- **Error Handling**: Comprehensive checks and error reporting
- **Logging**: Detailed logs for monitoring and troubleshooting

### Implementation Differences

While the roadmap.sh project suggests using Cloudflare R2, we chose AWS S3 because:
1. Better integration with existing AWS infrastructure
2. More mature tooling and documentation
3. Wider industry adoption
4. Compatible with other S3-like services (including R2) if needed

## Project Structure

```
automated-backups/
├── scripts/
│   ├── backup.sh        # Creates and uploads backups
│   └── restore.sh       # Downloads and restores backups
├── .env.example         # Template for environment variables
└── README.md           # Documentation
```

## Implementation Details

### 1. Backup Script
- Uses `mongodump` with gzip compression
- Uploads to S3 using AWS CLI
- Implements backup rotation
- Includes error handling and logging

### 2. Restore Script
- Downloads latest backup from S3
- Restores using `mongorestore`
- Validates backup integrity
- Handles errors gracefully

### 3. Cron Job
- Runs every 12 hours
- Logs output to `/var/log/mongodb-backup.log`
- Uses absolute paths for reliability

## Proof of Implementation

### 1. Successful Backup
```bash
$ ssh ubuntu@44.203.38.191 'cd /opt/mongodb-backup && ./backup.sh'
Starting MongoDB backup at Wed Feb 12 14:17:37 UTC 2025
Backup file: mongodb-backup_20250212_141737.gz
Creating backup...
done dumping todos.todos (1 document)
Uploading to S3...
upload: ./mongodb-backup_20250212_141737.gz to s3://roadmapsh-bucket/mongodb-backup/mongodb-backup_20250212_141737.gz
Cleaning up local backup...
Cleaning up old backups...
Backup completed successfully at Wed Feb 12 14:17:39 UTC 2025
```

### 2. List Backups in S3
```bash
$ ssh ubuntu@44.203.38.191 'aws s3 ls s3://roadmapsh-bucket/mongodb-backup/'
2025-02-12 14:15:19        469 mongodb-backup_20250212_141517.gz
2025-02-12 14:17:39        469 mongodb-backup_20250212_141737.gz
```

### 3. Successful Restore
```bash
$ ssh ubuntu@44.203.38.191 'cd /opt/mongodb-backup && ./restore.sh'
Finding latest backup...
Latest backup: mongodb-backup_20250212_141737.gz
Downloading backup from S3...
Backup downloaded successfully
Restoring database...
done restoring todos.todos (1 document)
Database restored successfully
Restore process completed successfully
```

### 4. Verify Database Content
```bash
$ ssh ubuntu@44.203.38.191 'docker exec multi-container-service-mongodb-1 mongosh --eval "db.getSiblingDB('\''todos'\'').todos.find()"'
[
  {
    _id: ObjectId('67aade6bacff6a08472ed100'),
    title: 'Test Todo',
    description: 'Testing our deployment',
    completed: false,
    createdAt: ISODate('2025-02-11T05:21:47.910Z'),
    updatedAt: ISODate('2025-02-11T05:21:47.910Z'),
    __v: 0
  }
]
```

## Setup Instructions

### Prerequisites
- Linux server with cron support
- MongoDB database
- AWS account with S3 access
- Python 3 and pip (for AWS CLI)

### Configuration
1. Clone this repository to `/opt/mongodb-backup`
2. Copy `.env.example` to `.env` and configure:
   ```env
   MONGODB_URI=mongodb://172.18.0.2:27017/todos
   AWS_ACCESS_KEY_ID=your_aws_access_key
   AWS_SECRET_ACCESS_KEY=your_aws_secret_key
   AWS_DEFAULT_REGION=us-east-1
   S3_BUCKET_NAME=your_bucket_name
   BACKUP_RETENTION_DAYS=7
   BACKUP_PREFIX=mongodb-backup
   ```
3. Install dependencies:
   ```bash
   sudo apt-get update
   sudo apt-get install -y mongodb-database-tools python3-pip
   sudo pip3 install --break-system-packages awscli
   ```
4. Set up cron job:
   ```bash
   (crontab -l 2>/dev/null; echo "0 */12 * * * cd /opt/mongodb-backup && ./backup.sh >> /var/log/mongodb-backup.log 2>&1") | crontab -
   ```

## Usage

### Manual Backup
```bash
cd /opt/mongodb-backup && ./backup.sh
```

### Manual Restore
```bash
cd /opt/mongodb-backup && ./restore.sh
```

### Monitor Backups
```bash
# View backup logs
tail -f /var/log/mongodb-backup.log

# List backups in S3
aws s3 ls s3://your-bucket-name/mongodb-backup/
```

## Future Improvements

1. **Multi-Database Support**: Add ability to backup multiple databases
2. **Compression Options**: Allow configurable compression levels
3. **Notification System**: Add email/Slack notifications for backup status
4. **Backup Verification**: Add integrity checks for backups
5. **Web Interface**: Create a simple dashboard for backup management

## Contributing

Feel free to open issues or submit pull requests. All contributions are welcome!

## License

MIT

## Project Status

✅ Active and Maintained