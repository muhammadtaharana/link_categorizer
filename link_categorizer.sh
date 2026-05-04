#!/bin/bash

set -euo pipefail

# ============================================================================
# Advanced Link Categorizer with Parallel Processing, Caching & Reporting
# ============================================================================

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
CACHE_DIR="${SCRIPT_DIR}/.cache"
OUTPUT_DIR="${SCRIPT_DIR}/extreme_categorized_urls"
DB_FILE="${SCRIPT_DIR}/categorizer.db"
LOG_FILE="${SCRIPT_DIR}/categorizer.log"
TIMESTAMP=$(date +%s)
SCAN_ID=$(date +%s_%N)

# Default settings
DRY_RUN=false
VERBOSE=false
VALIDATE_HTTP=false
PARALLEL_JOBS=4
BATCH_SIZE=1000
PROGRESS=false
OUTPUT_FORMATS=()
WEBHOOK_URL=""
DATABASE_ENABLED=false
REPORT_ENABLED=false
INPUT_FILE=""
FILTER_DOMAINS=()
EXCLUDE_DOMAINS=()

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[$level]${NC} $message" >&2
    fi
}

error() {
    local message="$@"
    echo -e "${RED}[ERROR]${NC} $message" >&2
    echo "[ERROR] $message" >> "$LOG_FILE"
    exit 1
}

success() {
    local message="$@"
    echo -e "${GREEN}[✓]${NC} $message"
    log "INFO" "$message"
}

warning() {
    local message="$@"
    echo -e "${YELLOW}[!]${NC} $message" >&2
    log "WARN" "$message"
}

print_help() {
    cat << 'EOF'
Usage: ./link_categorizer.sh [options] <url_file>

Options:
  -c, --config FILE          Use custom config file
  -o, --output DIR           Output directory (default: extreme_categorized_urls)
  -f, --format FORMAT        Output format: txt, json, csv, html, sarif (multiple: -f json -f html)
  -j, --jobs N               Parallel jobs (default: 4)
  -v, --validate-http        Validate URLs with HTTP requests
  -p, --progress             Show progress indicator
  -d, --domain DOMAIN        Filter by domain (can be used multiple times)
  -e, --exclude DOMAIN       Exclude domain (can be used multiple times)
  -t, --timeout SECONDS      HTTP timeout (default: 5)
  --dry-run                  Preview without writing files
  --database                 Store results in SQLite database
  --webhook URL              Send webhook notification on completion
  --report                   Generate summary report
  --verbose                  Verbose output
  -h, --help                 Show this help message

Examples:
  # Basic categorization
  ./link_categorizer.sh urls.txt

  # With HTTP validation and multiple formats
  ./link_categorizer.sh -v -f json -f html urls.txt

  # Parallel processing with progress
  ./link_categorizer.sh -j 8 -p urls.txt

  # With domain filtering and database
  ./link_categorizer.sh --database -d example.com urls.txt

EOF
}

# ============================================================================
# Configuration Management
# ============================================================================

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        warning "Config file not found at $CONFIG_FILE, using defaults"
        return 0
    fi

    log "INFO" "Loading configuration from $CONFIG_FILE"
    
    if command -v jq &> /dev/null; then
        PARALLEL_JOBS=$(jq -r '.performance.parallel_jobs // 4' "$CONFIG_FILE" 2>/dev/null || echo 4)
        BATCH_SIZE=$(jq -r '.performance.batch_size // 1000' "$CONFIG_FILE" 2>/dev/null || echo 1000)
        WEBHOOK_URL=$(jq -r '.webhooks.slack_url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        OUTPUT_FORMATS=($(jq -r '.output.formats[]?' "$CONFIG_FILE" 2>/dev/null || echo "txt"))
    fi
}

# ============================================================================
# Database Functions
# ============================================================================

init_database() {
    if [ "$DATABASE_ENABLED" = false ]; then
        return 0
    fi

    if ! command -v sqlite3 &> /dev/null; then
        warning "SQLite3 not found, database disabled"
        DATABASE_ENABLED=false
        return 0
    fi

    log "INFO" "Initializing database: $DB_FILE"
    
    sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS scans (
    scan_id TEXT PRIMARY KEY,
    timestamp INTEGER,
    input_file TEXT,
    input_hash TEXT,
    total_urls INTEGER,
    status TEXT
);

CREATE TABLE IF NOT EXISTS results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id TEXT,
    url TEXT,
    category TEXT,
    http_status INTEGER,
    response_time REAL,
    timestamp INTEGER,
    FOREIGN KEY (scan_id) REFERENCES scans(scan_id)
);

CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    pattern TEXT,
    count INTEGER DEFAULT 0,
    created_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_scan_id ON results(scan_id);
CREATE INDEX IF NOT EXISTS idx_category ON results(category);
CREATE INDEX IF NOT EXISTS idx_url ON results(url);
SQL
    success "Database initialized"
}

store_result() {
    if [ "$DATABASE_ENABLED" = false ]; then
        return 0
    fi

    local url=$1
    local category=$2
    local http_status=${3:-0}
    local response_time=${4:-0}

    url="${url//\"/\\\"}"
    sqlite3 "$DB_FILE" "INSERT INTO results (scan_id, url, category, http_status, response_time, timestamp) VALUES ('$SCAN_ID', \"$url\", '$category', $http_status, $response_time, $TIMESTAMP);" 2>/dev/null || true
}

# ============================================================================
# Caching Functions
# ============================================================================

init_cache() {
    mkdir -p "$CACHE_DIR"
    log "INFO" "Cache directory: $CACHE_DIR"
}

get_file_hash() {
    if command -v md5sum &> /dev/null; then
        md5sum "$1" | awk '{print $1}'
    elif command -v md5 &> /dev/null; then
        md5 -q "$1"
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}

check_cache() {
    local input_file=$1
    local current_hash=$(get_file_hash "$input_file")
    local cache_file="${CACHE_DIR}/$(basename "$input_file").hash"

    if [ -f "$cache_file" ]; then
        local cached_hash=$(cat "$cache_file")
        if [ "$current_hash" = "$cached_hash" ]; then
            return 0  # Cache hit
        fi
    fi
    
    return 1  # Cache miss
}

update_cache() {
    local input_file=$1
    local current_hash=$(get_file_hash "$input_file")
    local cache_file="${CACHE_DIR}/$(basename "$input_file").hash"
    echo "$current_hash" > "$cache_file"
    log "INFO" "Cache updated for $input_file"
}

# ============================================================================
# HTTP Validation
# ============================================================================

validate_url_http() {
    local url=$1
    local timeout=${2:-5}

    if ! command -v curl &> /dev/null; then
        return 0
    fi

    local start_time=$(date +%s.%N)
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

    echo "$http_status|$response_time"
}

# ============================================================================
# URL Categorization
# ============================================================================

categorize_url() {
    local url=$1
    local pattern=$2
    
    if echo "$url" | grep -iE "$pattern" | grep -ivE "\.(jpg|jpeg|png|gif|woff|woff2|ttf|css|ico|svg)$" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

process_url() {
    local url=$1
    local patterns=$2
    
    [ -z "$url" ] && return 1
    
    if [ ${#FILTER_DOMAINS[@]} -gt 0 ]; then
        local found=false
        for domain in "${FILTER_DOMAINS[@]}"; do
            if echo "$url" | grep -i "$domain" > /dev/null 2>&1; then
                found=true
                break
            fi
        done
        [ "$found" = true ] || return 1
    fi
    
    if [ ${#EXCLUDE_DOMAINS[@]} -gt 0 ]; then
        for domain in "${EXCLUDE_DOMAINS[@]}"; do
            if echo "$url" | grep -i "$domain" > /dev/null 2>&1; then
                return 1
            fi
        done
    fi
    
    while IFS='|' read -r category pattern; do
        [ -z "$category" ] && continue
        
        if echo "$url" | grep -iE "$pattern" | grep -ivE "\.(jpg|jpeg|png|gif|woff|woff2|ttf|css|ico|svg)$" > /dev/null 2>&1; then
            local http_info="0|0"
            if [ "$VALIDATE_HTTP" = true ]; then
                http_info=$(validate_url_http "$url" 5)
            fi
            local status=$(echo "$http_info" | cut -d'|' -f1)
            local rtime=$(echo "$http_info" | cut -d'|' -f2)
            echo "$category|$url|$status|$rtime"
            store_result "$url" "$category" "${status:-0}" "${rtime:-0}"
            return 0
        fi
    done <<< "$patterns"
    
    return 1
}

# ============================================================================
# Pattern Management
# ============================================================================

load_patterns() {
    # Default patterns
    cat << 'EOF'
sqli|(\?|&)(id|query|search|select|from|where|order|limit|sort|cat|p|page)=
xss|(\?|&)(q|s|search|id|lang|name|msg|text|redirect|url|callback|email|user)=
xxe|(\.(xml|svg|xhtml|xsd)$)|(/api/)|(/soap)|(/rpc)|(\?|&)(data|xml|file|doc)=
path_traversal|(\?|&)(file|path|page|doc|root|dir|folder|view|load|read|include|img|image)=
ssrf|(\?|&)(url|uri|link|dest|redirect|path|domain|host|proxy|site|to)=
auth_oauth|/(login|signup|register|logout|auth|callback|token|authorize|password|mfa|signin|session)
access_control|/(api|v1|v2|user|settings|profile|edit|update|delete|v3)/[0-9a-zA-Z-]+
csrf|/(update|delete|add|remove|change|settings|transfer|email|profile|password)
cache_deception|/(my-account|profile|settings|dashboard|home|inbox)$
ssti|(\?|&)(template|name|id|email|preview|layout|render)=
open_redirect|(\?|&)(next|url|redirect|return|r|goto|link|dest|to)=
jwt_leaks|ey[a-zA-Z0-9_-]+\.ey[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+
graphql_injection|/graphql|/graph|(\?|&)(query|mutation)=
api_key_exposure|api[_-]?key|apikey|api_secret|secret_key|bearer|token
cloud_storage|s3\.amazonaws|storage\.googleapis|blob\.core\.windows|cloudfront
insecure_deserialization|serialize|unserialize|pickle|marshal
EOF
}

# ============================================================================
# Output Formatting
# ============================================================================

output_txt() {
    local category=$1
    local outfile="$OUTPUT_DIR/${category}.txt"
    local count=$2

    echo "[+] $(printf '%-20s' "$category") : $count hits"
    log "INFO" "Generated: $outfile ($count hits)"
}

output_json() {
    if [ "$DRY_RUN" = true ]; then
        warning "DRY-RUN: Would generate JSON reports"
        return 0
    fi

    local summary_file="$OUTPUT_DIR/summary.json"
    local input_file="${INPUT_FILE}"
    
    {
        echo "{"
        echo "  \"scan_id\": \"$SCAN_ID\","
        echo "  \"timestamp\": $TIMESTAMP,"
        echo "  \"input_file\": \"$input_file\","
        echo "  \"categories\": ["
        
        local first=true
        for file in "$OUTPUT_DIR"/*.txt; do
            if [ -f "$file" ]; then
                local category=$(basename "$file" .txt)
                local count=$(wc -l < "$file")
                
                if [ "$first" = true ]; then
                    first=false
                else
                    echo ","
                fi
                echo -n "    {\"category\": \"$category\", \"count\": $count}"
            fi
        done
        
        echo ""
        echo "  ],"
        echo "  \"total_urls\": $(find "$OUTPUT_DIR" -name "*.txt" -exec wc -l {} + | tail -1 | awk '{print $1}')"
        echo "}"
    } > "$summary_file"

    success "JSON report: $summary_file"
}

output_csv() {
    if [ "$DRY_RUN" = true ]; then
        warning "DRY-RUN: Would generate CSV report"
        return 0
    fi

    local csv_file="$OUTPUT_DIR/results.csv"
    
    echo "category,url,count" > "$csv_file"
    
    for file in "$OUTPUT_DIR"/*.txt; do
        if [ -f "$file" ]; then
            local category=$(basename "$file" .txt)
            local count=$(wc -l < "$file")
            echo "$category,file,${count}" >> "$csv_file"
        fi
    done

    success "CSV report: $csv_file"
}

output_html() {
    if [ "$DRY_RUN" = true ]; then
        warning "DRY-RUN: Would generate HTML report"
        return 0
    fi

    local html_file="$OUTPUT_DIR/report.html"
    local total_urls=0

    {
        echo "<!DOCTYPE html>"
        echo "<html>"
        echo "<head>"
        echo "  <title>Link Categorizer Report</title>"
        echo "  <style>"
        echo "    body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }"
        echo "    .container { max-width: 1000px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }"
        echo "    h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }"
        echo "    table { width: 100%; border-collapse: collapse; margin-top: 20px; }"
        echo "    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }"
        echo "    th { background: #007bff; color: white; }"
        echo "    tr:hover { background: #f9f9f9; }"
        echo "    .stat { display: inline-block; margin: 10px 20px 10px 0; }"
        echo "    .stat-value { font-size: 24px; font-weight: bold; color: #007bff; }"
        echo "    .stat-label { color: #666; font-size: 12px; }"
        echo "  </style>"
        echo "</head>"
        echo "<body>"
        echo "  <div class='container'>"
        echo "    <h1>Link Categorizer Report</h1>"
        echo "    <p>Generated: $(date)</p>"
        echo "    <p>Scan ID: $SCAN_ID</p>"
        echo ""
        echo "    <div class='stats'>"

        for file in "$OUTPUT_DIR"/*.txt; do
            if [ -f "$file" ]; then
                local category=$(basename "$file" .txt)
                local count=$(wc -l < "$file")
                total_urls=$((total_urls + count))
                echo "      <div class='stat'>"
                echo "        <div class='stat-value'>$count</div>"
                echo "        <div class='stat-label'>$category</div>"
                echo "      </div>"
            fi
        done

        echo "    </div>"
        echo ""
        echo "    <table>"
        echo "      <thead><tr><th>Category</th><th>Count</th><th>Percentage</th></tr></thead>"
        echo "      <tbody>"

        for file in "$OUTPUT_DIR"/*.txt; do
            if [ -f "$file" ]; then
                local category=$(basename "$file" .txt)
                local count=$(wc -l < "$file")
                local percentage=$(echo "scale=2; $count * 100 / $total_urls" | bc 2>/dev/null || echo "0")
                echo "      <tr><td>$category</td><td>$count</td><td>${percentage}%</td></tr>"
            fi
        done

        echo "      </tbody>"
        echo "    </table>"
        echo ""
        echo "    <p><strong>Total URLs:</strong> $total_urls</p>"
        echo "  </div>"
        echo "</body>"
        echo "</html>"
    } > "$html_file"

    success "HTML report: $html_file"
}

output_sarif() {
    if [ "$DRY_RUN" = true ]; then
        warning "DRY-RUN: Would generate SARIF report"
        return 0
    fi

    local sarif_file="$OUTPUT_DIR/results.sarif"

    {
        echo "{"
        echo "  \"version\": \"2.1.0\","
        echo "  \"runs\": ["
        echo "    {"
        echo "      \"tool\": {"
        echo "        \"driver\": {"
        echo "          \"name\": \"link-categorizer\","
        echo "          \"version\": \"2.0\","
        echo "          \"informationUri\": \"https://github.com/\""
        echo "        }"
        echo "      },"
        echo "      \"results\": ["

        local first=true
        for file in "$OUTPUT_DIR"/*.txt; do
            if [ -f "$file" ]; then
                local category=$(basename "$file" .txt)
                while IFS= read -r url; do
                    if [ -n "$url" ]; then
                        if [ "$first" = true ]; then
                            first=false
                        else
                            echo ","
                        fi
                        echo -n "        {\"ruleId\": \"$category\", \"message\": {\"text\": \"Found $category vulnerability pattern\"}, \"locations\": [{\"logicalLocations\": [{\"name\": \"$url\"}]}]}"
                    fi
                done < "$file"
            fi
        done

        echo ""
        echo "      ]"
        echo "    }"
        echo "  ]"
        echo "}"
    } > "$sarif_file"

    success "SARIF report: $sarif_file"
}

generate_report() {
    if [ "$REPORT_ENABLED" = false ]; then
        return 0
    fi

    log "INFO" "Generating comprehensive report"
    
    for format in "${OUTPUT_FORMATS[@]}"; do
        case "$format" in
            json) output_json "$INPUT_FILE" ;;
            csv) output_csv ;;
            html) output_html ;;
            sarif) output_sarif ;;
        esac
    done
}

# ============================================================================
# Webhook Notification
# ============================================================================

send_webhook() {
    if [ -z "$WEBHOOK_URL" ]; then
        return 0
    fi

    if ! command -v curl &> /dev/null; then
        warning "curl not found, webhook skipped"
        return 0
    fi

    log "INFO" "Sending webhook notification"
    
    local total=$(find "$OUTPUT_DIR" -name "*.txt" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    
    local payload=$(cat <<EOF
{
    "text": "Link Categorizer Scan Complete",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Link Categorizer Scan Complete*\nScan ID: $SCAN_ID\nTotal URLs: $total\nTime: $(date)"
            }
        }
    ]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' --data "$payload" "$WEBHOOK_URL" 2>/dev/null || warning "Webhook notification failed"
}

# ============================================================================
# Main Categorization Logic
# ============================================================================

categorize_all() {
    local input_file=$1
    INPUT_FILE="$input_file"
    
    if [ ! -f "$input_file" ]; then
        error "Input file not found: $input_file"
    fi

    log "INFO" "Starting categorization of: $input_file"
    
    mkdir -p "$OUTPUT_DIR"
    
    # Load patterns
    local patterns=$(load_patterns)
    
    # Count total URLs
    local total_urls=$(wc -l < "$input_file")
    log "INFO" "Total URLs to process: $total_urls"
    
    log "INFO" "Processing URLs sequentially"
    local count=0
    local temp_results="${OUTPUT_DIR}/.temp_results"
    > "$temp_results"
    
    while IFS= read -r url; do
        process_url "$url" "$patterns" >> "$temp_results" 2>/dev/null || true
        
        count=$((count + 1))
        if [ "$PROGRESS" = true ] && [ $((count % 100)) -eq 0 ]; then
            local pct=$((count * 100 / total_urls))
            echo -ne "\rProcessed: $count / $total_urls [$pct%]"
        fi
    done < "$input_file"
    echo ""

    # Consolidate results
    log "INFO" "Consolidating results"
    if [ -f "${OUTPUT_DIR}/.temp_results" ]; then
        while IFS='|' read -r category url status rtime; do
            echo "$url" >> "${OUTPUT_DIR}/${category}.txt"
        done < "${OUTPUT_DIR}/.temp_results"
        rm "${OUTPUT_DIR}/.temp_results"
    fi
    
    # Display summary
    echo ""
    echo -e "${BLUE}[*] Categorization Summary:${NC}"
    for file in "$OUTPUT_DIR"/*.txt; do
        if [ -f "$file" ]; then
            local category=$(basename "$file" .txt)
            local count=$(wc -l < "$file")
            output_txt "$category" "$count"
        fi
    done
    
    # Generate reports
    generate_report
    
    # Send webhook
    send_webhook
    
    success "Categorization complete. Results in: $OUTPUT_DIR"
}

# ============================================================================
# Argument Parsing
# ============================================================================

main() {
    local input_file=""
    local http_timeout=5

    # Initialize OUTPUT_FORMATS if not set
    if [ ${#OUTPUT_FORMATS[@]} -eq 0 ]; then
        OUTPUT_FORMATS=("txt")
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMATS+=("$2")
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -v|--validate-http)
                VALIDATE_HTTP=true
                shift
                ;;
            -p|--progress)
                PROGRESS=true
                shift
                ;;
            -d|--domain)
                FILTER_DOMAINS+=("$2")
                shift 2
                ;;
            -e|--exclude)
                EXCLUDE_DOMAINS+=("$2")
                shift 2
                ;;
            -t|--timeout)
                http_timeout="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --database)
                DATABASE_ENABLED=true
                shift
                ;;
            --webhook)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --report)
                REPORT_ENABLED=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                input_file="$1"
                shift
                ;;
        esac
    done

    if [ -z "$input_file" ]; then
        error "No input file specified. Use -h for help."
    fi

    # Initialize
    init_cache
    load_config
    init_database
    
    # Display settings if verbose
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Configuration:${NC}"
        echo "  Input: $input_file"
        echo "  Output: $OUTPUT_DIR"
        echo "  Formats: ${OUTPUT_FORMATS[@]}"
        echo "  Parallel Jobs: $PARALLEL_JOBS"
        echo "  HTTP Validation: $VALIDATE_HTTP"
        echo "  Database: $DATABASE_ENABLED"
        echo "  Reports: $REPORT_ENABLED"
        [ ${#FILTER_DOMAINS[@]} -gt 0 ] && echo "  Filter Domains: ${FILTER_DOMAINS[@]}"
        [ ${#EXCLUDE_DOMAINS[@]} -gt 0 ] && echo "  Exclude Domains: ${EXCLUDE_DOMAINS[@]}"
        echo ""
    fi

    # Run categorization
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY-RUN MODE${NC}"
        success "Would categorize: $input_file"
    else
        categorize_all "$input_file"
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

main "$@"
