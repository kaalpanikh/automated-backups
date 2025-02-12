# Automated MongoDB Backups

This project implements an automated backup system for MongoDB databases. It's specifically configured to work with the [multi-container-service](https://github.com/kaalpanikh/multi-container-service) project, but can be adapted for any MongoDB database.

## How It Works

### 1. Backup Process
Every 12 hours, the system:
1. Connects to your MongoDB database
2. Creates a compressed backup using `mongodump`
3. Uploads the backup to cloud storage (AWS S3 or Cloudflare R2)
4. Deletes backups older than 7 days
5. Cleans up temporary files

### 2. Restore Process
When you need to restore a backup:
1. The system finds the latest backup in cloud storage
2. Downloads it to a temporary location
3. Restores it to your MongoDB database
4. Cleans up temporary files

## Project Structure

```
automated-backups/
├── scripts/
│   ├── backup.sh        # Creates and uploads backups
│   └── restore.sh       # Downloads and restores backups
├── .github/
│   └── workflows/
│       └── backup.yml   # Automated backup schedule
├── .env.example         # Template for environment variables
└── README.md           # This documentation
```

## Storage Provider Options

You can choose between two storage providers for your backups:

### AWS S3
Advantages:
- Extensive AWS ecosystem integration
- Multiple storage classes for cost optimization
- Advanced features (versioning, lifecycle rules)
- Global region selection

### Cloudflare R2
Advantages:
- Lower cost for most use cases
- Free egress bandwidth
- S3-compatible API
- Simpler configuration
- No region selection needed

## Environment Variables

Create a `.env` file with the following variables based on your chosen storage provider:

### For AWS S3:
```env
# MongoDB Connection
MONGODB_URI=mongodb://mongodb:27017/todos
NODE_ENV=development

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_DEFAULT_REGION=your_aws_region
S3_BUCKET_NAME=your_bucket_name

# Backup Settings
BACKUP_RETENTION_DAYS=7
BACKUP_PREFIX=mongodb-backup
```

### For Cloudflare R2:
```env
# MongoDB Connection
MONGODB_URI=mongodb://mongodb:27017/todos
NODE_ENV=development

# Cloudflare R2 Configuration
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_ENDPOINT=your_r2_endpoint
R2_BUCKET_NAME=your_bucket_name

# Backup Settings
BACKUP_RETENTION_DAYS=7
BACKUP_PREFIX=mongodb-backup
```

## Setup Instructions

### 1. Prerequisites
- A running MongoDB database (provided by multi-container-service)
- GitHub account (for automated backups)
- Account with either AWS or Cloudflare

### 2. Storage Provider Setup

#### Option 1: AWS S3
1. Create an AWS account if you don't have one
2. Create a new S3 bucket:
   - Go to AWS Console → S3
   - Click "Create bucket"
   - Choose a unique bucket name
   - Select your preferred region
   - Configure other settings as needed
3. Create an IAM user for access:
   - Go to AWS Console → IAM
   - Create a new user
   - Attach policy for S3 access
   - Save the access key and secret key

#### Option 2: Cloudflare R2
1. Create a Cloudflare account if you don't have one
2. Enable R2:
   - Go to Cloudflare Dashboard
   - Click on "R2"
   - Follow setup instructions
3. Create a new bucket
4. Generate API tokens (Access Key ID and Secret Access Key)

### 3. Repository Setup
1. Clone this repository
2. Copy `.env.example` to `.env`
3. Fill in your environment variables based on your chosen provider

### 4. GitHub Secrets

#### For AWS S3:
Add these secrets to your repository:
1. `MONGODB_URI`
2. `AWS_ACCESS_KEY_ID`
3. `AWS_SECRET_ACCESS_KEY`
4. `AWS_DEFAULT_REGION`
5. `S3_BUCKET_NAME`

#### For Cloudflare R2:
Add these secrets to your repository:
1. `MONGODB_URI`
2. `R2_ACCESS_KEY_ID`
3. `R2_SECRET_ACCESS_KEY`
4. `R2_ENDPOINT`
5. `R2_BUCKET_NAME`

## Usage

### Automatic Backups
Once set up, backups happen automatically every 12 hours through GitHub Actions.

### Manual Backup
To create a backup manually:
```bash
./scripts/backup.sh
```

### Restore from Backup
To restore the latest backup:
```bash
./scripts/restore.sh
```

## Understanding the Backup Storage

### How Files are Stored
- Backups are stored with names like: `mongodb_backup_20250212_172320.gz`
- The name includes the date and time of backup
- Files are automatically compressed to save space

### Storage Costs

#### AWS S3
- Pay for storage used
- Pay for data transfer (especially egress)
- Different storage classes available
- Regional pricing varies

#### Cloudflare R2
- Free tier available
- No egress fees
- Simple pricing structure
- Often cheaper for smaller workloads

### Backup Retention
- By default, backups older than 7 days are deleted
- Configurable via `BACKUP_RETENTION_DAYS`
- At least one backup is always kept

## Troubleshooting

### Common Issues

1. MongoDB Connection Failed
   - Check if MongoDB is running
   - Verify `MONGODB_URI` is correct
   - Ensure network connectivity

2. Storage Upload Failed
   - Check credentials
   - Verify bucket exists
   - For S3: Check region settings
   - For R2: Verify endpoint URL

3. GitHub Actions Failed
   - Check repository secrets
   - Verify workflow file syntax
   - Check GitHub Actions logs

### Logs
- All actions are logged with timestamps
- Check GitHub Actions for workflow logs
- Local runs show logs in terminal

## Important Notes

### Docker Network Considerations
When running this backup system on a host that has MongoDB running in Docker:
1. Use the container's IP address in the `MONGODB_URI` instead of the service name
2. You can find the container's IP using: `docker inspect <container_name> | grep IPAddress`
3. Example URI: `mongodb://172.18.0.2:27017/dbname`

### Cross-Platform Development
If developing on Windows and deploying to Linux:
1. The scripts automatically handle Windows line endings (CRLF)
2. No manual intervention needed as the scripts include `dos2unix` conversion

### Error Handling
The scripts now include comprehensive error checking:
1. Environment variable validation
2. MongoDB connection testing
3. AWS credentials verification
4. Backup/restore operation validation

### Monitoring
1. All backup operations are logged to `/var/log/mongodb-backup.log`
2. View recent backup activity: `tail -f /var/log/mongodb-backup.log`
3. Check cron job status: `crontab -l`

## Security Notes

1. Credentials
   - Never commit `.env` file
   - Use GitHub secrets for sensitive data
   - Rotate credentials periodically
   - Use minimal IAM permissions (for AWS)

2. Backups
   - All backups are compressed
   - Transmitted securely via HTTPS
   - For AWS: Consider using bucket encryption
   - For R2: Encryption is automatic

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Open an issue in the repository

## License

MIT