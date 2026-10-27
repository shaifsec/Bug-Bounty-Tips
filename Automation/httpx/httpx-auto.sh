
#!/usr/bin/env bash

set -uo pipefail

OUTDIR="httpx-results"
MODEL="/opt/httpx/model.json"

if ! read -r -p "Enter the path to your subdomain .txt file: " INPUT; then
    echo "[!] Could not read the input file path."
    exit 1
fi

if [[ -z "$INPUT" ]]; then
    echo "[!] No input file path provided."
    exit 1
fi

if [[ "${INPUT,,}" != *.txt ]]; then
    echo "[!] Input file must have a .txt extension."
    exit 1
fi

# Check input and dependencies
if [[ ! -f "$INPUT" ]]; then
    echo "[!] $INPUT not found."
    exit 1
fi

if ! command -v httpx >/dev/null 2>&1; then
    echo "[!] httpx is not installed or not in PATH."
    exit 1
fi

mkdir -p "$OUTDIR"

# Remove blank lines, comments, and duplicate targets
grep -vE '^[[:space:]]*(#|$)' "$INPUT" | sort -u > "$OUTDIR/targets.txt"
TARGETS="$OUTDIR/targets.txt"

if [[ ! -s "$TARGETS" ]]; then
    echo "[!] No targets found."
    exit 1
fi

echo "[+] Targets loaded: $(wc -l < "$TARGETS")"
echo "[+] Results directory: $OUTDIR"

# Common HTTP response filter
FILTER=(-silent -fc 404,401)

# 1. HTTP probing and technology detection
echo "[1] HTTP probing..."
httpx -l "$TARGETS" "${FILTER[@]}" \
    -sc -title -cl -location -cname -server -td \
    -o "$OUTDIR/httpx.txt"

# 2. Knowledge-base detection
if [[ -f "$MODEL" ]]; then
    echo "[2] Knowledge-base scan..."
    httpx -l "$TARGETS" -silent -fc 404,401 \
        -kb -json -ptm "$MODEL" \
        -o "$OUTDIR/httpx-kb.jsonl"

    # 3. Error and parked fingerprints
    echo "[3] Error/parked fingerprint scan..."
    httpx -l "$TARGETS" -silent -fc 404,401 \
        -fpt error,parked -ptm "$MODEL" \
        -o "$OUTDIR/httpx-fingerprints.txt"
else
    echo "[!] Model not found: $MODEL"
    echo "[!] Skipping model-based scans."
fi

# Helper function for checking paths
check_path() {
    local path="$1"
    local matcher="$2"
    local output="$3"

    echo "[*] Checking $path"

    httpx -l "$TARGETS" -silent -fc 404,401 \
        -path "$path" \
        -mc 200 \
        -mdc "$matcher" \
        -o "$OUTDIR/$output.txt"
}

# 4. Common files and metadata
echo "[4] Checking common files..."

check_path "/robots.txt" \
    'contains(content_type, "text/plain")' \
    "robots"

check_path "/sitemap.xml" \
    'contains_any(content_type, "application/xml", "text/xml") && contains(body, "<urlset")' \
    "sitemap"

check_path "/humans.txt" \
    'contains(content_type, "text/plain")' \
    "humans"

check_path "/ads.txt" \
    'contains(content_type, "text/plain") && contains(body, "google.com")' \
    "ads"

check_path "/.well-known/openid-configuration" \
    'contains(content_type, "application/json") && contains(body, "\"issuer\"")' \
    "openid"

check_path "/.well-known/apple-app-site-association,/.well-known/apple-app-site-association.json" \
    'contains(content_type, "application/json") && contains(body, "\"applinks\"")' \
    "apple-app-site-association"

check_path "/.well-known/assetlinks.json" \
    'contains(content_type, "application/json") && contains(body, "\"android_app\"")' \
    "android-assetlinks"

check_path "/crossdomain.xml" \
    'contains_any(content_type, "application/xml", "text/xml") && contains(body, "cross-domain-policy")' \
    "crossdomain"

# 5. Well-known endpoints
echo "[5] Checking well-known endpoints..."

httpx -l "$TARGETS" -silent -fc 404,401 \
    -path "/.well-known/security.txt,/.well-known/change-password,/.well-known/openid-configuration" \
    -mc 200 \
    -o "$OUTDIR/well-known.txt"

echo
echo "[+] Automation completed."
echo "[+] Results saved in: $OUTDIR/"
