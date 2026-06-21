Write-Host "=== Validacion Local Zabbix Agent 2 Windows ==="
hostname
ipconfig /all
Get-Service "Zabbix Agent 2"
Get-NetFirewallRule -DisplayName "JHALEX Zabbix Agent 10050" -ErrorAction SilentlyContinue
Get-NetTCPConnection -LocalPort 10050 -ErrorAction SilentlyContinue
Get-Content "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf" | Select-String "Server=|ServerActive=|Hostname=|ListenPort="
Test-Connection 192.168.70.2 -Count 3
