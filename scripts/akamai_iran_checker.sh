#!/bin/bash

# =============================================
# Akamai IP Checker - Tests FROM IRAN
# Uses check-host.net Iranian nodes
# For ShirOKhorshid CDN Fronting
# =============================================

WORKING_IPS=()
FAILED_IPS=()

# Iranian nodes on check-host.net
IR_NODES="ir1.node.check-host.net&node=ir2.node.check-host.net&node=ir3.node.check-host.net&node=ir4.node.check-host.net"

echo "======================================"
echo " Akamai IP Checker - Tests From IRAN"
echo " Using check-host.net Iranian nodes"
echo "======================================"
echo ""

# ---- Known Akamai IPs to test ----
ALL_IPS=(
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

# ---- Also resolve fresh IPs from Akamai domains ----
echo "[1/3] Resolving fresh Akamai IPs from domains..."
DOMAINS=(
  "www.apple.com"
  "www.microsoft.com"
  "www.adobe.com"
  "www.ibm.com"
  "www.cisco.com"
  "www.dell.com"
  "www.hp.com"
  "www.sony.com"
  "www.bbc.com"
  "www.oracle.com"
)

for domain in "${DOMAINS[@]}"; do
  RESOLVED=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
  for ip in $RESOLVED; do
    ALL_IPS+=("$ip")
  done
  echo "  ✓ $domain"
done

# Remove duplicates
UNIQUE_IPS=($(echo "${ALL_IPS[@]}" | tr ' ' '\n' | sort -u))
echo ""
echo "  Total unique IPs to test: ${#UNIQUE_IPS[@]}"

# ---- Test each IP from Iranian nodes ----
echo ""
echo "[2/3] Testing each IP from Iranian nodes..."
echo "  (This takes ~10 seconds per IP, please wait)"
echo ""

check_ip_from_iran() {
  local IP=$1

  # Submit TCP check request to check-host.net using Iranian nodes
  RESPONSE=$(curl -s \
    -H "Accept: application/json" \
    "https://check-host.net/check-tcp?host=${IP}:443&node=${IR_NODES}" \
    --max-time 15 2>/dev/null)

  # Get request ID
  REQUEST_ID=$(echo "$RESPONSE" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get('request_id',''))
except:
  print('')
" 2>/dev/null)

  if [ -z "$REQUEST_ID" ]; then
    echo "  ❌ $IP (API error)"
    return 1
  fi

  # Wait for results
  sleep 8

  # Get results
  RESULT=$(curl -s \
    -H "Accept: application/json" \
    "https://check-host.net/check-result/$REQUEST_ID" \
    --max-time 15 2>/dev/null)

  # Parse results - check if ANY Iranian node succeeded
  SUCCESS=$(echo "$RESULT" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  ok=0
  fail=0
  for node,result in d.items():
    if 'ir' in node:
      if result and isinstance(result, list) and result[0]:
        r=result[0]
        if isinstance(r, dict) and 'time' in r:
          ok+=1
        elif isinstance(r, dict) and 'error' in r:
          fail+=1
      else:
        fail+=1
  print(f'{ok},{fail}')
except Exception as e:
  print('0,0')
" 2>/dev/null)

  OK_COUNT=$(echo "$SUCCESS" | cut -d',' -f1)
  FAIL_COUNT=$(echo "$SUCCESS" | cut -d',' -f2)

  if [ "$OK_COUNT" -gt 0 ] 2>/dev/null; then
    echo "  ✅ $IP (works from $OK_COUNT Iranian node(s))"
    return 0
  else
    echo "  ❌ $IP (blocked in Iran - $FAIL_COUNT failed)"
    return 1
  fi
}

for IP in "${UNIQUE_IPS[@]}"; do
  if check_ip_from_iran "$IP"; then
    WORKING_IPS+=("$IP")
  else
    FAILED_IPS+=("$IP")
  fi
  # Small delay to avoid rate limiting
  sleep 2
done

# ---- Output Results ----
echo ""
echo "[3/3] Generating results..."
echo ""
echo "======================================"
echo " RESULTS"
echo "======================================"
echo ""
echo "✅ Working in Iran: ${#WORKING_IPS[@]}"
echo "❌ Blocked in Iran: ${#FAILED_IPS[@]}"
echo ""

if [ ${#WORKING_IPS[@]} -eq 0 ]; then
  echo "No working IPs found from Iran."
  echo "Try running again - check-host.net may have been rate limited."
  exit 1
fi

# Comma-separated output
CSV=$(IFS=','; echo "${WORKING_IPS[*]}")

echo "--------------------------------------"
echo " PASTE THIS INTO ShirOKhorshid:"
echo " Settings → CDN edge IPs"
echo "--------------------------------------"
echo ""
echo "$CSV"
echo ""

# Save to file
echo "$CSV" > akamai_iran_working.txt
echo "--------------------------------------"
echo " Saved to: akamai_iran_working.txt"
echo ""
echo " CDN SNI Hostname:"
echo " a248.e.akamai.net"
echo "======================================"
