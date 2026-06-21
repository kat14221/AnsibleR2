# FASE 10D: Zabbix Agent2 Linux

Automatización de la instalación y configuración del agente Zabbix 2 en los servidores y clientes Linux de la sede Lima.

## 1. Servidores objetivo

| Equipo | IP |
| :--- | :--- |
| `DOC-FILE-BACKUP-LIMA` | 192.168.80.2 |
| `CLIENT-LIMA` | 192.168.20.20 |

## 2. Ejecutar en DOC-FILE-BACKUP-LIMA

Ejecutar desde la terminal del servidor con tu usuario local (no con el usuario de dominio si no tiene sudo):

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
git pull --rebase origin main
sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook -i inventories/local/hosts.yml playbooks/24_configurar_zabbix_agent2_doc_file_lima_local.yml -vv
sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_zabbix_agent2_linux_local.yml -vv
```

## 3. Ejecutar en CLIENT-LIMA

Ejecutar en la terminal de la máquina cliente **con usuario local sudo** (por ejemplo, el usuario con el que instalaste Linux Mint), NO con el usuario `client.lima@jhalex.local`:

```bash
cd ~/AnsibleR2/red-empresarial-lima-ansible
git pull --rebase origin main
sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook -i inventories/local/hosts.yml playbooks/25_configurar_zabbix_agent2_client_lima_local.yml -vv
sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook -i inventories/local/hosts.yml playbooks/99_validar_zabbix_agent2_linux_local.yml -vv
```

## 4. Validación desde MON-ZABBIX-LIMA

Una vez instalados los agentes, comprobar desde el servidor Zabbix (`192.168.70.2`) que tiene llegada al puerto `10050` de los agentes:

```bash
nc -vz 192.168.80.2 10050
nc -vz 192.168.20.20 10050
```

## 5. Configuración en la Zabbix UI

1. Ingresar a la interfaz web de Zabbix: `http://192.168.70.2/zabbix`
2. Ir a **Data collection -> Hosts**.
3. Entrar a la configuración de `DOC-FILE-BACKUP-LIMA`.
   - **Templates:** Agregar plantilla `Linux by Zabbix agent`.
   - **Interfaces:** Agregar interfaz tipo Agent apuntando a IP `192.168.80.2` por el puerto `10050`.
   - Guardar.
4. Entrar a la configuración de `CLIENT-LIMA`.
   - **Templates:** Agregar plantilla `Linux by Zabbix agent`.
   - **Interfaces:** Agregar interfaz tipo Agent apuntando a IP `192.168.20.20` por el puerto `10050`.
   - Guardar.
5. Esperar unos minutos y verificar que el icono `ZBX` se ponga en color verde (Available) en la lista de hosts.
