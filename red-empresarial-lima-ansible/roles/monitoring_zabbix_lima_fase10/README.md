# monitoring_zabbix_lima_fase10

Rol para configurar el servidor `MON-ZABBIX-LIMA` en la VLAN 70 (Monitoreo).
Instala y configura el stack completo de Zabbix 7.0 LTS apoyado por PostgreSQL y Apache.

## Descripción
Configura:
1. El hostname correcto en la máquina (`mon-zabbix-lima`).
2. Configuración de red (IP estática `192.168.70.2/27` vía netplan).
3. Instalación de paquetes base y del repositorio oficial de Zabbix.
4. Instalación de PostgreSQL 16 y creación del rol/base de datos (`zabbix`).
5. Importación idempotente del esquema SQL base.
6. Configuración de `zabbix_server.conf` para la conexión a BD local.
7. Ajustes de timezone para la interfaz web PHP-Apache.
8. Creación de un documento de inventario local inicial en `/etc/zabbix/jhalex_targets_lima.txt`.

## Targets Documentados
- LIM-DC01
- DOC-FILE-BACKUP-LIMA
- SWCORELIM1
- SWCORELIM2
- GW-VLAN70

## Variables principales
- `fase10_zabbix_enabled`: Habilita o deshabilita la ejecución del rol.
- `fase10_ip`: La dirección IP que tomará el servidor en la VLAN 70.
- `fase10_db_password`: Contraseña para el rol PostgreSQL interno de Zabbix.

## Importante
Las contraseñas de base de datos se encuentran en texto plano dentro de los diccionarios de variables. Para uso en producción se recomienda encarecidamente utilizar Ansible Vault para cifrar `fase10_db_password`.
