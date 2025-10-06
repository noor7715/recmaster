#!/bin/bash
#
# recmaster - Terminal Reconnaissance Master
# Author: Your Name
# Version: 1.0
# GitHub: https://github.com/yourusername/recmaster
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════╗"
echo "║           Terminal App Recon Tool           ║"
echo "║              Live Results Only              ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Get target URL from user
read -p "Enter the target URL (e.g., https://app.example.com): " target_url

# Validate URL format
if [[ ! $target_url =~ ^https?:// ]]; then
    echo -e "${RED}[!] Error: URL must start with http:// or https://${NC}"
    exit 1
fi

# Extract domain
domain=$(echo $target_url | awk -F/ '{print $3}')
base_domain=$(echo $domain | awk -F. '{print $(NF-1)"."$NF}')

echo -e "${GREEN}[+] Target: $target_url${NC}"
echo -e "${GREEN}[+] Domain: $domain${NC}"
echo -e "${GREEN}[+] Base Domain: $base_domain${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
}

# Function to run and display command
run_and_show() {
    local description=$1
    local command=$2
    
    echo -e "\n${YELLOW}▶ $description${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
    eval $command
    echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
}

# Start reconnaissance
echo -e "${PURPLE}🚀 Starting Live Reconnaissance...${NC}"

## 1. BASIC CHECKS
print_section "📋 BASIC CHECKS"

# DNS information
run_and_show "DNS Resolution" "host $domain"

# HTTP headers
run_and_show "HTTP Headers" "curl -I -s -L $target_url"

# Server response
run_and_show "Server Response" "curl -s -L -i $target_url | head -20"

## 2. TECHNOLOGY IDENTIFICATION
print_section "🔍 TECHNOLOGY IDENTIFICATION"

# WhatWeb
if command -v whatweb &> /dev/null; then
    run_and_show "Technology Stack" "whatweb $target_url"
else
    echo -e "${YELLOW}[-] WhatWeb not installed, using alternative methods${NC}"
    run_and_show "Technology Indicators" "curl -s $target_url | grep -i 'powered-by\\|framework\\|version\\|react\\|vue\\|angular' | head -10"
fi

## 3. SSL/TLS ANALYSIS
print_section "🔒 SSL/TLS ANALYSIS"

# SSL certificate info
run_and_show "SSL Certificate" "openssl s_client -connect $domain:443 < /dev/null 2>/dev/null | openssl x509 -subject -dates -issuer -noout"

## 4. SUBDOMAIN DISCOVERY
print_section "🌐 SUBDOMAIN DISCOVERY"

# Certificate Transparency
run_and_show "Subdomains from Certificate Transparency" "curl -s 'https://crt.sh/?q=%.$base_domain&output=json' 2>/dev/null | jq -r '.[].name_value' | sed 's/\\*\\.//g' | sort -u | head -20"

# Quick subdomain check with subfinder
if command -v subfinder &> /dev/null; then
    run_and_show "Subdomains (Subfinder)" "subfinder -d $base_domain -silent | head -20"
else
    echo -e "${YELLOW}[-] Subfinder not installed${NC}"
fi

## 5. WEB CONTENT DISCOVERY
print_section "📁 WEB CONTENT DISCOVERY"

# Robots.txt
run_and_show "Robots.txt" "curl -s $target_url/robots.txt"

# Common files check
echo -e "\n${YELLOW}▶ Common Files Check${NC}"
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
for file in .env .git/config backup.zip README.md; do
    response=$(curl -s -o /dev/null -w "%{http_code}" $target_url/$file)
    if [ "$response" != "404" ] && [ "$response" != "000" ]; then
        echo -e "${GREEN}[FOUND] $target_url/$file (HTTP: $response)${NC}"
    else
        echo -e "[MISSING] $target_url/$file"
    fi
done
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"

## 6. PORT SCANNING
print_section "🔎 PORT SCANNING"

# Quick port scan
run_and_show "Quick Port Scan (Top 20 ports)" "nmap --top-ports 20 $domain | grep -E 'open|filtered'"

# Web-specific ports
run_and_show "Web Ports Scan" "nmap -p 80,443,8080,8443,3000,5000 $domain | grep -E 'open|closed'"

## 7. API DISCOVERY
print_section "🔧 API ENDPOINT DISCOVERY"

echo -e "\n${YELLOW}▶ Common API Endpoints${NC}"
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
for endpoint in api graphql v1 rest api/v1 graphql/api admin dashboard; do
    response=$(curl -s -o /dev/null -w "%{http_code}" $target_url/$endpoint)
    case $response in
        200) echo -e "${GREEN}[LIVE] $target_url/$endpoint (200)${NC}" ;;
        301|302) echo -e "${YELLOW}[REDIRECT] $target_url/$endpoint ($response)${NC}" ;;
        403) echo -e "${RED}[FORBIDDEN] $target_url/$endpoint (403)${NC}" ;;
        404) echo -e "[MISSING] $target_url/$endpoint" ;;
        *) echo -e "[UNKNOWN] $target_url/$endpoint ($response)" ;;
    esac
done
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"

## 8. SECURITY HEADERS CHECK
print_section "🛡️ SECURITY HEADERS"

run_and_show "Security Headers" "curl -s -I $target_url | grep -E 'Content-Security-Policy|X-Frame-Options|X-Content-Type-Options|Strict-Transport-Security|X-XSS-Protection'"

## 9. QUICK DIRECTORY CHECK (Optional)
print_section "📂 QUICK DIRECTORY CHECK"

read -p "Run quick directory scan? (y/N): " run_dir_scan

if [[ $run_dir_scan =~ ^[Yy]$ ]]; then
    if command -v gobuster &> /dev/null; then
        echo -e "\n${YELLOW}▶ Quick Directory Bruteforce (Top 50)${NC}"
        echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
        gobuster dir -u $target_url -w /usr/share/seclists/Discovery/Web-Content/common.txt -q -t 10 | head -20
        echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
    else
        echo -e "${YELLOW}[-] Gobuster not installed${NC}"
    fi
else
    echo -e "${YELLOW}[-] Skipped directory scan${NC}"
fi

## 10. SUMMARY
print_section "📊 QUICK SUMMARY"

echo -e "${GREEN}✓ DNS Resolution${NC}"
echo -e "${GREEN}✓ HTTP Headers & Technology${NC}"
echo -e "${GREEN}✓ SSL Certificate${NC}"
echo -e "${GREEN}✓ Subdomain Discovery${NC}"
echo -e "${GREEN}✓ Common Files Check${NC}"
echo -e "${GREEN}✓ Port Scanning${NC}"
echo -e "${GREEN}✓ API Endpoint Discovery${NC}"
echo -e "${GREEN}✓ Security Headers${NC}"

if [[ $run_dir_scan =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ Directory Scan${NC}"
fi

echo -e "\n${PURPLE}🎯 Reconnaissance Targets:${NC}"
echo -e "• Subdomains from crt.sh"
echo -e "• Open ports and services"
echo -e "• Technology stack"
echo -e "• API endpoints"
echo -e "• Common files exposure"
echo -e "• Security headers"

echo -e "\n${CYAN}💡 Tips:${NC}"
echo -e "• Use browser DevTools for deeper analysis"
echo -e "• Check for JavaScript files for API endpoints"
echo -e "• Look for documentation endpoints"
echo -e "• Verify all found subdomains"

echo -e "\n${GREEN}✅ LIVE RECONNAISSANCE COMPLETED!${NC}"
echo -e "${YELLOW}📋 All results shown above in terminal${NC}"