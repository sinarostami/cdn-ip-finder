#!/bin/bash

# =============================================
# Akamai IP Finder & Tester for ShirOKhorshid
# =============================================

WORKING_IPS=()
TIMEOUT=3

echo "======================================"
echo " Akamai IP Finder for ShirOKhorshid"
echo "======================================"
echo ""

# ---- Step 1: Collect IPs from Akamai-hosted domains ----
echo "[1/4] Resolving Akamai-hosted domains..."

DOMAINS=(
  "www.apple.com"
  "www.microsoft.com"
  "www.adobe.com"
  "www.intel.com"
  "www.ibm.com"
  "www.dell.com"
  "www.hp.com"
  "www.sony.com"
  "www.nbc.com"
  "www.bbc.com"
  "www.cisco.com"
  "www.oracle.com"
  "www.sap.com"
  "www.vmware.com"
  "www.salesforce.com"
  "www.paypal.com"
  "www.ebay.com"
  "www.linkedin.com"
  "www.nasa.gov"
  "www.usps.com"
)

ALL_IPS=()

for domain in "${DOMAINS[@]}"; do
  RESOLVED=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
  for ip in $RESOLVED; do
    ALL_IPS+=("$ip")
  done
  echo "  ✓ $domain"
done

# ---- Step 2: Add known Akamai IP ranges ----
echo ""
echo "[2/4] Adding known Akamai IP ranges..."

KNOWN_AKAMAI=(
  "2.22.250.149"
  "23.58.193.140"
  "23.48.23.151"
  "23.48.23.186"
  "23.48.23.133"
  "23.48.23.195"
  "23.48.23.178"
  "23.43.237.239"
  "104.112.146.82"
  "23.2.13.136"
  "72.246.28.3"
  "72.18.63.4"
  "92.16.53.11"
  "92.16.53.50"
  "92.16.19.136"
  "184.24.77.42"
  "184.24.77.32"
  "184.24.77.5"
  "184.24.77.7"
  "184.24.77.16"
  "184.24.77.36"
  "184.24.77.21"
  "184.24.77.11"
  "184.24.77.29"
  "185.200.232.49"
  "185.200.232.50"
  "185.200.232.42"
  "185.200.232.41"
  "185.200.232.8"
  "185.200.232.43"
  "185.200.232.40"
  "185.143.232.122"
  "185.200.232.9"
  "185.200.232.11"
  "185.200.232.16"
  "185.200.232.17"
  "185.200.232.19"
  "185.200.232.24"
  "185.200.232.25"
  "185.200.232.26"
  "185.200.232.34"
  "12.19.126.81"
  "23.202.138.125"
  "2.19.126.81"
)

for ip in "${KNOWN_AKAMAI[@]}"; do
  ALL_IPS+=("$ip")
done

echo "  ✓ Added ${#KNOWN_AKAMAI[@]} known Akamai IPs"

# ---- Step 3: Remove duplicates ----
echo ""
echo "[3/4] Removing duplicates..."
UNIQUE_IPS=($(echo "${ALL_IPS[@]}" | tr ' ' '\n' | sort -u))
echo "  ✓ ${#UNIQUE_IPS[@]} unique IPs to test"

# ---- Step 4: Test each IP ----
echo ""
echo "[4/4] Testing IPs (timeout: ${TIMEOUT}s each)..."
echo ""

for ip in "${UNIQUE_IPS[@]}"; do
  # Test HTTPS connection to the IP
  RESULT=$(curl -sk \
    --max-time "$TIMEOUT" \
    --connect-timeout "$TIMEOUT" \
    -o /dev/null \
    -w "%{http_code}" \
    --resolve "a248.e.akamai.net:443:$ip" \
    "https://a248.e.akamai.net/" 2>/dev/null)

  if [[ "$RESULT" =~ ^[0-9]+$ ]] && [ "$RESULT" -lt 600 ] && [ "$RESULT" -gt 0 ]; then
    echo "  ✅ $ip (HTTP $RESULT)"
    WORKING_IPS+=("$ip")
  else
    echo "  ❌ $ip"
  fi
done

# ---- Output Results ----
echo ""
echo "======================================"
echo " RESULTS"
echo "======================================"
echo ""
echo "Working IPs: ${#WORKING_IPS[@]} / ${#UNIQUE_IPS[@]}"
echo ""

if [ ${#WORKING_IPS[@]} -eq 0 ]; then
  echo "No working IPs found. Try increasing the timeout."
  exit 1
fi

# Comma-separated output
CSV=$(IFS=','; echo "${WORKING_IPS[*]}")

echo "--------------------------------------"
echo " PASTE THIS INTO ShirOKhorshid:"
echo " CDN edge IPs field"
echo "--------------------------------------"
echo ""
echo "$CSV"
echo ""

# Also save to file
echo "$CSV" > akamai_ips.txt
echo "--------------------------------------"
echo " Also saved to: akamai_ips.txt"
echo ""
echo " CDN SNI Hostname to use:"
echo " a248.e.akamai.net"
echo "======================================"
