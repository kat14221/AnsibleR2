# Role: zabbix_visual_lima_fase10f

Este rol configura la capa visual de Zabbix para la sede JHALEX Lima mediante la API JSON-RPC de Zabbix.

## Tareas

1. Instala `python3-requests`.
2. Crea directorio de despliegue en `/opt/jhalex/zabbix`.
3. Inyecta el script de Python para configuración de la API y el archivo YAML de configuración generado dinámicamente con las variables del rol.
4. Ejecuta el script.

El script crea y configura:
- Grupos de Hosts
- Tags
- Dashboard Ejecutivo
- Mapa de Red
- Acciones Visuales
