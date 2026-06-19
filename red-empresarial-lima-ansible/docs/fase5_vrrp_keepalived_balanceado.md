# Fase 5: VRRP / Keepalived Balanceado por VLANs

## Diseño de la Arquitectura L3 (Activo/Activo)
En esta fase, la redundancia de capa 3 se implementa usando el protocolo **VRRP (Virtual Router Redundancy Protocol)** a través de **Keepalived**. Para evitar cuellos de botella y utilizar eficientemente ambos Core Switches (`SWCORELIM1` y `SWCORELIM2`), las VLANs se dividen en dos grupos de balanceo.

### Grupos de Balanceo
Cada Core asume el rol de **MASTER** para un conjunto específico de VLANs en condiciones normales:

| VLAN | Interfaz SVI | VIP (Gateway) | Activo Normal | Peer de Backup |
| ---- | ------------ | ------------- | ------------- | -------------- |
| 10   | svi-vlan10   | 192.168.10.1  | SWCORELIM1    | SWCORELIM2     |
| 20   | svi-vlan20   | 192.168.20.1  | SWCORELIM1    | SWCORELIM2     |
| 30   | svi-vlan30   | 192.168.30.1  | SWCORELIM1    | SWCORELIM2     |
| 40   | svi-vlan40   | 192.168.40.1  | SWCORELIM2    | SWCORELIM1     |
| 50   | svi-vlan50   | 192.168.50.17 | SWCORELIM2    | SWCORELIM1     |
| 60   | svi-vlan60   | 192.168.60.1  | SWCORELIM2    | SWCORELIM1     |
| 70   | svi-vlan70   | 192.168.70.1  | SWCORELIM1    | SWCORELIM2     |
| 80   | svi-vlan80   | 192.168.80.1  | SWCORELIM2    | SWCORELIM1     |
| 99   | svi-vlan99   | 192.168.99.1  | SWCORELIM1    | SWCORELIM2     |

## Consideraciones Técnicas
1. **Unicast VRRP**: En lugar de utilizar multicast estándar (224.0.0.18), se configuró VRRP en modo **unicast** (`unicast_src_ip` y `unicast_peer`) usando las IPs reales de cada SVI. Esto mitiga los problemas de pérdida de multicast y filtrado que son comunes en Open vSwitch bajo VMware ESXi.
2. **Prioridades**: El MASTER designado para un grupo tiene prioridad `150`, y el BACKUP tiene prioridad `100`.
3. **GARP**: Se configuraron retardos y repeticiones de envíos GARP (`garp_master_delay`, `garp_master_repeat`, `garp_master_refresh`) para forzar la actualización de la tabla ARP de las VMs cuando ocurre una transición.
4. **Relación con Fase 4C.2**: Esta fase presupone que la topología física subyacente es **libre de bucles** gracias al "Safe-standby" implementado en la Fase 4C.2. VRRP asume que las SVIs operan sin interrupciones L2 por caídas de enlaces, ya que el failover físico es independiente y controlado manualmente.

## Instrucciones de Instalación
Los playbooks locales configuran todo pero **NO INICIAN** Keepalived para permitir validación humana antes del encendido.

```bash
# 1. Configurar SWCORELIM1
ansible-playbook -i inventories/local/hosts.yml playbooks/09_configurar_vrrp_swcorelim1_local.yml -vv -K

# 2. Configurar SWCORELIM2
ansible-playbook -i inventories/local/hosts.yml playbooks/09_configurar_vrrp_swcorelim2_local.yml -vv -K
```

## Arranque Manual
Una vez ejecutados los playbooks sin errores, arrancar en ambos cores:
```bash
sudo systemctl start keepalived
```

## Validación Exclusiva VRRP
Para verificar el estado, se pueden consultar los logs:
```bash
sudo journalctl -u keepalived -n 120 --no-pager | egrep "VI_VLAN|MASTER|BACKUP|FAULT|priority|Entering"
```

El script de validación se puede correr en ambos lados:
```bash
ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_vrrp_swcorelim1_local.yml -vv -K
```

## Prueba de Failover
Para probar que el failover L3 funciona (independiente de caídas físicas):
1. En SWCORELIM1 ejecutar `sudo systemctl stop keepalived`.
2. En SWCORELIM2 revisar que asumió las IPs de los Grupos A y B con `ip -br addr show`.
3. Retornar `keepalived` en SWCORELIM1 y revisar que asuma de vuelta el Grupo A.

## Rollback
Si se debe revertir por algún motivo grave (y el servicio estaba iniciado):
```bash
sudo systemctl stop keepalived
# Restaurar desde el backup automatizado por el playbook:
sudo cp /etc/keepalived/keepalived.conf.bak_fase5_<timestamp> /etc/keepalived/keepalived.conf
sudo keepalived -t -f /etc/keepalived/keepalived.conf
sudo systemctl start keepalived
```
