# Role: core_vrrp_keepalived_fase5

Este rol es el encargado de implementar la **FASE 5** de alta disponibilidad en los Core Switches de la red JHALEX, desplegando Keepalived para VRRP balanceado por grupos de VLANs.

## Descripción

El rol instala, configura y valida la sintaxis de Keepalived en un modelo Activo/Activo (balanceado), donde:
- **SWCORELIM1** es MASTER para el Grupo A (VLANs 10, 20, 30, 70, 99).
- **SWCORELIM2** es MASTER para el Grupo B (VLANs 40, 50, 60, 80).

## Funciones
- Realiza prechecks estrictos para asegurar que no hay IPs virtuales configuradas localmente previas a su inicio.
- Valida que la Fase 4C.2 (Safe-standby) esté habilitada.
- Verifica conectividad ICMP Unicast SVI-a-SVI entre peers.
- No inicia ni habilita el servicio de forma automática (esto debe hacerse manualmente o posterior a la validación).

## Variables
Las instancias VRRP se configuran en `host_vars/<host>.yml` bajo la variable principal `fase5_vrrp_instances`.
