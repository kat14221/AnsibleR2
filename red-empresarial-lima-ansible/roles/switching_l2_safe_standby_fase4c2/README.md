# Rol: switching_l2_safe_standby_fase4c2

Este rol se encarga de persistir la Fase 4C.2, asegurando que los enlaces redundantes permanezcan desactivados para evitar loops debido a la convergencia inestable de RSTP en ESXi, y provee un script interactivo para failover manual coordinado.

## Tareas principales
- Valida la existencia del bridge OVS.
- Asegura la ausencia de los bonds antiguos en OVS.
- Sube las interfaces listadas en `fase4c2_ports_up`.
- Baja las interfaces listadas en `fase4c2_ports_down`.
- Instala un script de inicialización `/usr/local/sbin/jhalex-fase4c2-safe-topology.sh`.
- Instala el servicio systemd `jhalex-fase4c2-safe-topology.service` para persistencia tras reinicios.
- Instala la herramienta `/usr/local/sbin/jhalex-link-failover` para failover manual controlado.

## Variables
Requiere las variables `fase4c2_*` definidas en el `host_vars` de cada switch.
