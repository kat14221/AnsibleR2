# FASE 11C — Softphone Linux CLIENT-LIMA

## 1. Objetivo de la fase
Configurar CLIENT-LIMA como cliente SIP Linux desatendido usando `baresip` para registrar la extensión 1002 contra PBX-ASTERISK-LIMA, confirmando conectividad SIP y de registro.

## 2. Datos de red de CLIENT-LIMA
- **Hostname**: CLIENT-LIMA
- **IP**: 192.168.20.20
- **Extensión**: 1002

## 3. Motivo de usar baresip en Linux
`baresip` es un cliente SIP por línea de comandos, modular y muy ligero. Es perfecto para automatizar pruebas SIP en entornos de servidor o clientes Linux donde no se requiere o no se dispone de una interfaz gráfica (GUI) ni de hardware de audio físico obligatorio. Permite verificar que el registro SIP y la negociación de red funcionan perfectamente a nivel protocolo.

## 4. Configuración SIP aplicada
Se configuró una cuenta con los siguientes parámetros:
- **Usuario SIP**: 1002
- **Password SIP**: Jhalex1002-2026!
- **Dominio SIP**: 192.168.60.10
- **Transporte**: UDP
- **Puerto SIP**: 5060

El archivo `config` de baresip se adaptó con drivers de audio mínimos (`aufile`) y módulos básicos (`g711`, `stun`, `turn`, `ice`) para asegurar que el motor interno no se detenga por falta de micrófono.

## 5. Servicio systemd creado
Se ha creado el servicio `baresip-1002.service` corriendo bajo un usuario del sistema `baresip`. Esto asegura que el softphone inicie automáticamente con el sistema operativo y se mantenga registrado en segundo plano, ideal para mantener la extensión disponible.

## 6. Comandos de validación
Desde CLIENT-LIMA:
```bash
sudo env ANSIBLE_ROLES_PATH=./roles ansible-playbook \
-i inventories/local/hosts.yml \
playbooks/99_validar_softphone_client_lima_local.yml -vv
```

O manualmente:
```bash
hostname
ip -br addr
ip route
ping -c 3 192.168.60.10
systemctl is-active baresip-1002
systemctl is-enabled baresip-1002
journalctl -u baresip-1002 -n 40 --no-pager
```

## 7. Evidencia esperada en Asterisk
La verdadera confirmación del registro ocurre en la PBX. Desde PBX-ASTERISK-LIMA ejecutar:
```bash
sudo asterisk -rx "pjsip show endpoints"
sudo asterisk -rx "pjsip show contacts"
```

El resultado esperado es:
```text
1002/sip:1002@192.168.20.20:xxxxx Avail
```

## 8. Limitación
Esta implementación establece la configuración técnica mínima estable para mantener el registro SIP activo (señalización). El audio físico (media) no es obligatorio para la validación técnica en este laboratorio.

## 9. Conclusión
El registro SIP 1002 queda validado exitosamente de forma automatizada y persistente.
