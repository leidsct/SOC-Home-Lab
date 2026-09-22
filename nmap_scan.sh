#!/bin/bash
# Nmap Attack Simulation Script for SOC Home Lab

TARGET_IP="10.0.2.3"

echo "Starting Nmap SYN scan against target: $TARGET_IP"
nmap -sS -sV -p 1-1000 "$TARGET_IP"

echo "Scan completed. Check Wazuh dashboard or archives.log for Sysmon event correlation."
