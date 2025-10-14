# VAPT-Tool — Vulnerability Assessment & Penetration Testing Toolkit

## Overview
This repository contains a custom VA-PT toolkit built on Kali Linux integrating:
- Nmap, Nikto, Nuclei, Greenbone (GVM), Metasploit, Burp Suite (Community), and other tools.
- A demo automation script: `run_demo.sh <target-ip>` that runs network/web scans and saves outputs to `reports/<target>/`.

## Quickstart (reproduce)
1. Clone repository and enter:
   ```bash
   git clone <your-repo-url> && cd vapt-submission/vapt-tool

2. # if installer finished successfully:
cd ~/vapt-tool
source .venv/bin/activate        # activate the venv

3.# make executable & run
chmod +x ~/install_vapt_tool.sh
bash ~/install_vapt_tool.sh

4.vapt                              # run the tool menu (or demo)

5. select option 1 && after the instalation select option4 :
or ./run_demo.sh <target-ip>

6.
---

##  If something fails — common manual fixes

- If `metasploit-framework` is not found, install with Kali metapackages or manual installer:
  ```bash
  sudo apt update
  sudo apt install metasploit-framework

7.mkdir -p ~/vapt-tool/burp
mv ~/Downloads/burpsuite_community_vX.Y.jar ~/vapt-tool/burp/burpsuite_community.jar
vapt   # then start burp through menu


