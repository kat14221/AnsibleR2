# FASE 9: Servidor de Archivos y Backup Local Lima

Este documento detalla la configuración y arquitectura del servidor `DOC-FILE-BACKUP-LIMA` desplegado en la VLAN 80.

## 1. Objetivo del Servidor
Proveer un repositorio local para documentos compartidos y respaldos a nivel de la sede Lima. Facilita la retención de datos en la red sin depender enteramente de la nube y permite segmentar el acceso por áreas, utilizando un sistema operativo robusto (Ubuntu Server 24.04 LTS) y servicios de compartición SMB/CIFS a través de Samba.

## 2. Por qué se ubica en VLAN 80
La VLAN 80 (Backup/Storage) es un segmento de red diseñado arquitectónicamente para alojar servicios de almacenamiento intensivo. Ubicar este servidor en esta VLAN aísla el tráfico pesado de transferencias de archivos de las VLANs de usuarios (VLAN 20) o administración (VLAN 10), garantizando que los respaldos no degraden el rendimiento general de la red empresarial.

## 3. Uso de IP Fija (192.168.80.2)
El scope DHCP de la VLAN 80 reparte IPs desde `192.168.80.10` en adelante. Para garantizar que los servicios del servidor siempre sean localizables y no dependan de arrendamientos DHCP, se le ha asignado estáticamente la IP `192.168.80.2`, la cual está reservada y fuera del pool dinámico.

## 4. Carpetas compartidas creadas
- **ADMIN** (`/srv/jhalex/ADMIN`): Directorio restringido para la gerencia y administración de sistemas.
- **CLIENTES** (`/srv/jhalex/CLIENTES`): Directorio compartido para el intercambio de documentos generales.

## 5. Usuarios y Grupos Samba
Se implementa un modelo de seguridad basado en roles (RBAC) utilizando grupos locales de Linux y ACLs (`setfacl`).
- **Grupos:** `jhalex_admin`, `jhalex_clientes`
- **Usuarios de prueba:** `admin.lima`, `cliente.lima`
Ambos usuarios carecen de shell interactivo (`/usr/sbin/nologin`) por seguridad, siendo exclusivos para Samba.

El grupo `jhalex_admin` posee permisos de Lectura/Escritura sobre ADMIN y sobre CLIENTES.
El grupo `jhalex_clientes` posee permisos de Lectura/Escritura únicamente sobre CLIENTES.

## 6. Pruebas desde Windows
Para validar el servicio desde `ADMIN-LIMA`, verificar conectividad L3 y resolución DNS:
```cmd
ping 192.168.80.2
nslookup doc-file-backup-lima.jhalex.local
```
Luego acceder al servidor de archivos mediante el explorador de Windows o el menú Ejecutar:
`\\192.168.80.2\ADMIN` o `\\192.168.80.2\CLIENTES`.

## 7. Pruebas desde Linux
En cualquier cliente Linux conectado a la red, utilizar `smbclient` para probar la autenticación:
```bash
smbclient -L //192.168.80.2 -U admin.lima
smbclient //192.168.80.2/CLIENTES -U cliente.lima
```

## 8. Registro DNS opcional
Se puede agregar un registro tipo A estático en el servidor DNS (LIM-DC01) para acceder usando FQDN:
```powershell
Add-DnsServerResourceRecordA -ZoneName "jhalex.local" -Name "doc-file-backup-lima" -IPv4Address "192.168.80.2"
```
A partir de este punto, el acceso SMB funcionará usando `\\doc-file-backup-lima.jhalex.local`.

## 9. Trabajo Futuro
Queda pendiente la integración del servidor Samba al dominio Active Directory (SSSD / Winbind). Por el momento, funciona de manera autónoma (`standalone`) con su propia base de datos de usuarios (passdb backend).
