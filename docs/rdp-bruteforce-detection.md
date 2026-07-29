## 🔓 Attack Simulation #2 — RDP Brute Force Detection

### Objective
Simulate a brute force attack against the Windows target's RDP service and verify that Wazuh correctly detects and alerts on repeated failed authentication attempts.

### Attack Setup
- **Attacker:** Kali Linux (10.0.2.15)
- **Target:** demoWIN / Windows 10 (10.0.2.3), RDP port 3389
- **Method:** Manual credential testing via `xfreerdp3`, simulating a brute force attempt with a small password list

    xfreerdp3 /v:10.0.2.3 /u:desca /p:123456 /cert:ignore
    xfreerdp3 /v:10.0.2.3 /u:desca /p:password /cert:ignore
    xfreerdp3 /v:10.0.2.3 /u:desca /p:admin123 /cert:ignore
    xfreerdp3 /v:10.0.2.3 /u:desca /p:qwerty123 /cert:ignore
    xfreerdp3 /v:10.0.2.3 /u:desca /p:letmein123 /cert:ignore

![Clean Dashboard Before Attack](VirtualBox_kali%20linux_BRUTE1.png)

![Attack Execution on Kali](VirtualBox_kali%20linux_BRUTE2.png)

### Detection Results — 

**Before the attack:**
- Total alerts: 2
- Authentication failures: **0**

**After the attack:**
- Total alerts: 133+
- Authentication failures: **5**

![Detected Login Failures](VirtualBox_kali%20linux_3.png)

### Alert Deep-Dive

Wazuh flagged each failed attempt under **Rule ID 60122** ("Logon failure - Unknown user or bad password"):

| Field | Value |
|-------|-------|
| Event ID | 4625 (Windows failed logon) |
| Source IP | 10.0.2.15 (Kali attacker machine) |
| Target Account | desca |
| Logon Type | 3 (Network) |
| Authentication Package | NTLM |
| Fired Times | 5 |
| Rule Level | 5 |

![Expanded Alert Detail 1](VirtualBox_kali%20linux_4.png)

![Expanded Alert Detail 2](VirtualBox_kali%20linux_5.png)

![Expanded Alert Detail 3](VirtualBox_kali%20linux_6.png)

### MITRE ATT&CK Mapping

| Field | Value |
|-------|-------|
| Technique ID | T1078 |
| Technique | Valid Accounts |
| Tactic | Defense Evasion, Persistence, Privilege Escalation, Initial Access, Impact |

> 📌 **Note:** Wazuh correctly correlated repeated authentication failures from a single source IP (10.0.2.15) against a single target account (desca) within a short time window — a textbook brute force pattern.

### Bonus Finding: Windows Account Lockout Policy Triggered

After the failed attempts above, Windows automatically triggered its built-in **Account Lockout Policy** on the target account. A follow-up login attempt using the account's valid password was rejected with:

    ERRCONNECT_ACCOUNT_LOCKED_OUT [0x00020018]

This confirms the account was locked by Windows itself, independent of the SIEM — demonstrating **defense-in-depth**: the target system's native security controls worked alongside Wazuh's detection layer to limit further unauthorized access attempts.

### Key Findings
1. **Source correlation works out of the box** — Wazuh's default Windows Security ruleset was sufficient to flag the failed logons without any custom rule tuning.
2. **Repeated failures (`firedtimes`) is the key signal** — a single failed login is normal user error; 5 failures from the same external IP in seconds is a clear brute force indicator.
3. **MITRE mapping speeds up triage** — the T1078 tag immediately tells an analyst this is a credential-based attack, not malware or exploitation.
4. **Endpoint-level defenses complement SIEM detection** — the account lockout policy added a second layer of protection beyond just alerting.
