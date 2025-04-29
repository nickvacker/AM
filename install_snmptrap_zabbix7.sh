#!/bin/bash

# Zabbix 7.0 - SNMP trap support installer for Ubuntu
# Author: Nick Vacker (AM repo)
# Date: 2025-04
# Purpose: Sets up snmptrapd logging to a file readable by Zabbix

set -e

echo "📦 Installing SNMP packages..."
sudo apt update -y
sudo apt install -y snmp snmptrapd libsnmp-perl

echo "🛠 Configuring /etc/snmp/snmptrapd.conf ..."
sudo tee /etc/snmp/snmptrapd.conf >/dev/null <<EOF
disableAuthorization yes
authCommunity log,execute,net public
EOF

echo "📁 Creating trap log file ..."
sudo touch /var/log/snmptrapd.log
sudo chown zabbix:zabbix /var/log/snmptrapd.log
sudo chmod 644 /var/log/snmptrapd.log

echo "⚙️ Setting Zabbix SNMPTrapperFile path ..."
if ! grep -q "^SNMPTrapperFile=" /etc/zabbix/zabbix_server.conf; then
  echo "SNMPTrapperFile=/var/log/snmptrapd.log" | sudo tee -a /etc/zabbix/zabbix_server.conf
else
  sudo sed -i 's|^SNMPTrapperFile=.*|SNMPTrapperFile=/var/log/snmptrapd.log|' /etc/zabbix/zabbix_server.conf
fi

echo "🔄 Restarting Zabbix server ..."
sudo systemctl restart zabbix-server

echo "🚀 Starting snmptrapd in background (manual method)..."
sudo pkill snmptrapd || true
nohup sudo /usr/sbin/snmptrapd -f -On -Lf /var/log/snmptrapd.log -c /etc/snmp/snmptrapd.conf >/dev/null 2>&1 &

echo "🕒 Ensuring snmptrapd starts at boot (via crontab)..."
if ! crontab -l | grep -q snmptrapd; then
  (crontab -l 2>/dev/null; echo "@reboot /usr/sbin/snmptrapd -f -On -Lf /var/log/snmptrapd.log -c /etc/snmp/snmptrapd.conf &") | crontab -
fi

echo "✅ SNMP trap support for Zabbix 7.0 is installed and running."
echo "📎 You can test with: ./send-test-trap.sh"
