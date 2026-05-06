#!/bin/bash
# Enhanced categorizer with proper vulnerability patterns
OUTPUT_DIR='./extreme_categorized_urls'
mkdir -p "$OUTPUT_DIR" && rm -f "$OUTPUT_DIR"/*.txt

echo "[*] Deep pattern analysis on Dyson BBP data..."
START=$(date +%s)

# Enhanced pattern matching with proper priorities
awk -v outdir="$OUTPUT_DIR" '{
    url = tolower($0)
    cat = "other"
    
    # SQL Injection patterns (high priority)
    if (url ~ /union.*select|select.*from|drop.*table|insert.*into|update.*set|delete.*from/ ||
        url ~ /or[[:space:]]*1[[:space:]]*=|and[[:space:]]*1[[:space:]]*=/ ||
        url ~ /sql|injection|sqli/) {
        cat = "sqli"
    }
    # XSS patterns
    else if (url ~ /<script|javascript:|onerror=|onload=|onmouseover=|alert\(/ ||
        url ~ /xss|cross.?site/) {
        cat = "xss"
    }
    # XXE patterns
    else if (url ~ /xxe|xml.*entity|<!entity|doctype/) {
        cat = "xxe"
    }
    # Path Traversal
    else if (url ~ /\.\.\/?|\.\.\\|path.*traversal|directory.*traversal/) {
        cat = "path_traversal"
    }
    # SSRF patterns
    else if (url ~ /ssrf|server.?side.*request|url=http|fetch=http|curl=/) {
        cat = "ssrf"
    }
    # Authentication/OAuth
    else if (url ~ /oauth|openid|saml|bearer.*token|auth.*token|password=|pwd=/) {
        cat = "auth_oauth"
    }
    # Access Control
    else if (url ~ /admin|root|superuser|privilege|permission|role=|acl/) {
        cat = "access_control"
    }
    # CSRF patterns
    else if (url ~ /csrf|cross.?request|xsrf|token.*validation/) {
        cat = "csrf"
    }
    # Cache poisoning
    else if (url ~ /cache.*header|cache.*control|x.?original|x.?forwarded|x.?real/) {
        cat = "cache_deception"
    }
    # SSTI patterns
    else if (url ~ /ssti|template.*injection|jinja|erb|velocity|freemarker/ ||
        url ~ /\{\{|<#|<%|#set/) {
        cat = "ssti"
    }
    # Open Redirect
    else if (url ~ /redirect|location|url=|goto|next=|return_to=|continue=|back=/ ||
        url ~ /\?url=|&url=|\?redirect=|&redirect=/) {
        cat = "open_redirect"
    }
    # JWT/Token leaks
    else if (url ~ /jwt|json.?web.*token|eyj[a-z0-9]/) {
        cat = "jwt_leaks"
    }
    # GraphQL
    else if (url ~ /graphql|apollo|gql/) {
        cat = "graphql_injection"
    }
    # API Key exposure
    else if (url ~ /api[_-]?key|apikey|secret|api[_-]?secret|access[_-]?key/) {
        cat = "api_key_exposure"
    }
    # Cloud Storage
    else if (url ~ /s3|bucket|azure|gcs|blob|storage/ ||
        url ~ /amazonaws|cloudfront|azurewebsites|storage\.googleapis/) {
        cat = "cloud_storage"
    }
    # Insecure Deserialization
    else if (url ~ /serialize|pickle|java.*object|php.*object|unmarsh|gadget/) {
        cat = "insecure_deserialization"
    }
    # File Inclusion
    else if (url ~ /include|require|file=|load=|page=|view=|template=/) {
        cat = "file_inclusion"
    }
    # RCE patterns
    else if (url ~ /exec|system|eval|code.*execution|remote.*command/ ||
        url ~ /shell|cmd|command=|process=/) {
        cat = "rce"
    }
    
    print $0 >> (outdir "/" cat ".txt")
}' "$1"

END=$(date +%s)
ELAPSED=$((END - START))

echo "[+] Done! ($ELAPSED seconds)"
echo ""
echo "=== Categorization Results ==="
echo ""
for file in "$OUTPUT_DIR"/*.txt; do
    if [ -f "$file" ]; then
        COUNT=$(wc -l < "$file")
        NAME=$(basename "$file" .txt)
        printf "  %-25s: %8d URLs\n" "$NAME" "$COUNT"
    fi
done | sort -rn -k3

echo ""
TOTAL=$(cat "$OUTPUT_DIR"/*.txt 2>/dev/null | wc -l)
echo "Total URLs categorized: $TOTAL"

