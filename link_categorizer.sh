#!/bin/bash

# --- Setup ---
if [ -z "$1" ]; then
    echo "Usage: $0 <url_file>"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_DIR="extreme_categorized_urls"
mkdir -p "$OUTPUT_DIR"

echo "[*] Initializing contextual filtering on $INPUT_FILE..."

# --- Professional Categorization Engine ---
# Logic: We use specific URL patterns (params, sensitive paths, extensions) 
# instead of broad words to minimize "noise."

categorize() {
    local label=$1
    local pattern=$2
    local outfile="$OUTPUT_DIR/$label.txt"

    # Use grep with Extended Regex (-E) and Case-Insensitive (-i)
    # Filter out common binary/static noise (images, fonts, etc.)
    grep -iE "$pattern" "$INPUT_FILE" | \
    grep -ivE "\.(jpg|jpeg|png|gif|woff|woff2|ttf|css|ico|svg)$" > "$outfile"

    if [ ! -s "$outfile" ]; then
        rm "$outfile"
    else
        echo "    [+] $(printf '%-20s' "$label") : $(wc -l < "$outfile") hits"
    fi
}

# --- Intelligence Layer: Pattern Definitions ---

# SQLi: Focus on ID-like params or common DB keywords in query strings
categorize "sqli" "(\?|&)(id|query|search|select|from|where|order|limit|sort|cat|p|page)="

# XSS: Target parameters that typically reflect input
categorize "xss" "(\?|&)(q|s|search|id|lang|name|msg|text|redirect|url|callback|email|user)="

# XXE / API: Target XML endpoints or Content-Type indicating parameters
categorize "xxe" "\.(xml|svg|xhtml|xsd)$|/api/|/soap|/rpc|(\?|&)(data|xml|file|doc)="

# Path Traversal: Target parameters that fetch files
categorize "path_traversal" "(\?|&)(file|path|page|doc|root|dir|folder|view|load|read|include|img|image)="

# SSRF: Target parameters containing other URLs or IP-like structures
categorize "ssrf" "(\?|&)(url|uri|link|dest|redirect|path|domain|host|proxy|site|to)="

# Auth / OAuth: Focus on critical action paths, not just any page with 'login'
categorize "auth_oauth" "/(login|signup|register|logout|auth|callback|token|authorize|password|mfa|signin|session)"

# IDOR / Access Control: Target paths with numeric or UUID identifiers
categorize "access_control" "/(api|v1|v2|user|settings|profile|edit|update|delete|v3)/[0-9a-zA-Z-]+"

# CSRF: Target state-changing paths (POST-like actions)
categorize "csrf" "/(update|delete|add|remove|change|settings|transfer|email|profile|password)"

# Web Cache Deception: Target sensitive paths that could be cached as static files
categorize "cache_deception" "/(my-account|profile|settings|dashboard|home|inbox)$"

# SSTI: Focus on template-heavy parameters or engines
categorize "ssti" "(\?|&)(template|name|id|email|preview|layout|render)="

# Open Redirect: Narrow focus on redirect parameters
categorize "open_redirect" "(\?|&)(next|url|redirect|return|r|goto|link|dest|to)="

# JSON Web Token (JWT): Find tokens in URLs (uncommon but critical)
categorize "jwt_leaks" "ey[a-zA-Z0-9_-]+\.ey[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"

echo "[*] Categorization complete. Results saved in '$OUTPUT_DIR/'."
