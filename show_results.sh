#!/bin/bash
cd /mnt/c/Users/User/Desktop/link_categorizer/extreme_categorized_urls
echo "=== Final Categorization Results ==="
echo ""
for f in *.txt; do
    COUNT=$(wc -l < "$f")
    printf "%-30s: %8d URLs\n" "${f%.txt}" "$COUNT"
done | sort -t: -k2 -rn
echo ""
echo "Total: $(cat *.txt | wc -l) URLs"
