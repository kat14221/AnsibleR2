# FASE 11A - Telefonía IP Lima con Asterisk

## Objetivo
Implementar una central telefónica IP empresarial básica en la sede Lima usando Asterisk sobre Ubuntu Server en la VLAN 60 Voz IP, permitiendo llamadas internas entre extensiones SIP simuladas mediante softphones.

## Arquitectura de Telefonía

### Tabla de VM

| Componente | Detalle |
| :--- | :--- |
| **Hostname** | PBX-ASTERISK-LIMA |
| **OS** | Ubuntu Server |
| **VLAN** | 60 (Voz IP) |
| **IP** | 192.168.60.10/25 |
| **Gateway** | 192.168.60.1 |
| **DNS** | 192.168.40.10 |
| **Usuario local** | pbxadmin |
| **Servicio** | Asterisk |

### Justificación de Asterisk
- **PBX open source**: Totalmente libre y sin licenciamiento comercial.
- **Compatible con SIP**: Protocolo estándar soportado por la mayoría de teléfonos y softphones.
- **Bajo consumo**: Ideal para despliegues ligeros y entornos de laboratorio.
- **Automatizable**: Toda la configuración reside en archivos de texto, perfectos para Ansible.
- **Adecuado para laboratorio empresarial**: Permite entender a bajo nivel PJSIP y Dialplans.

### Comparativa: Asterisk puro vs FreePBX vs 3CX
- **Asterisk puro**: Configuración basada en texto, alto control y entendimiento profundo, sin interfaz web, altamente automatizable vía CLI/Ansible.
- **FreePBX**: Interfaz web sobre Asterisk, facilita la gestión, requiere instalar stack LAMP, más difícil de versionar con Ansible.
- **3CX**: Comercial, privativo, fácil de usar, requiere licencia para funcionalidades avanzadas.

## Tabla de Extensiones

| Extensión | Nombre | Descripción | Password |
| :--- | :--- | :--- | :--- |
| **1001** | ADMIN-LIMA | Softphone administrativo Windows | Jhalex1001-2026! |
| **1002** | CLIENT-LIMA | Softphone cliente Linux | Jhalex1002-2026! |
| **1003** | PHONE-LIMA-01 | Telefono IP simulado futuro | Jhalex1003-2026! |
| **600** | Prueba de eco | Test interno | - |

*(Nota: En producción, usar Ansible Vault para los passwords).*

## Tabla de Puertos

| Servicio | Protocolo | Puerto(s) |
| :--- | :--- | :--- |
| **SIP** | UDP | 5060 |
| **RTP** | UDP | 10000 - 20000 |
| **SSH** | TCP | 22 |

## Configuración de Softphone Windows (ADMIN-LIMA)
Para MicroSIP, Zoiper o similar:
- **Server**: 192.168.60.10
- **User**: 1001
- **Password**: Jhalex1001-2026!
- **Transport**: UDP
- **Port**: 5060
- **STUN**: desactivado

## Configuración de Softphone Linux (CLIENT-LIMA)
- **User**: 1002
- **Password**: Jhalex1002-2026!
- **Server**: 192.168.60.10

## Pruebas
1. Registrar 1001.
2. Registrar 1002.
3. Llamar 1001 → 1002.
4. Llamar 1002 → 1001.
5. Llamar 600 para eco.

## Comandos de Validación

```bash
sudo systemctl status asterisk --no-pager
sudo asterisk -rx "core show version"
sudo asterisk -rx "pjsip show endpoints"
sudo asterisk -rx "pjsip show contacts"
sudo asterisk -rx "dialplan show internal"
ss -lunpt | grep 5060
```

## Capturas Requeridas

- [INSERTAR CAPTURA: PBX-ASTERISK-LIMA — ip -br addr mostrando 192.168.60.10/25]
- [INSERTAR CAPTURA: PBX-ASTERISK-LIMA — ip route mostrando default via 192.168.60.1]
- [INSERTAR CAPTURA: Asterisk activo con systemctl status]
- [INSERTAR CAPTURA: pjsip show endpoints con extensiones 1001, 1002 y 1003]
- [INSERTAR CAPTURA: pjsip show contacts con softphones registrados]
- [INSERTAR CAPTURA: llamada 1001 a 1002]
- [INSERTAR CAPTURA: llamada a extensión 600 de eco]

## Estado de Fase
- **Implementada**: Cuando el playbook configura Asterisk sin errores.
- **Validada**: Cuando las extensiones aparecen registradas y al menos un softphone puede llamar y escuchar el eco.
