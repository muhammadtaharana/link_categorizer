# Advanced Link Categorizer - Complete Usage Guide

## Overview

The advanced Link Categorizer v2.0 is a powerful URL classification tool with:
- ✅ Parallel processing (4x-8x faster)
- ✅ HTTP validation & status checking
- ✅ Multiple output formats (TXT, JSON, CSV, HTML, SARIF)
- ✅ SQLite database backend
- ✅ Caching system to skip re-processing
- ✅ Webhook notifications (Slack, Jira)
- ✅ Comprehensive reporting
- ✅ Error handling & logging
- ✅ Dry-run mode for previews
- ✅ Extended vulnerability patterns (20+ categories)

---

## Installation

### Prerequisites
```bash
# Linux/macOS
sudo apt-get install parallel sqlite3 jq curl

# macOS (Homebrew)
brew install parallel sqlite3 jq curl

# Windows (WSL)
# Use Ubuntu subsystem or install Git Bash
```

### Setup
```bash
# Make script executable
chmod +x link_categorizer.sh

# Initialize cache and logs
mkdir -p .cache
touch categorizer.log
```

---

## Basic Usage

### Simple Categorization
```bash
./link_categorizer.sh urls.txt
```

Output:
```
[✓] Categorization Summary:
[+] sqli                 : 42 hits
[+] xss                  : 128 hits
[+] path_traversal       : 15 hits
[+] ssrf                 : 8 hits
```

---

## Advanced Options

### 1. **Parallel Processing**
```bash
# Use 8 parallel jobs instead of default 4
./link_categorizer.sh -j 8 urls.txt

# Automatic detection (uses CPU cores)
./link_categorizer.sh -j $(nproc) urls.txt
```

### 2. **HTTP Validation**
```bash
# Validate each URL is live (slower but more accurate)
./link_categorizer.sh --validate-http urls.txt

# With custom timeout
./link_categorizer.sh -v -t 10 urls.txt
```

### 3. **Multiple Output Formats**
```bash
# Generate all formats at once
./link_categorizer.sh -f json -f csv -f html -f sarif urls.txt

# Output results:
# - summary.json
# - results.csv
# - report.html
# - results.sarif
```

### 4. **Database Storage**
```bash
# Store in SQLite database
./link_categorizer.sh --database urls.txt

# Query results later:
sqlite3 categorizer.db "SELECT category, COUNT(*) FROM results GROUP BY category;"
```

### 5. **Domain Filtering**
```bash
# Only process URLs from example.com
./link_categorizer.sh -d example.com urls.txt

# Exclude third-party domains
./link_categorizer.sh -d example.com -e cdn.example.com urls.txt

# Multiple domains
./link_categorizer.sh -d domain1.com -d domain2.com urls.txt
```

### 6. **Progress Tracking**
```bash
# Show progress for large files
./link_categorizer.sh -p urls.txt

# Output: Processed: 100 / 5000
```

### 7. **Webhook Notifications**
```bash
# Send Slack notification when done
./link_categorizer.sh --webhook https://hooks.slack.com/services/YOUR/WEBHOOK/URL urls.txt

# Update config.json for persistent webhooks
```

### 8. **Report Generation**
```bash
# Generate comprehensive HTML report
./link_categorizer.sh --report urls.txt

# Output: extreme_categorized_urls/report.html
```

### 9. **Dry-Run Mode**
```bash
# Preview without writing files
./link_categorizer.sh --dry-run urls.txt

# Validates configuration and shows what would happen
```

### 10. **Verbose Logging**
```bash
# See detailed logs
./link_categorizer.sh --verbose urls.txt

# Check logs: cat categorizer.log
```

---

## Combined Examples

### Security Assessment
```bash
./link_categorizer.sh \
  --validate-http \
  --database \
  --report \
  -f json -f html \
  -p \
  -j 8 \
  urls.txt
```

### Bug Bounty Workflow
```bash
# Quick scan with progress
./link_categorizer.sh -p urls.txt

# Review top vulnerabilities
head -20 extreme_categorized_urls/sqli.txt
head -20 extreme_categorized_urls/xss.txt

# Validate and report for client
./link_categorizer.sh -v --report -f html urls.txt
```

### Continuous Monitoring
```bash
# Cache prevents re-processing same URLs
./link_categorizer.sh --database urls.txt

# Next run only processes new URLs
./link_categorizer.sh --database urls.txt
```

### Integration with Other Tools
```bash
# Feed SQLi URLs to sqlmap
while read url; do
  sqlmap -u "$url" --batch
done < extreme_categorized_urls/sqli.txt

# Feed XSS URLs to nuclei
nuclei -l extreme_categorized_urls/xss.txt -t xss

# Import JSON to tools
jq '.categories[]' extreme_categorized_urls/summary.json
```

---

## Configuration File

Edit `config.json` to customize:

### Performance Settings
```json
{
  "performance": {
    "parallel_jobs": 4,
    "batch_size": 1000,
    "cache_enabled": true,
    "progress_indicator": true
  }
}
```

### Output Formats
```json
{
  "output": {
    "formats": ["txt", "json", "html"],
    "include_statistics": true
  }
}
```

### HTTP Validation
```json
{
  "http_validation": {
    "enabled": true,
    "timeout_seconds": 5,
    "max_retries": 2
  }
}
```

### Database Settings
```json
{
  "database": {
    "enabled": true,
    "type": "sqlite",
    "path": "./categorizer.db"
  }
}
```

### Webhooks
```json
{
  "webhooks": {
    "slack_url": "https://hooks.slack.com/services/YOUR/WEBHOOK",
    "send_on_completion": true
  }
}
```

---

## Vulnerability Patterns

### Supported Categories

| Category | Pattern | Example |
|----------|---------|---------|
| **sqli** | ID/query params | `?id=1`, `&search=test` |
| **xss** | Reflection params | `?q=search`, `&name=user` |
| **xxe** | XML endpoints | `/api/`, `.xml`, `/soap` |
| **path_traversal** | File params | `?file=doc`, `&path=file` |
| **ssrf** | URL params | `?url=http://`, `&redirect=` |
| **auth_oauth** | Auth paths | `/login`, `/token`, `/auth` |
| **access_control** | ID paths | `/api/user/123`, `/v1/profile/456` |
| **csrf** | State-changing | `/update`, `/delete`, `/change` |
| **cache_deception** | Sensitive paths | `/my-account`, `/dashboard` |
| **ssti** | Template params | `?template=`, `&layout=` |
| **open_redirect** | Redirect params | `?next=`, `&url=`, `&to=` |
| **jwt_leaks** | JWT tokens | `ey...ey...ey` |
| **graphql_injection** | GraphQL endpoints | `/graphql`, `?query=` |
| **api_key_exposure** | API credentials | `api_key=`, `bearer=` |
| **cloud_storage** | Cloud buckets | `s3.amazonaws`, `blob.core` |
| **insecure_deserialization** | Serialization | `serialize()`, `pickle` |

---

## Performance Tips

### Speed Optimization
```bash
# Use maximum parallelism
./link_categorizer.sh -j $(nproc) urls.txt

# Skip HTTP validation for speed
./link_categorizer.sh urls.txt  # Default (fastest)

# Use SSD for better I/O
export OUTPUT_DIR=/mnt/ssd/results
./link_categorizer.sh urls.txt
```

### Memory Optimization
```bash
# Reduce batch size for low-memory systems
# Edit config.json: "batch_size": 100

# Use database instead of files
./link_categorizer.sh --database urls.txt
```

---

## Troubleshooting

### Common Issues

**"GNU Parallel not found"**
```bash
# Install parallel
sudo apt-get install parallel

# Or fall back to sequential processing (slower)
./link_categorizer.sh urls.txt
```

**"SQLite3 not found"**
```bash
# Install sqlite3
sudo apt-get install sqlite3

# Database feature auto-disables without it
```

**"jq not found"**
```bash
# Install jq
sudo apt-get install jq

# JSON/advanced parsing auto-disables without it
```

**Out of memory**
```bash
# Reduce parallel jobs
./link_categorizer.sh -j 2 huge_urls.txt

# Process in chunks
split -l 10000 urls.txt chunk_
for f in chunk_*; do ./link_categorizer.sh "$f"; done
```

---

## Examples by Use Case

### Bug Bounty
```bash
./link_categorizer.sh \
  --validate-http \
  -f html \
  --report \
  -p \
  targets.txt
```

### Penetration Testing
```bash
./link_categorizer.sh \
  --database \
  -j 8 \
  -p \
  --report \
  -f json \
  scope.txt

# Query database
sqlite3 categorizer.db \
  "SELECT url FROM results WHERE category='sqli' ORDER BY url;"
```

### Security Audit
```bash
./link_categorizer.sh \
  --validate-http \
  --database \
  --webhook $(echo $SLACK_WEBHOOK) \
  --report \
  -f html -f json \
  audit_urls.txt
```

### Continuous Scanning
```bash
#!/bin/bash
# daily_scan.sh
DAILY_URLS="urls_$(date +%Y%m%d).txt"
./link_categorizer.sh \
  --database \
  --report \
  "$DAILY_URLS"
```

---

## Output Examples

### HTML Report
Generated as: `extreme_categorized_urls/report.html`
- Interactive dashboard
- Category statistics
- Percentage breakdown
- Category breakdown table

### JSON Report
Generated as: `extreme_categorized_urls/summary.json`
```json
{
  "scan_id": "1704067200_123456789",
  "timestamp": 1704067200,
  "categories": [
    {"category": "sqli", "count": 42},
    {"category": "xss", "count": 128}
  ],
  "total_urls": 170
}
```

### CSV Report
Generated as: `extreme_categorized_urls/results.csv`
```
category,url,count
sqli,file,42
xss,file,128
```

### SARIF Report
Generated as: `extreme_categorized_urls/results.sarif`
- Security Analysis Results Format
- Integration with GitHub Security
- IDE/tool compatibility

---

## Help & Support

```bash
# View help
./link_categorizer.sh -h

# Enable verbose logging
./link_categorizer.sh --verbose urls.txt

# Check logs
tail -f categorizer.log

# View database schema
sqlite3 categorizer.db ".schema"
```

---

## Advanced Features (Coming Soon)

- [ ] Automatic false-positive filtering
- [ ] Machine learning categorization
- [ ] Custom plugin system
- [ ] Web UI dashboard
- [ ] Real-time streaming
- [ ] API server mode
- [ ] Integration with Burp Suite
- [ ] Auto-exploitation templates
