# FASE 10F - Dashboard, Mapa de Red y Alertas Zabbix Lima

## Objetivo
Crear una capa visual y de operación ejecutiva para la sede JHALEX Lima mediante la API de Zabbix.

## Configuración
Esta fase configura automáticamente:
- **Grupos de Hosts**: Para estructurar monitoreo (CORE, GATEWAYS, SERVIDORES, CLIENTES, MONITOREO).
- **Tags**: Clasificación lógica por rol, VLAN y sitio.
- **Mapa de Red**: Jerarquía lógica visual que parte del Core.
- **Dashboard Ejecutivo**: Vista "JHALEX Lima - Vista Ejecutiva".
- **Alerta Básica**: Acción "JHALEX Lima - Alerta de caida de equipo" notificada al grupo Admin en caso de Average o superior.

## Credenciales seguras API Zabbix
Antes de ejecutar la automatización, debes configurar la contraseña de la API para Zabbix en `MON-ZABBIX-LIMA`:

```bash
sudo mkdir -p /opt/jhalex/zabbix

sudo tee /opt/jhalex/zabbix/fase10f_credentials.yml >/dev/null <<'EOF'
fase10f_zabbix_user: "Admin"
fase10f_zabbix_password: "COLOCAR_PASSWORD_REAL_DEL_PANEL"
EOF

sudo chmod 600 /opt/jhalex/zabbix/fase10f_credentials.yml
sudo chown root:root /opt/jhalex/zabbix/fase10f_credentials.yml
```

## Ejecución
Ejecutar desde `MON-ZABBIX-LIMA`:

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible

sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook \
-i inventories/local/hosts.yml \
playbooks/28_configurar_zabbix_dashboard_mapa_lima_local.yml -vv
```

## Validación
```bash
sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook \
-i inventories/local/hosts.yml \
playbooks/99_validar_zabbix_dashboard_mapa_lima_local.yml -vv
```

## Revisiones Visuales en Zabbix (Frontend)
1. Ir a **Monitorización → Mapas → JHALEX Lima - Mapa de Red**.
2. Ir a **Tableros → JHALEX Lima - Vista Ejecutiva**.
3. Ir a **Recopilación de datos → Equipos** y verificar los tags de la columna "Etiquetas" o filtrar por grupo de hosts.
