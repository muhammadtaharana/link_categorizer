# Advanced Link Categorizer v2.0

Ultra-fast URL categorization tool for security assessment, bug bounty hunting, and penetration testing.

> [!NOTE]
> **Version 2.1** - NEW: Awk-based single-pass categorizer processes 310K URLs in 33 seconds. 18 vulnerability categories optimized for blackhat BBP reconnaissance.

## Features

✨ **Core Capabilities**
- 🚀 **Parallel Processing** - Process millions of URLs 4-8x faster with GNU Parallel
- 💾 **Caching System** - Skip re-processing unchanged files automatically
- 🌐 **HTTP Validation** - Verify URLs are live with status codes and response times
- 📊 **Multiple Formats** - TXT, JSON, CSV, HTML, SARIF reports
- 🗄️ **SQLite Database** - Store and query results over time
- 📈 **20+ Vulnerability Categories** - SQLi, XSS, XXE, Path Traversal, SSRF, Auth, IDOR, CSRF, SSTI, JWT, GraphQL, and more
- 🔔 **Webhooks** - Slack, Jira, custom notifications
- 📝 **Comprehensive Logging** - Verbose output and persistent logs
- 🔧 **Configuration File** - Customize patterns and behavior
- 🎯 **Domain Filtering** - Filter by inclusion/exclusion
- 📋 **Progress Tracking** - Monitor processing in real-time
- 🧪 **Dry-Run Mode** - Preview without writing files

## Installation

### Prerequisites
```bash
# Linux
sudo apt-get install parallel sqlite3 jq curl

# macOS
brew install parallel sqlite3 jq curl

# Windows: Use WSL or Git Bash
```

### Quick Setup
```bash
# Download and setup
chmod +x link_categorizer.sh setup.sh
./setup.sh

# Or manually
mkdir -p .cache logs extreme_categorized_urls
```

## Quick Start

### ⚡ FASTEST: Use fast_awk.sh (v2.1 - RECOMMENDED)
```bash
./fast_awk.sh urls.txt
# Processes 310K URLs in 33 seconds
# Output: extreme_categorized_urls/sqli.txt, xss.txt, etc.
```

### Benchmark Results (310K Dyson BBP URLs)
| Script | Time | Speed |
|--------|------|-------|
| **fast_awk.sh** | 33 sec | 9,400 URLs/sec |
| link_categorizer.sh | 45 sec | 6,900 URLs/sec |

### Legacy: Original Script
```bash
./link_categorizer.sh urls.txt
```

## Command Reference

| Option | Purpose |
|--------|---------|
| `-j, --jobs N` | Parallel jobs (default: 4) |
| `-v, --validate-http` | Check if URLs are live |
| `-p, --progress` | Show progress indicator |
| `-f, --format FORMAT` | Output format: txt, json, csv, html, sarif |
| `-d, --domain DOMAIN` | Filter by domain |
| `-e, --exclude DOMAIN` | Exclude domain |
| `--database` | Store in SQLite database |
| `--report` | Generate summary report |
| `--webhook URL` | Send Slack notification |
| `--dry-run` | Preview without writing |
| `--verbose` | Detailed output |
| `-h, --help` | Show help |

## Vulnerability Categories

| Category | Purpose | Example |
|----------|---------|---------|
| **sqli** | SQL Injection | `?id=1&select=*&from=users` |
| **xss** | Cross-Site Scripting | `?search=<script>&q=test` |
| **xxe** | XML External Entity | `/api/upload.xml?data=` |
| **path_traversal** | File Access | `?file=../../etc/passwd` |
| **ssrf** | Server-Side Request Forgery | `?url=http://internal-server` |
| **auth_oauth** | Auth Endpoints | `/login, /token, /authorize` |
| **access_control** | IDOR | `/api/user/123, /v1/profile/456` |
| **csrf** | Cross-Site Request Forgery | `/update, /delete, /transfer` |
| **cache_deception** | Cache Poisoning | `/my-account, /dashboard` |
| **ssti** | Template Injection | `?template=name&layout=` |
| **open_redirect** | Open Redirect | `?redirect=/evil.com&url=` |
| **jwt_leaks** | JWT Token Exposure | `ey...ey...ey` |
| **graphql_injection** | GraphQL Injection | `/graphql?query=mutation` |
| **api_key_exposure** | Credential Exposure | `api_key=, bearer=` |
| **cloud_storage** | Cloud Bucket Misconfig | `s3.amazonaws, blob.core` |
| **insecure_deserialization** | Serialization | `pickle=, serialize()` |

## Output Structure

```
extreme_categorized_urls/
├── sqli.txt                    # SQL injection targets
├── xss.txt                     # XSS reflection points
├── path_traversal.txt          # File access endpoints
├── ssrf.txt                    # SSRF parameters
├── (15+ more categories)
├── report.html                 # Interactive dashboard
├── summary.json                # Machine-readable results
├── results.csv                 # Spreadsheet format
└── results.sarif               # Security Analysis Results
```

## Real-World Examples

### Bug Bounty Workflow
```bash
# Gather URLs
waybackurls example.com > urls.txt
gau example.com >> urls.txt

# Categorize with validation
./link_categorizer.sh -v -f html --report urls.txt

# Review findings
open extreme_categorized_urls/report.html
```

### Pentest Assessment
```bash
./link_categorizer.sh \
  -j 8 -p \
  --validate-http \
  --database \
  -f json -f html \
  --report \
  scope.txt

# Query database for specific vulnerabilities
sqlite3 categorizer.db "SELECT url FROM results WHERE category='sqli';"
```

### Continuous Monitoring
```bash
# Daily scan with caching (only new URLs processed)
./link_categorizer.sh \
  --database \
  --report \
  urls_$(date +%Y%m%d).txt

# Track trends over time
sqlite3 categorizer.db "SELECT DATE(datetime(timestamp, 'unixepoch')) as date, COUNT(*) FROM results GROUP BY date;"
```

### Integration with Other Tools
```bash
# Feed to Nuclei for vulnerability scanning
nuclei -l extreme_categorized_urls/sqli.txt -t sqli/

# Feed to SQLMap for SQL injection testing
cat extreme_categorized_urls/sqli.txt | sqlmap -m - --batch

# Import JSON to custom tools
jq '.categories[] | select(.count > 50)' extreme_categorized_urls/summary.json
```

## Configuration

Edit `config.json` to customize behavior:

```json
{
  "performance": {
    "parallel_jobs": 4,
    "batch_size": 1000,
    "cache_enabled": true
  },
  "output": {
    "formats": ["txt", "json", "html"]
  },
  "http_validation": {
    "enabled": false,
    "timeout_seconds": 5
  },
  "database": {
    "enabled": false
  },
  "webhooks": {
    "slack_url": ""
  }
}
```

## Performance

### Benchmark Results
- Basic processing: **5,000 URLs/sec**
- Parallel (8 jobs): **20,000 URLs/sec**
- With HTTP validation: **50-100 URLs/sec**
- 1M URL file: **~60 seconds** (8 cores)

### Optimization Tips
```bash
# Use all CPU cores
./link_categorizer.sh -j $(nproc) urls.txt

# Low memory systems
./link_categorizer.sh -j 2 huge_urls.txt

# Process in parallel chunks
split -l 100000 urls.txt chunk_
parallel ./link_categorizer.sh {} ::: chunk_*
```

## Database Queries

```bash
# Count vulnerabilities by type
sqlite3 categorizer.db \
  "SELECT category, COUNT(*) FROM results GROUP BY category ORDER BY COUNT(*) DESC;"

# Find all IDOR-prone endpoints
sqlite3 categorizer.db \
  "SELECT url FROM results WHERE category='access_control' LIMIT 20;"

# Compare scans over time
sqlite3 categorizer.db \
  "SELECT scan_id, category, COUNT(*) FROM results GROUP BY scan_id, category;"
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "parallel: command not found" | `apt-get install parallel` |
| "sqlite3: command not found" | `apt-get install sqlite3` |
| Out of memory | Reduce `-j` or split input file |
| Slow processing | Increase `-j` or skip `-v` |
| Permission denied | `chmod +x link_categorizer.sh` |

## Documentation

- **[USAGE.md](USAGE.md)** - Comprehensive guide with advanced examples
- **[config.json](config.json)** - Configuration template with all options
- **[setup.sh](setup.sh)** - Automated environment setup

## What's New in v2.0

- ✨ Parallel processing (4-8x faster)
- 💾 Intelligent caching system
- 🌐 HTTP validation with status codes
- 📊 5 output formats (JSON, CSV, HTML, SARIF)
- 🗄️ SQLite database backend
- 🔔 Webhook notifications
- 📈 8 new vulnerability categories
- 🎯 Domain filtering
- 📋 Real-time progress tracking
- 🧪 Dry-run mode

## Use Cases

✅ **Security Testing** - Identify vulnerability patterns before testing  
✅ **Bug Bounty** - Triage targets by vulnerability type  
✅ **Penetration Testing** - Prioritize high-risk endpoints  
✅ **Risk Assessment** - Quantify vulnerability distribution  
✅ **Continuous Monitoring** - Track security posture over time  
✅ **Incident Response** - Analyze compromised applications  

## Caution

> Use Link Categorizer only on assets you own or have explicit written permission to test. This tool is for authorized security research and testing only. The authors are not responsible for misuse or illegal activity.

## License

MIT License - Free for security research

---

For detailed usage and advanced examples, see [USAGE.md](USAGE.md)
</br>

> [!TIP]
> **Optimization Tip:**
>
> - Ensure your input file contains full URLs (including schemes and parameters) for the best results.
> - Combine this with tools like `gau` or `waybackurls` to feed the engine a comprehensive dataset.
> - Check the `hits` count in the terminal to see which vulnerability classes are most prevalent in your target.

</br>
</br>

### TO-DO

* [ ] Add support for multi-threading to handle million+ URL lists.
* [ ] Integrate custom regex configuration via external YAML file.
* [ ] Add automated header checking for identified sensitive paths.

</br>
</br>

> [!CAUTION]
> **Use Link Categorizer only on assets you own or have explicit permission to test. This tool is designed for security researchers and bug bounty hunters to streamline reconnaissance. The authors are not responsible for any misuse or illegal activities.**[cite: 2]
```
