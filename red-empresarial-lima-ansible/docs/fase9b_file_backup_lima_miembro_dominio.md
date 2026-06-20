# FASE 9B: Integración DOC-FILE-BACKUP-LIMA al Dominio AD

Este documento detalla el procedimiento y arquitectura técnica utilizada para integrar el servidor `DOC-FILE-BACKUP-LIMA` al Directorio Activo (`jhalex.local`).

## 1. Standalone vs AD Member
En la Fase 9, Samba funcionaba de forma *standalone* (autónoma). La autenticación se realizaba utilizando una base de datos local `passdb` exclusiva del servidor, lo que requería administrar usuarios como `admin.lima` y `cliente.lima` localmente mediante `smbpasswd`.
Al cambiar a *AD Member* (Fase 9B), Samba delega la autenticación directamente a los Domain Controllers (`LIM-DC01`) usando Kerberos (`krb5`) y Winbind. Esto centraliza la gestión de accesos y aplica las políticas de grupo corporativas.

## 2. Por qué la Fase 9 usaba usuarios locales
Fue una etapa transitoria para asegurar que el servidor, las carpetas y los ACL de Linux funcionaban correctamente en el segmento VLAN 80 sin introducir variables complejas del Directorio Activo de forma prematura.

## 3. Uso de Grupos y Usuarios de AD
A través de `security = ADS` en `smb.conf` e `idmap backend = rid`, Samba y el sistema Linux pueden reconocer de forma transparente (vía NSS) a los usuarios y grupos de AD.
- `GG-JHALEX-ADMIN-EMPRESA`: Grupo de administradores.
- `GG-JHALEX-CLIENTES-LIMA`: Grupo de usuarios estándar.
De este modo, se administran los permisos aplicando chown y ACL sobre carpetas Linux mapeando directamente los grupos del dominio.

## 4. Permisos de ADMIN
El recurso compartido `[ADMIN]` restringe todo su acceso (lectura/escritura) al grupo AD `GG-JHALEX-ADMIN-EMPRESA`. Cualquier usuario ajeno al grupo será rechazado de inmediato.

## 5. Permisos de CLIENTES
El recurso `[CLIENTES]` permite el acceso tanto a los usuarios comunes del dominio en la sede (grupo `GG-JHALEX-CLIENTES-LIMA`) como al personal de soporte (`GG-JHALEX-ADMIN-EMPRESA`). Para garantizar que los administradores mantengan control absoluto, se inyectan reglas ACL granulares y predeterminadas con `setfacl`.
Además, Samba expone el atributo `acl_xattr` hacia la red. Esto permite a un administrador mapeado gestionar permisos finos NTFS (ej. prohibir eliminar pero permitir editar) desde la interfaz de Seguridad en un cliente Windows.

## 6. Restricción de Cliente No Administrador
Para asegurar que los usuarios cliente no comprometan el entorno (ej. instalando software sin autorización), el usuario `JHALEX\cliente.lima` debe ser estrictamente un "Domain User" sin privilegios elevados. **No debe** formar parte del grupo local "Administrators" en su estación de trabajo Windows (ej. la VM `ADMIN-LIMA`).

## 7. UAC (User Account Control)
Windows mantiene activo el UAC. Debido a las restricciones descritas en el punto 6, cuando el cliente intente realizar un cambio administrativo, UAC requerirá obligatoriamente las credenciales de un administrador (ej. `JHALEX\admin.lima`).

## 8. Trabajo Futuro
El despliegue local de la solución de File/Backup Member Server funciona como prototipo escalable para replicar la estructura a otras sedes (ej. Huancayo) y finalmente a componentes híbridos o alojados en la nube pública (AWS).
