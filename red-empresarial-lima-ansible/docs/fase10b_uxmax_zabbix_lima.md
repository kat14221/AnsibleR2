# FASE 10B — Módulo UX Max para Zabbix

Esta fase instala el módulo UX Max en el frontend de Zabbix para mejorar la experiencia visual y funcional del usuario.

## Requisitos Previos

- La Fase 10 (Zabbix Base) debe estar completada y validada.
- El frontend de Zabbix debe ser accesible a través de HTTP (`http://192.168.70.2/zabbix`).
- Debes configurar la variable `fase10b_uxmax_repo_url` en `host_vars/mon-zabbix-lima.yml` con la URL real del repositorio de UX Max antes de ejecutar esta fase.

## Mejoras que incluye UX Max

- **Ventanas modales movibles:** Permite reorganizar las ventanas modales dentro de la interfaz.
- **Resaltado de tags:** Mejora visualmente la representación de etiquetas.
- **Cambio de colores:** Facilita la personalización de la paleta de colores del frontend.
- **Resaltado de código JavaScript:** Mejora la legibilidad de scripts dentro de la interfaz.

## Ejecución de la Fase 10B

1. Configura la URL del repositorio:
   Edita el archivo `host_vars/mon-zabbix-lima.yml` y actualiza:
   ```yaml
   fase10b_uxmax_repo_url: "URL_DEL_REPO_UXMAX_A_CONFIRMAR"
   ```

2. Ejecuta el playbook de instalación:
   ```bash
   sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook -i inventories/local/hosts.yml playbooks/23_instalar_uxmax_zabbix_lima_local.yml -vv
   ```

3. Valida la instalación:
   ```bash
   sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_uxmax_zabbix_lima_local.yml -vv
   ```

## Habilitación Manual en Zabbix

El módulo **debe habilitarse manualmente** desde la interfaz web de Zabbix:

1. Ingresa a Zabbix con un usuario con rol de **Super Admin** (ej. `Admin`).
2. Navega a **Administration -> General -> Modules**.
3. Haz clic en el botón **Scan directory** para que Zabbix detecte el módulo UX Max.
4. Haz clic en **Enable** junto al módulo UX Max.
5. (Opcional) Configura los colores, tags u otras características visuales que proporciona el módulo.
