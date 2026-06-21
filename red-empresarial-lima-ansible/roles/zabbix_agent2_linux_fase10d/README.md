# Fase 10D: Zabbix Agent2 Linux

Este rol configura el agente de Zabbix 2 (Zabbix Agent2) en servidores y clientes Linux (Ubuntu/Debian) para permitir su monitoreo desde MON-ZABBIX-LIMA.

## Tareas principales
- Validar habilitación del agente.
- Instalar paquetes: `zabbix-agent2`, `curl`, `net-tools`.
- Crear configuración `/etc/zabbix/zabbix_agent2.conf` apuntando a `MON-ZABBIX-LIMA`.
- Habilitar e iniciar servicio.
- Permitir puerto TCP 10050 desde `192.168.70.2` en UFW.
