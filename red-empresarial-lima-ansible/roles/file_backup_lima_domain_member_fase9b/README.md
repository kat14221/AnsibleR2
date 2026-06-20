# file_backup_lima_domain_member_fase9b

Rol para configurar e integrar el servidor `DOC-FILE-BACKUP-LIMA` al dominio Active Directory (`jhalex.local`) como miembro (Member Server) y reemplazar la autenticación Samba standalone por autenticación Winbind.

## Descripción
Configura:
1. Paquetes necesarios para Winbind, Kerberos, Samba y ACL extendidas.
2. Configuración de Kerberos (`/etc/krb5.conf`) apuntando a `LIM-DC01`.
3. Configuración de Samba (`/etc/samba/smb.conf`) con directivas `security = ADS`, backend `rid` para ID mapping y soporte extendido `vfs objects = acl_xattr`.
4. Soporte Winbind en `/etc/nsswitch.conf`.
5. Permisos base L3 (POSIX) sobre las carpetas compartidas inyectando los grupos del Directorio Activo (`JHALEX\GG-JHALEX-ADMIN-EMPRESA`, `JHALEX\GG-JHALEX-CLIENTES-LIMA`).
6. Preparación para que el Administrador ingrese manualmente el comando de Join al Dominio (si es que no está unido).

## Carpetas compartidas y Permisos AD
- **ADMIN**: Lectura/Escritura solo para `GG-JHALEX-ADMIN-EMPRESA`.
- **CLIENTES**: Lectura/Escritura para `GG-JHALEX-CLIENTES-LIMA` y `GG-JHALEX-ADMIN-EMPRESA`.
Samba se ha configurado con `acl_xattr`, permitiendo modificar los permisos finos (ej. prevenir borrado pero permitir edición) directamente desde la pestaña Seguridad de un cliente Windows logueado como administrador del dominio.

## Importante
Dado que unir un servidor al dominio en Kerberos requiere ingresar la contraseña del administrador del dominio en tiempo de ejecución, este rol **asume** que el Join se realizará de forma semiautomática o manual. Si la máquina no está unida al dominio (`net ads testjoin` falla), el rol notificará al operador los comandos exactos a ejecutar.
