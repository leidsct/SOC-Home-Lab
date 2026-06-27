# 🛡️ SOC Home Lab — Wazuh SIEM + Sysmon + Kali Linux

A home Security Operations Center (SOC) lab built using VirtualBox for practicing attack simulation, log collection, and alert detection using Wazuh SIEM.

---

## 📋 Table of Contents
- [Lab Overview](#lab-overview)
- [Environment Setup](#environment-setup)
- [VM Configuration](#vm-configuration)
- [Wazuh SIEM Setup](#wazuh-siem-setup)
- [Sysmon Installation](#sysmon-installation)
- [Wazuh Agent Configuration](#wazuh-agent-configuration)
- [Attack Simulation — Nmap Scan](#attack-simulation--nmap-scan)
- [Detection & Alert Analysis](#detection--alert-analysis)
- [MITRE ATT&CK Mapping](#mitre-attck-mapping)
- [Key Findings](#key-findings)

---

## 🏗️ Lab Overview

This lab simulates a real-world SOC environment with:
- A **Windows 10 target machine** monitored by Sysmon and Wazuh Agent
- A **Kali Linux attacker machine** for offensive simulation
- An **Ubuntu Server** running Wazuh SIEM for centralized log collection and alerting

### Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│              VirtualBox NAT Network              │
│                  soclab (10.0.2.0/24)            │
│                                                  │
│  ┌──────────────┐      ┌──────────────────────┐  │
│  │  Kali Linux  │─────▶│   demoWIN (Target)   │  │
│  │  10.0.2.15   │ scan │   10.0.2.3           │  │
│  │  (Attacker)  │      │   Windows 10         │  │
│  └──────────────┘      │   Sysmon + Agent     │  │
│                        └──────────┬───────────┘  │
│                                   │ logs          │
│                        ┌──────────▼───────────┐  │
│                        │   Ubuntu Server      │  │
│                        │   10.0.2.4           │  │
│                        │   Wazuh SIEM         │  │
│                        └──────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## 🖥️ Environment Setup

### Host Machine
| Spec | Details |
|------|---------|
| Laptop | Asus TUF A15 |
| CPU | AMD Ryzen 7 |
| RAM | 16GB |
| GPU | RTX 3050 |
| Hypervisor | Oracle VirtualBox |

### Virtual Machines
| VM | OS | IP Address | Role |
|----|-----|------------|------|
| demoWIN | Windows 10 Pro | 10.0.2.3 | Target Machine |
| kali | Kali Linux | 10.0.2.15 | Attacker Machine |
| ubuntu-server | Ubuntu Server 22.04 | 10.0.2.4 | Wazuh SIEM Server |

### Network Configuration
- **Type:** NAT Network
- **Network Name:** soclab
- **Subnet:** 10.0.2.0/24

---

## ⚙️ VM Configuration

### Step 1: Create NAT Network in VirtualBox
1. Open VirtualBox → **File → Preferences → Network**
2. Click **"+"** to add new NAT Network
3. Set name: `soclab`
4. Set CIDR: `10.0.2.0/24`
5. Click **OK**

### Step 2: Assign NAT Network to each VM
For each VM (demoWIN, Kali, Ubuntu):
1. Right-click VM → **Settings → Network**
2. Change **Attached to:** `NAT Network`
3. Set **Name:** `soclab`
4. Click **OK**

### Step 3: Set Static IPs

**demoWIN (Windows 10):**
- Open Network Settings → Change adapter options
- Set static IP: `10.0.2.3`
- Subnet: `255.255.255.0`
- Gateway: `10.0.2.1`

**Ubuntu Server:**
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```
```yaml
network:
  ethernets:
    enp0s3:
      addresses: [10.0.2.4/24]
      gateway4: 10.0.2.1
      nameservers:
        addresses: [8.8.8.8]
  version: 2
```
```bash
sudo netplan apply
```

---

## 🔧 Wazuh SIEM Setup

### Install Wazuh on Ubuntu Server (10.0.2.4)

```bash
# Download Wazuh installation script
curl -sO https://packages.wazuh.com/4.7/wazuh-install.sh

# Run the installer
sudo bash wazuh-install.sh -a

# Check Wazuh Manager status
sudo systemctl status wazuh-manager
```

### Access Wazuh Dashboard
- URL: `https://10.0.2.4`
- Default user: `admin`
- Password: (generated during install — save this!)

### Enable Log Archiving
Edit Wazuh manager config:
```bash
sudo nano /var/ossec/etc/ossec.conf
```

Find the `<global>` section and set:
```xml
<global>
  <logall>yes</logall>
  <logall_json>yes</logall_json>
</global>
```

Restart Wazuh manager:
```bash
sudo systemctl restart wazuh-manager
```

---

## 🔍 Sysmon Installation

### Install Sysmon on demoWIN (Windows 10)

1. Download Sysmon from [Microsoft Sysinternals](https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon)
2. Download Sysmon config (SwiftOnSecurity recommended):
```powershell
# Download Sysmon
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Sysmon.zip -OutFile Sysmon.zip
Expand-Archive Sysmon.zip

# Install with default config
cd Sysmon
.\Sysmon64.exe -accepteula -i
```

3. Verify Sysmon is running:
```cmd
sc query sysmon64
```
Expected output: `STATE: 4 RUNNING`

---

## 🤝 Wazuh Agent Configuration

### Install Wazuh Agent on demoWIN

1. Go to Wazuh Dashboard → **Agents → Deploy New Agent**
2. Select:
   - Package: **Windows**
   - Architecture: **x86_64**
   - Wazuh Server IP: `10.0.2.4`
   - Agent Name: `demoWIN`
3. Copy the generated PowerShell command and run it on demoWIN as Administrator

### Configure Agent to Forward Sysmon Logs

Edit ossec.conf on demoWIN:
```
C:\Program Files (x86)\ossec-agent\ossec.conf
```

Add this entry before `</ossec_config>`:
```xml
<!-- Sysmon log collection -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

### Restart Wazuh Agent
```cmd
# Open CMD as Administrator
sc start WazuhSvc

# Verify running
sc query WazuhSvc
```
Expected: `STATE: 4 RUNNING`

### Verify Logs are Arriving (on Ubuntu)
```bash
sudo grep -i "sysmon" /var/ossec/logs/archives/archives.log | tail -20
```
✅ If output appears — Sysmon logs are flowing to Wazuh!

---

## ⚔️ Attack Simulation — Nmap Scan

### Run Nmap from Kali Linux (10.0.2.15)

```bash
# Basic SYN scan with service detection
nmap -sS -sV -p 1-1000 10.0.2.3
```

### Nmap Scan Results
```
PORT    STATE  SERVICE       VERSION
135/tcp open   msrpc         Microsoft Windows RPC
139/tcp open   netbios-ssn   Microsoft Windows netbios-ssn
445/tcp open   microsoft-ds
MAC Address: 08:00:27:44:5F:E6 (Oracle VirtualBox)
OS: Windows; CPE: cpe:/o:microsoft:windows
```

### Monitor Real-time on Ubuntu
```bash
sudo tail -f /var/ossec/logs/archives/archives.log | grep -i "10.0.2.15"
```

---

## 📊 Detection & Alert Analysis

### Finding Alerts in Wazuh Dashboard

1. Go to `https://10.0.2.4` → **Security Events → Events tab**
2. Use Lucene search:
```
agent.name:DESKTOP-F8F343T AND rule.id:92217
```
3. Set time range: **Last 24 hours**

### Alert Details — Rule 92217

| Field | Value |
|-------|-------|
| **Rule ID** | 92217 |
| **Rule Description** | Executable dropped in Windows root folder |
| **Rule Level** | 6 (Medium) |
| **Fired Times** | 149 hits |
| **Agent** | DESKTOP-F8F343T (demoWIN) |
| **Agent IP** | 10.0.2.3 |
| **Log Source** | Microsoft-Windows-Sysmon/Operational |
| **Sysmon Event ID** | 11 (File Created) |
| **Process** | mscorsvw.exe |
| **Target File** | TaskScheduler.dll |
| **User** | NT AUTHORITY\SYSTEM |

---

## 🎯 MITRE ATT&CK Mapping

| Field | Value |
|-------|-------|
| **Technique ID** | T1570 |
| **Tactic** | Lateral Movement |
| **Technique** | Lateral Tool Transfer |

> 📌 Note: While the primary goal was Nmap port scan detection, Wazuh also captured file creation events (Sysmon Event ID 11) triggered during the scan, mapped to MITRE T1570.

---

## 🔑 Key Findings

1. **Sysmon + Wazuh = Powerful Combo** — Sysmon provides detailed Windows telemetry that Wazuh can correlate into actionable alerts.

2. **Log Archiving must be enabled** — By default, `logall` is set to `no` in Wazuh. Setting it to `yes` is required to capture all events including Sysmon logs.

3. **ossec.conf must include Sysmon** — Without the `<localfile>` entry for `Microsoft-Windows-Sysmon/Operational`, no Sysmon events will be forwarded to Wazuh.

4. **SIEM doesn't know the tool name** — Wazuh detects *behavior* (file drops, network connections, process creation), not the tool itself. The SOC analyst correlates evidence to conclude "this was Nmap."

5. **MITRE ATT&CK mapping** — Wazuh automatically tags alerts with relevant MITRE techniques, making it easier to understand the attack context.

---

## 🛠️ Tools Used

| Tool | Purpose |
|------|---------|
| VirtualBox | Hypervisor for hosting VMs |
| Wazuh 4.7.5 | SIEM — log collection, alerting, dashboards |
| Sysmon | Windows telemetry — process, network, file events |
| Kali Linux | Attack simulation platform |
| Nmap | Network port scanner (attack tool) |

---

## 📚 References

- [Wazuh Documentation](https://documentation.wazuh.com)
- [Microsoft Sysmon](https://docs.microsoft.com/en-us/sysinternals/downloads/sysmon)
- [MITRE ATT&CK T1570](https://attack.mitre.org/techniques/T1570/)
- [SwiftOnSecurity Sysmon Config](https://github.com/SwiftOnSecurity/sysmon-config)

---

*Built by Leo | Cybersecurity Student | Aspiring SOC Analyst*
