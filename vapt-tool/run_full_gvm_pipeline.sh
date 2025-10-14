#!/usr/bin/env bash
set -euo pipefail
PROJECT="$HOME/vapt-tool"
if [ -z "${1-}" ]; then echo "Usage: $0 <target-ip>"; exit 1; fi
TARGET="$1"
read -rp "GVM admin username (usually 'admin'): " GMP_USER
read -rsp "GVM admin password: " GMP_PASS
echo
mkdir -p "$PROJECT/reports/$TARGET"
# create target
CREATE_XML="<create_target><name>lab-$TARGET</name><hosts>$TARGET</hosts></create_target>"
CREATED=$(echo "$CREATE_XML" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
TARGET_ID=$(echo "$CREATED" | xmllint --xpath 'string(//create_target_response/@id)' - 2>/dev/null || true)
if [ -z "$TARGET_ID" ]; then echo "Failed to create target. Output:"; echo "$CREATED"; exit 2; fi
# get config id 'Full and fast'
CONFIGS=$(echo '<get_configs/>' | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
CONF_ID=$(echo "$CONFIGS" | xmllint --xpath "string(//config[name='Full and fast']/@id)" - 2>/dev/null || true)
if [ -z "$CONF_ID" ]; then CONF_ID=$(echo "$CONFIGS" | xmllint --xpath "string(//config[1]/@id)" -); fi
# create task
CTASK="<create_task><name>auto-scan-$TARGET</name><config id=\"$CONF_ID\"/><target id=\"$TARGET_ID\"/></create_task>"
CREATED_TASK=$(echo "$CTASK" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
TASK_ID=$(echo "$CREATED_TASK" | xmllint --xpath 'string(//create_task_response/@id)' - 2>/dev/null || true)
if [ -z "$TASK_ID" ]; then echo "Failed to create task"; echo "$CREATED_TASK"; exit 3; fi
# start
echo "<start_task task_id=\"$TASK_ID\"/>" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -
# poll
while true; do
  STATUS_XML=$(echo "<get_tasks task_id=\"$TASK_ID\"/>" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
  STATUS=$(echo "$STATUS_XML" | xmllint --xpath "string(//task/status/text())" - 2>/dev/null || true)
  echo "Status: $STATUS"
  if [[ "$STATUS" =~ Done|Complete|Stopped ]]; then break; fi
  sleep 20
done
# export latest report (PDF)
REPORT_XML=$(echo "<get_reports task_id=\"$TASK_ID\" details=\"1\"/>" | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --xml -)
REPORT_ID=$(echo "$REPORT_XML" | xmllint --xpath "string(//report/@id)" - 2>/dev/null || true)
if [ -n "$REPORT_ID" ]; then
  echo "<get_report report_id=\"$REPORT_ID\" format_id=\"c402cc3e-b531-11e1-9163-406186ea4fc5\"/>" \
    | gvm-cli socket --gmp-username "$GMP_USER" --gmp-password "$GMP_PASS" --raw - > "$PROJECT/reports/$TARGET/gvm_report.pdf"
  echo "Saved: $PROJECT/reports/$TARGET/gvm_report.pdf"
else
  echo "No report id found"
fi
