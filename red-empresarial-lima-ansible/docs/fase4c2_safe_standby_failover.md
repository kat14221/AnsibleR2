# Fase 4C.2: Persistencia y Failover Controlado

## Objetivo de la Fase
La Fase 4C.2 se encarga de implementar una arquitectura de **Alta Disponibilidad Física Controlada**. Debido a que la implementación de RSTP de Open vSwitch presenta comportamientos inestables en nuestro entorno virtualizado de ESXi (loop leaks), se ha decidido **desactivar los puertos secundarios por software (IP link down)** en lugar de confiar en el bloqueo dinámico de RSTP.

Esto permite:
- Evitar de manera garantizada la propagación de bucles L2 y tormentas de broadcast.
- Mantener los enlaces secundarios físicos presentes e instalados como "Backup pasivo/standby".
- Ofrecer un failover manual controlado en caso de corte o fallo de fibra en el enlace principal.
- Mantener el diseño base intacto para cuando la topología se escale hacia L3 y VRRP (Fase 5) o se implemente un entorno bare-metal con LACP confiable.

## Topología Segura (Enlaces Activos)
Sólo se mantienen activos los caminos principales:
- **SWCORELIM1**: Core1-Core2 (ens36), Core1-Dist1 (ens38). Standby: ens37, ens39.
- **SWCORELIM2**: Core2-Core1 (ens36), Core2-Dist2 (ens41). Standby: ens37, ens40.
- **SWDISTLIM1**: Dist1-Core1 (ens34), Dist1-Acc1 (ens42). Standby: ens37, ens40, ens41, ens43, ens44, ens45.
- **SWDISTLIM2**: Dist2-Core2 (ens36), Dist2-Acc2 (ens42). Standby: ens37, ens38, ens39, ens40, ens41, ens43.
- **SWACCLIM1**: Acc1-Dist1 (ens34). Standby: ens35, ens36, ens37.
- **SWACCLIM2**: Acc2-Dist2 (ens36). Standby: ens34, ens35, ens37.

## Persistencia
Se ha implementado un servicio de Systemd llamado `jhalex-fase4c2-safe-topology.service` que ejecuta al arranque el script `/usr/local/sbin/jhalex-fase4c2-safe-topology.sh`. Este script asegura que, incluso después de un reinicio, las interfaces principales se levanten y las standby se mantengan caídas.

## Script de Failover: `jhalex-link-failover`
Esta herramienta CLI (instalada en `/usr/local/sbin`) permite a los operadores realizar failovers y pruebas de conectividad de manera segura e idempotente.

**Comandos:**
```bash
sudo jhalex-link-failover status                 # Verifica puertos activos, caídos y estado del OVS
sudo jhalex-link-failover list                   # Muestra los enlaces configurados y qué método de test utilizan
sudo jhalex-link-failover test <link_name>       # Verifica la conectividad o el estado del enlace principal
sudo jhalex-link-failover backup <link_name>     # Ejecuta failover "Break-before-Make" bajando el primario y subiendo el secundario
sudo jhalex-link-failover primary <link_name>    # Revierte el failover para usar nuevamente el puerto principal
```

> **ADVERTENCIA CRÍTICA: Enlaces entre Switches (Inter-Switch Links)**
> Todos los enlaces de esta red (Core-Core, Core-Dist, Dist-Acc) son P2P entre dos de nuestros equipos.
> El comando `jhalex-link-failover` se ejecuta **de forma local**.
> Si vas a realizar failover de, por ejemplo, el enlace Core1-Core2, debes ejecutar el script de failover en SWCORELIM1 **Y** SWCORELIM2 de manera coordinada. Si solo lo bajas en uno de los lados, romperás el enlace asimétricamente.

## Procedimiento de Failover (Ejemplo Core1-Core2)

1. En SWCORELIM1, cambiar a backup:
   ```bash
   sudo jhalex-link-failover backup core1_core2
   ```
2. Inmediatamente, en SWCORELIM2, cambiar el peer:
   ```bash
   sudo jhalex-link-failover backup core2_core1
   ```
3. Ejecutar un test en ambos lados para validar:
   ```bash
   sudo jhalex-link-failover test core1_core2
   ```

## Siguientes Pasos
La topología L2 resultante a partir de esta fase se considera libre de bucles, segura y redundante (manual).
El próximo paso arquitectónico es la **Fase 5 (VRRP)**, la cual introducirá redundancia activa-activa en el enrutamiento Capa 3 para las subredes VLAN, explotando estos caminos L2 de forma segura.

## Rollback
Si se desea eliminar la Fase 4C.2:
```bash
sudo systemctl disable jhalex-fase4c2-safe-topology.service
sudo systemctl stop jhalex-fase4c2-safe-topology.service
sudo rm -f /etc/systemd/system/jhalex-fase4c2-safe-topology.service
sudo rm -f /usr/local/sbin/jhalex-fase4c2-safe-topology.sh
sudo rm -f /usr/local/sbin/jhalex-link-failover
sudo systemctl daemon-reload
```
