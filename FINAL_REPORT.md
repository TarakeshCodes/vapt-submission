# FINAL_REPORT — VAPT-Tool (Lab target: 192.168.10.45)

**Author:** Tarakesh  
**Date:** 2025-10-14  
**Target (lab):** `192.168.10.45`  
**Tooling used:** nmap, enum4linux, smbclient, smbmap, rpcclient, nikto, nuclei, Metasploit, Greenbone (GVM)  
**Reports / Evidence:** `~/vapt-tool/reports/192.168.10.45/` (see Evidence section)

---

## 1 — Executive Summary

A focused VAPT was run against a lab host `192.168.10.45` to discover network services, enumerate SMB/CIFS information, and check for known Windows SMB vulnerabilities. The scan identified open Microsoft RPC/SMB services (ports 135, 139, 445) and harvested service enumeration information. An unauthenticated Metasploit auxiliary check for MS17-010 did not successfully exploit the host (authentication error), but the presence of SMB services indicates an attack surface that merits patching and hardening. Full automated scans and resulting files are attached as evidence. See Findings and Remediation for prioritized actions.

---

## 2 — Scope

- Single internal host: `192.168.10.45`
- Network-level and SMB-focused enumeration, plus web scans where applicable.
- No destructive exploitation performed; Metasploit was used in **non-exploit** scanning mode only.

---

## 3 — Methodology (commands / automation)

The following automated/demo commands were used (examples — run in `~/vapt-tool` venv):

- Quick port/service discovery (nmap) && Commnads
```bash
nmap -sS -sV -T4 -oA reports/192.168.10.45/nmap_quick 192.168.10.45
nmap -p 135,139,445 --script "smb-os-discovery,smb-enum-shares,smb-enum-users,smb-vuln-ms17-010" -oA reports/192.168.10.45/nmap_smb 192.168.10.45
enum4linux -a 192.168.10.45 > reports/192.168.10.45/enum4linux.txt
smbclient -L //192.168.10.45 -N > reports/192.168.10.45/smbclient_shares_anon.txt
smbmap -H 192.168.10.45 > reports/192.168.10.45/smbmap.txt
rpcclient -U '' 192.168.10.45 -c "enumdomusers" > reports/192.168.10.45/rpcclient_enumdomusers.txt
msfconsole -q -x "use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS 192.168.10.45; set THREADS 10; run; exit" | tee reports/192.168.10.45/msf_smb_ms17_check.txt

