# file_backup_lima_fase9

Rol para configurar el servidor `DOC-FILE-BACKUP-LIMA` en la VLAN 80 (Backup/Storage).
Provee servicios básicos de compartición de archivos a través de Samba, con control de acceso por grupos y ACLs de Linux.

## Descripción
Configura:
1. El hostname correcto en la máquina (`doc-file-backup-lima`).
2. Configuración de red (IP estática `192.168.80.2/27` vía netplan).
3. Grupos y usuarios del sistema requeridos para el acceso.
4. Paquetes necesarios para Samba y utilidades de ACL.
5. Permisos de directorio y de sistema de archivos usando `setfacl`.
6. Publicación de SMB/CIFS a la red a través de `smb.conf`.

## Carpetas compartidas
- **ADMIN**: Lectura/Escritura solo para usuarios en `jhalex_admin`.
- **CLIENTES**: Lectura/Escritura para usuarios en `jhalex_clientes` y `jhalex_admin`.

## Variables principales
- `fase9_file_backup_enabled`: Habilita o deshabilita la ejecución del rol.
- `fase9_ip`: La dirección IP que tomará el servidor en la VLAN 80.
- `fase9_samba_admin_password`: Contraseña del usuario SMB de admin.
- `fase9_samba_cliente_password`: Contraseña del usuario SMB de clientes.

## Importante
Las contraseñas de demostración se encuentran en texto plano dentro de los diccionarios de variables. Para uso en producción se recomienda encarecidamente utilizar Ansible Vault para el cifrado de las mismas o un sistema externo de gestión de secretos.
