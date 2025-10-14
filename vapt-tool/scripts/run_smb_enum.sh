#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Accept target as first argument; fallback to default if not provided
TARGET="${1:-192.168.10.45}"
OUTDIR="$HOME/vapt-tool/reports/$TARGET"

mkdir -p "$OUTDIR"
echo "[*] Running SMB-focused enumeration on $TARGET - output -> $OUTDIR"
echo

# 1) Nmap SMB scripts (service detection + smb scripts)
echo "[*] Running nmap SMB scripts..."
nmap -p 135,139,445 \
  --script "smb-os-discovery,smb-enum-shares,smb-enum-users,smb-vuln-ms17-010,smb-vuln-cve2009-3103" \
  -oA "$OUTDIR/nmap_smb" "$TARGET" || echo "[!] nmap returned non-zero status" 

echo

# 2) enum4linux (optional)
if command -v enum4linux >/dev/null 2>&1; then
  echo "[*] Running enum4linux..."
  enum4linux -a "$TARGET" > "$OUTDIR/enum4linux.txt" 2>&1 || true
else
  echo "[!] enum4linux not installed; skipping. See: apt install enum4linux" > "$OUTDIR/enum4linux.txt"
fi
echo

# 3) smbclient - list shares (attempt anonymous)
echo "[*] Attempting anonymous smb share listing (smbclient)..."
smbclient -L "//$TARGET" -N > "$OUTDIR/smbclient_shares_anon.txt" 2>&1 || true
echo

# 4) smbmap (optional)
if command -v smbmap >/dev/null 2>&1; then
  echo "[*] Running smbmap (if available)..."
  smbmap -H "$TARGET" > "$OUTDIR/smbmap.txt" 2>&1 || true
else
  echo "[!] smbmap not installed; skipping." > "$OUTDIR/smbmap.txt"
fi
echo

# 5) rpcclient (best-effort)
echo "[*] Running rpcclient enumdomusers (best-effort; may need credentials)..."
timeout 15s rpcclient -U '' "$TARGET" -c "enumdomusers" > "$OUTDIR/rpcclient_enumdomusers.txt" 2>&1 || echo "[!] rpcclient timed out or failed" > "$OUTDIR/rpcclient_enumdomusers.txt"
echo

# 6) Metasploit ms17_010 scanner (non-exploit check)
if command -v msfconsole >/dev/null 2>&1; then
  echo "[*] Running msfconsole auxiliary scanner for ms17_010 (non-destructive check)..."
  msfconsole -q -x "use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS $TARGET; set THREADS 8; run; exit" | tee "$OUTDIR/msf_smb_ms17_check.txt" || true
else
  echo "[!] msfconsole not installed; skipping." > "$OUTDIR/msf_smb_ms17_check.txt"
fi
echo

# Finished
echo "[*] Enumeration finished. Files saved to: $OUTDIR"
ls -lh "$OUTDIR" || true
echo
echo "Tip: Inspect key outputs with:"
echo "  sed -n '1,120p' \"$OUTDIR/nmap_smb.nmap\""
echo "  sed -n '1,120p' \"$OUTDIR/enum4linux.txt\""
echo "  sed -n '1,120p' \"$OUTDIR/msf_smb_ms17_check.txt\""

