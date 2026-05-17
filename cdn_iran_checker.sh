#!/bin/bash

# =============================================
# CDN IP Finder & Iran Tester
# Tests: Akamai, Google, Amazon, Microsoft
# For ShirOKhorshid CDN Fronting
# =============================================

WORKING_IPS=()
SLEEP_BETWEEN=2
CHECK_WAIT=8

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Iranian nodes
IR_NODES="ir1.node.check-host.net&node=ir2.node.check-host.net&node=ir3.node.check-host.net&node=ir4.node.check-host.net"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║   CDN IP Finder & Iran Tester            ║"
echo "║   For ShirOKhorshid CDN Fronting         ║"
echo "║   Tests: Akamai, Google, Amazon, Azure   ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================
# STEP 1: Check which CDNs are accessible in Iran
# =============================================

echo -e "${YELLOW}[STEP 1] Checking which CDNs are accessible from Iran...${NC}"
echo ""

ACCESSIBLE_CDNS=()

check_cdn_iran() {
  local CDN_NAME=$1
  local TEST_HOST=$2
  local TEST_PORT=${3:-443}

  echo -n "  Testing $CDN_NAME... "

  RESPONSE=$(curl -s \
    -H "Accept: application/json" \
    "https://check-host.net/check-tcp?host=${TEST_HOST}:${TEST_PORT}&node=${IR_NODES}" \
    --max-time 15 2>/dev/null)

  REQUEST_ID=$(echo "$RESPONSE" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get('request_id',''))
except:
  print('')
" 2>/dev/null)

  if [ -z "$REQUEST_ID" ]; then
    echo -e "${RED}❌ API error${NC}"
    return 1
  fi

  sleep $CHECK_WAIT

  RESULT=$(curl -s \
    -H "Accept: application/json" \
    "https://check-host.net/check-result/$REQUEST_ID" \
    --max-time 15 2>/dev/null)

  STATS=$(echo "$RESULT" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  ok=0
  fail=0
  for node,result in d.items():
    if 'ir' in node:
      if result and isinstance(result,list) and result[0]:
        r=result[0]
        if isinstance(r,dict) and 'time' in r:
          ok+=1
        else:
          fail+=1
      else:
        fail+=1
  print(f'{ok},{fail}')
except:
  print('0,0')
" 2>/dev/null)

  OK=$(echo "$STATS" | cut -d',' -f1)
  FAIL=$(echo "$STATS" | cut -d',' -f2)

  if [ "$OK" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Accessible from Iran ($OK/4 nodes)${NC}"
    ACCESSIBLE_CDNS+=("$CDN_NAME")
    return 0
  else
    echo -e "${RED}❌ Blocked in Iran${NC}"
    return 1
  fi
}

# Test each CDN
check_cdn_iran "Akamai"    "a248.e.akamai.net"
AKAMAI_OK=$?
sleep $SLEEP_BETWEEN

check_cdn_iran "Google"    "www.googleapis.com"
GOOGLE_OK=$?
sleep $SLEEP_BETWEEN

check_cdn_iran "Amazon"    "cloudfront.net"
AMAZON_OK=$?
sleep $SLEEP_BETWEEN

check_cdn_iran "Microsoft" "ajax.aspnetcdn.com"
AZURE_OK=$?
sleep $SLEEP_BETWEEN

echo ""
echo -e "${CYAN}Accessible CDNs: ${ACCESSIBLE_CDNS[*]}${NC}"
echo ""

# =============================================
# STEP 2: Collect IPs for accessible CDNs
# =============================================

echo -e "${YELLOW}[STEP 2] Collecting IPs for accessible CDNs...${NC}"
echo ""

ALL_IPS=()

# ---- AKAMAI IPs ----
if [ $AKAMAI_OK -eq 0 ]; then
  echo -e "  ${BLUE}Collecting Akamai IPs...${NC}"

  # Known Akamai IPs
  AKAMAI_IPS=(
    "2.22.250.149"   "23.58.193.140"  "23.48.23.151"
    "23.48.23.186"   "23.48.23.133"   "23.48.23.195"
    "23.48.23.178"   "23.43.237.239"  "104.112.146.82"
    "23.2.13.136"    "72.246.28.3"    "72.18.63.4"
    "92.16.53.11"    "92.16.53.50"    "92.16.19.136"
    "184.24.77.42"   "184.24.77.32"   "184.24.77.5"
    "184.24.77.7"    "184.24.77.16"   "184.24.77.36"
    "184.24.77.21"   "184.24.77.11"   "184.24.77.29"
    "185.200.232.49" "185.200.232.50" "185.200.232.42"
    "185.200.232.41" "185.200.232.8"  "185.200.232.43"
    "185.200.232.40" "185.143.232.122" "185.200.232.9"
    "185.200.232.11" "185.200.232.16" "185.200.232.17"
    "185.200.232.19" "185.200.232.24" "185.200.232.25"
    "185.200.232.26" "185.200.232.34" "12.19.126.81"
    "23.202.138.125" "2.19.126.81"
  )

  # Resolve fresh Akamai IPs from domains
  AKAMAI_DOMAINS=(
    "www.apple.com" "www.microsoft.com" "www.adobe.com"
    "www.intel.com" "www.ibm.com" "www.cisco.com"
    "www.dell.com"  "www.hp.com"  "www.sony.com"
    "www.bbc.com"   "www.oracle.com" "www.paypal.com"
  )

  for domain in "${AKAMAI_DOMAINS[@]}"; do
    RESOLVED=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    for ip in $RESOLVED; do
      AKAMAI_IPS+=("$ip")
    done
  done

  for ip in "${AKAMAI_IPS[@]}"; do
    ALL_IPS+=("akamai|$ip")
  done
  echo "  ✓ Collected ${#AKAMAI_IPS[@]} Akamai IPs"
fi

# ---- GOOGLE IPs ----
if [ $GOOGLE_OK -eq 0 ]; then
  echo -e "  ${BLUE}Collecting Google IPs...${NC}"

  GOOGLE_IPS=()

  # Resolve Google CDN domains
  GOOGLE_DOMAINS=(
    "www.googleapis.com"
    "ajax.googleapis.com"
    "fonts.googleapis.com"
    "storage.googleapis.com"
    "accounts.google.com"
    "www.gstatic.com"
    "ssl.gstatic.com"
  )

  for domain in "${GOOGLE_DOMAINS[@]}"; do
    RESOLVED=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    for ip in $RESOLVED; do
      GOOGLE_IPS+=("$ip")
    done
  done

  # Add Cloud Run IPs we discovered earlier
  GOOGLE_IPS+=(
    "34.143.72.2" "34.143.73.2" "34.143.74.2"
    "34.143.75.2" "34.143.76.2" "34.143.77.2"
    "34.143.78.2" "34.143.79.2"
  )

  for ip in "${GOOGLE_IPS[@]}"; do
    ALL_IPS+=("google|$ip")
  done
  echo "  ✓ Collected ${#GOOGLE_IPS[@]} Google IPs"
fi

# ---- AMAZON CLOUDFRONT IPs ----
if [ $AMAZON_OK -eq 0 ]; then
  echo -e "  ${BLUE}Collecting Amazon CloudFront IPs...${NC}"

  AMAZON_IPS=()

  AMAZON_DOMAINS=(
    "d1.awsstatic.com"
    "aws.amazon.com"
    "d36cz9buwru1tt.cloudfront.net"
    "images-na.ssl-images-amazon.com"
  )

  for domain in "${AMAZON_DOMAINS[@]}"; do
    RESOLVED=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    for ip in $RESOLVED; do
      AMAZON_IPS+=("$ip")
    done
  done

  for ip in "${AMAZON_IPS[@]}"; do
    ALL_IPS+=("amazon|$ip")
  done
  echo "  ✓ Collected ${#AMAZON_IPS[@]} Amazon IPs"
fi

# ---- MICROSOFT AZURE IPs ----
if [ $AZURE_OK -eq 0 ]; then
  echo -e "  ${BLUE}Collecting Microsoft Azure CDN IPs...${NC}"

  AZURE_IPS=()

  AZURE_DOMAINS=(
    "ajax.aspnetcdn.com"
    "az416426.vo.msecnd.net"
    "az784690.vo.msecnd.net"
  )

  for domain in "${AZURE_DOMAINS[@]}"; do
    RESOLVED=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    for ip in $RESOLVED; do
      AZURE_IPS+=("$ip")
    done
  done

  for ip in "${AZURE_IPS[@]}"; do
    ALL_IPS+=("azure|$ip")
  done
  echo "  ✓ Collected ${#AZURE_IPS[@]} Azure IPs"
fi

# Remove duplicates (by IP only)
echo ""
UNIQUE_IPS=($(echo "${ALL_IPS[@]}" | tr ' ' '\n' | sort -t'|' -k2 -u))
echo -e "  ${CYAN}Total unique IPs to test: ${#UNIQUE_IPS[@]}${NC}"

# =============================================
# STEP 3: Test each IP from Iranian nodes
# =============================================

echo ""
echo -e "${YELLOW}[STEP 3] Testing each IP from Iranian nodes...${NC}"
echo -e "  ${YELLOW}(~10 seconds per IP - please be patient)${NC}"
echo ""

test_ip_from_iran() {
  local CDN=$1
  local IP=$2

  RESPONSE=$(curl -s \
    -H "Accept: application/json" \
    "https://check-host.net/check-tcp?host=${IP}:443&node=${IR_NODES}" \
    --max-time 15 2>/dev/null)

  REQUEST_ID=$(echo "$RESPONSE" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get('request_id',''))
except:
  print('')
" 2>/dev/null)

  if [ -z "$REQUEST_ID" ]; then
    echo -e "  ${RED}❌ [$CDN] $IP (API error)${NC}"
    return 1
  fi

  sleep $CHECK_WAIT

  RESULT=$(curl -s \
    -H "Accept: application/json" \
    "https://check-host.net/check-result/$REQUEST_ID" \
    --max-time 15 2>/dev/null)

  STATS=$(echo "$RESULT" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  ok=0
  fail=0
  total_time=0
  for node,result in d.items():
    if 'ir' in node:
      if result and isinstance(result,list) and result[0]:
        r=result[0]
        if isinstance(r,dict) and 'time' in r:
          ok+=1
          total_time+=r['time']
        else:
          fail+=1
      else:
        fail+=1
  avg=round(total_time/ok*1000) if ok>0 else 0
  print(f'{ok},{fail},{avg}')
except:
  print('0,0,0')
" 2>/dev/null)

  OK=$(echo "$STATS" | cut -d',' -f1)
  FAIL=$(echo "$STATS" | cut -d',' -f2)
  AVG=$(echo "$STATS" | cut -d',' -f3)

  if [ "$OK" -gt 0 ] 2>/dev/null; then
    echo -e "  ${GREEN}✅ [$CDN] $IP — $OK/4 Iranian nodes OK — avg ${AVG}ms${NC}"
    return 0
  else
    echo -e "  ${RED}❌ [$CDN] $IP — blocked in Iran${NC}"
    return 1
  fi
}

for ENTRY in "${UNIQUE_IPS[@]}"; do
  CDN=$(echo "$ENTRY" | cut -d'|' -f1)
  IP=$(echo "$ENTRY" | cut -d'|' -f2)

  if test_ip_from_iran "$CDN" "$IP"; then
    WORKING_IPS+=("$IP")
  fi

  sleep $SLEEP_BETWEEN
done

# =============================================
# STEP 4: Output Results
# =============================================

echo ""
echo -e "${CYAN}======================================"
echo " FINAL RESULTS"
echo -e "======================================${NC}"
echo ""
echo -e "${GREEN}✅ Working IPs from Iran: ${#WORKING_IPS[@]}${NC}"
echo ""

if [ ${#WORKING_IPS[@]} -eq 0 ]; then
  echo -e "${RED}No working IPs found. Try running again.${NC}"
  exit 1
fi

CSV=$(IFS=','; echo "${WORKING_IPS[*]}")

echo -e "${CYAN}--------------------------------------"
echo " PASTE INTO ShirOKhorshid:"
echo " Settings → CDN edge IPs"
echo -e "--------------------------------------${NC}"
echo ""
echo "$CSV"
echo ""

# Save to files
echo "$CSV" > cdn_working_ips.txt
echo "Saved to: cdn_working_ips.txt"
echo ""
echo -e "${CYAN}--------------------------------------"
echo " CDN SNI Hostname options:"
echo "   Akamai:  a248.e.akamai.net"
echo "   Google:  www.googleapis.com"
echo "   Amazon:  cloudfront.net"
echo "   Azure:   ajax.aspnetcdn.com"
echo -e "--------------------------------------${NC}"
