# Role: asterisk_pbx_lima_fase11a

Este rol instala y configura Asterisk puro (sin FreePBX) para funcionar como PBX IP en la sede Lima de JHALEX.

## Objetivo
Implementar una central telefónica IP para la VLAN 60 Voz IP que permita el registro de softphones y llamadas internas mediante PJSIP.

## Tareas
1. Precheck de red (hostname, IP, Gateway, DNS).
2. Correccion de hostname.
3. Instalacion de Asterisk.
4. Backup de configuracion.
5. Despliegue de plantillas PJSIP, Dialplan y RTP.
6. Ajuste de UFW si se encuentra activo.
7. Reinicio y validacion.

## Variables Principales
Consultar `defaults/main.yml`.
