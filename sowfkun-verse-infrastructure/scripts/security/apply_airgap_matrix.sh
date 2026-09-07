#!/bin/bash
# ==============================================================================
# Script: apply_airgap_matrix.sh
# Purpose: Enforce True One-Way Air-Gapped DMZ across the 4-server cluster
# Compatible: Ubuntu / Debian / Linux with iptables
# ==============================================================================

set -e

ROLE=$1
IP_NETCUP_MONGO="${2:-100.70.62.111}"
IP_S1_CACHE_MQ="${3:-100.98.199.44}"
IP_S2_CORE_APP="${4:-100.115.97.125}"
IP_S3_GATEWAY="${5:-100.82.253.55}"

echo "================================================================"
echo "🛡️  Configuring One-Way Air-Gapped DMZ for Node: [$ROLE]"
echo "================================================================"

# 1. Reset / Create custom chains
iptables -F AIRGAP-INPUT 2>/dev/null || true
iptables -F AIRGAP-OUTPUT 2>/dev/null || true
iptables -X AIRGAP-INPUT 2>/dev/null || true
iptables -X AIRGAP-OUTPUT 2>/dev/null || true

iptables -N AIRGAP-INPUT
iptables -N AIRGAP-OUTPUT

# Ensure AIRGAP chains are at the very top of INPUT and OUTPUT
iptables -D INPUT -j AIRGAP-INPUT 2>/dev/null || true
iptables -I INPUT 1 -j AIRGAP-INPUT

iptables -D OUTPUT -j AIRGAP-OUTPUT 2>/dev/null || true
iptables -I OUTPUT 1 -j AIRGAP-OUTPUT

case "$ROLE" in
    gateway)
        echo "🔒 Applying Egress Gateway Security Profile..."
        # Server 3 (Egress Gateway) cannot initiate NEW connections to internal nodes
        iptables -A AIRGAP-OUTPUT -d "$IP_NETCUP_MONGO" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-OUTPUT -d "$IP_S1_CACHE_MQ" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-OUTPUT -d "$IP_S2_CORE_APP" -m conntrack --ctstate NEW -j DROP
        
        # Block GCP Metadata & MagicDNS access
        iptables -A AIRGAP-OUTPUT -d 169.254.169.254 -j DROP
        iptables -A AIRGAP-OUTPUT -d 100.100.100.200 -j DROP
        ;;

    app)
        echo "🔒 Applying Core App Server Security Profile..."
        # Server 2 (Core App) drops incoming NEW connections from peer nodes
        iptables -A AIRGAP-INPUT -s "$IP_NETCUP_MONGO" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-INPUT -s "$IP_S1_CACHE_MQ" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-INPUT -s "$IP_S3_GATEWAY" -m conntrack --ctstate NEW -j DROP
        ;;

    mongo)
        echo "🔒 Applying Mongo Node Security Profile..."
        # Mongo drops incoming NEW connections from Gateway and Cache/MQ
        iptables -A AIRGAP-INPUT -s "$IP_S3_GATEWAY" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-INPUT -s "$IP_S1_CACHE_MQ" -m conntrack --ctstate NEW -j DROP
        
        # Mongo cannot initiate NEW connections to App or Cache/MQ (only Gateway :8090 for alert)
        iptables -A AIRGAP-OUTPUT -d "$IP_S2_CORE_APP" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-OUTPUT -d "$IP_S1_CACHE_MQ" -m conntrack --ctstate NEW -j DROP
        ;;

    cache_mq)
        echo "🔒 Applying Cache & MQ Server Security Profile..."
        # Cache/MQ drops incoming NEW connections from Gateway and Mongo
        iptables -A AIRGAP-INPUT -s "$IP_S3_GATEWAY" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-INPUT -s "$IP_NETCUP_MONGO" -m conntrack --ctstate NEW -j DROP
        
        # Cache/MQ cannot initiate NEW connections to App or Mongo (only Gateway :8090 for alert)
        iptables -A AIRGAP-OUTPUT -d "$IP_S2_CORE_APP" -m conntrack --ctstate NEW -j DROP
        iptables -A AIRGAP-OUTPUT -d "$IP_NETCUP_MONGO" -m conntrack --ctstate NEW -j DROP
        ;;

    *)
        echo "❌ Unknown role: $ROLE"
        exit 1
        ;;
esac

echo "✅ AIRGAP Rules applied successfully for [$ROLE]!"

# 2. Persist rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# If netfilter-persistent is installed, save there too
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save || true
fi

echo "💾 Firewall rules persisted to /etc/iptables/rules.v4"
