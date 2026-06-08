# Guía de Validaciones – RLIMENGANO

> **Proyecto:** Red Empresarial Lima  
> **Documento:** Pruebas de validación post-configuración  
> **Versión:** 1.0

---

## Validaciones Automatizadas (desde el Playbook)

Ejecutar el playbook de validación:

```bash
ansible-playbook \
  -i inventories/local/hosts.yml \
  playbooks/99_validar_rlimengano.yml \
  --ask-become-pass
```

Este playbook verifica automáticamente:
- Hostname correcto
- IP de ens35 = `10.250.20.1/24`
- IP de ens34 asignada por DHCP
- Ruta por defecto existe y sale por ens34
- ens35 sin gateway por defecto
- IPv4 Forwarding = 1
- Servicio nftables activo
- NAT masquerade presente en el ruleset
- Ping a 8.8.8.8 exitoso
- HTTP a google.com exitoso

---

## Validaciones Manuales en RLIMENGANO

### 1. Verificar identidad del sistema

```bash
hostname
# Esperado: RLIMENGANO
```

### 2. Verificar interfaces de red

```bash
ip -br addr show
```

Salida esperada:

```
lo                 UNKNOWN   127.0.0.1/8 ::1/128
ens34              UP        172.17.25.71/24          ← IP DHCP (puede variar)
ens35              UP        10.250.20.1/24            ← IP estática fija
```

### 3. Verificar tabla de rutas

```bash
ip route show
```

Salida esperada:

```
default via 172.17.25.X dev ens34 proto dhcp       ← Ruta por defecto: SOLO por ens34
172.17.25.0/24 dev ens34 proto kernel scope link    ← Red WAN
10.250.20.0/24 dev ens35 proto kernel scope link    ← Red LAN (sin gateway)
```

> **CRÍTICO:** NO debe aparecer `default via ... dev ens35`. Si aparece, hay un error de configuración.

### 4. Verificar IPv4 Forwarding

```bash
sysctl net.ipv4.ip_forward
# Esperado: net.ipv4.ip_forward = 1
```

Verificar que es persistente:

```bash
cat /etc/sysctl.d/99-rlimengano-forward.conf
# Debe contener: net.ipv4.ip_forward=1
```

### 5. Verificar nftables

```bash
# Estado del servicio
systemctl status nftables

# Listar todas las reglas
nft list ruleset

# Verificar NAT masquerade
nft list ruleset | grep masquerade
# Esperado: algo como: ip saddr 10.250.20.0/24 oif "ens34" masquerade
```

### 6. Pruebas de conectividad desde RLIMENGANO

```bash
# Ping a DNS de Google
ping -c 4 8.8.8.8

# Ping a DNS de Cloudflare
ping -c 4 1.1.1.1

# Prueba DNS
nslookup google.com 8.8.8.8

# Prueba HTTP/HTTPS
curl -I https://google.com

# Prueba completa
curl -sI https://example.com | head -5
```

### 7. Verificar backups

```bash
ls -la /root/backups/rlimengano/
ls -la /root/backups/rlimengano/netplan/
ls -la /root/backups/rlimengano/nftables/   # si aplica
```

---

## Pruebas Manuales desde RLIM1-PRINCIPAL

**Configuración de RLIM1 en su interfaz WAN2 (ENG-VM NETWORK):**

```
Interfaz: (la que conecta a ENG-VM NETWORK en ESXi)
IP WAN2 : 10.250.20.11/24
Gateway : 10.250.20.1       ← ens35 de RLIMENGANO
DNS     : 8.8.8.8
```

Una vez configurada la interfaz WAN2 en RLIM1, ejecutar:

### Prueba 1: Ping al gateway (RLIMENGANO)

```bash
# Desde RLIM1
ping 10.250.20.1
```

**Resultado esperado:** Respuesta continua desde `10.250.20.1`

```
64 bytes from 10.250.20.1: icmp_seq=1 ttl=64 time=X ms
64 bytes from 10.250.20.1: icmp_seq=2 ttl=64 time=X ms
```

### Prueba 2: Ping al DNS de Google

```bash
# Desde RLIM1 (requiere que NAT esté activo)
ping 8.8.8.8
```

**Resultado esperado:** Respuesta desde `8.8.8.8` (traversa el NAT de RLIMENGANO)

### Prueba 3: Ping a google.com (requiere DNS)

```bash
# Desde RLIM1
ping google.com
```

**Resultado esperado:** Resolución DNS exitosa y respuesta de Google

### Prueba 4: Traceroute para verificar la ruta

```bash
# Desde RLIM1
traceroute 8.8.8.8
```

**Resultado esperado:** El primer salto debe ser `10.250.20.1` (RLIMENGANO)

```
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max
 1  10.250.20.1 (10.250.20.1)   X ms    ← RLIMENGANO (ens35)
 2  172.17.25.X (gateway ESXi)  X ms    ← Gateway ESXi
 3  ...                                  ← Internet
```

---

## Pruebas Manuales desde RLIM2-SECUNDARIO

**Configuración de RLIM2 en su interfaz WAN2 (ENG-VM NETWORK):**

```
Interfaz: (la que conecta a ENG-VM NETWORK en ESXi)
IP WAN2 : 10.250.20.12/24
Gateway : 10.250.20.1       ← ens35 de RLIMENGANO
DNS     : 8.8.8.8
```

Ejecutar las mismas pruebas que RLIM1:

```bash
# Desde RLIM2
ping 10.250.20.1         # Gateway RLIMENGANO
ping 10.250.20.11        # Verificar conectividad entre .11 y .12 (misma LAN)
ping 8.8.8.8             # Internet via NAT
ping google.com          # DNS + Internet
traceroute 8.8.8.8       # Verificar ruta
```

---

## Verificación de NAT desde RLIMENGANO

Para confirmar que el NAT está procesando tráfico de RLIM1/RLIM2:

```bash
# Ver conexiones activas en la tabla NAT
# (mientras RLIM1 o RLIM2 están haciendo ping o navegando)
nft list table ip nat

# Ver estadísticas de paquetes por regla
nft list ruleset -a

# Capturar tráfico en ens34 mientras RLIM1 hace ping
tcpdump -i ens34 icmp -n
# Debes ver paquetes con IP de origen = IP de ens34 (no 10.250.20.x)
# Esto confirma que el masquerade está funcionando
```

---

## Checklist de Aceptación

Marca cada item cuando esté verificado:

| # | Verificación                                       | Estado |
|---|---------------------------------------------------|--------|
| 1 | `hostname` = `RLIMENGANO`                         | ☐      |
| 2 | `ens34` tiene IP DHCP activa                      | ☐      |
| 3 | `ens35` tiene `10.250.20.1/24`                    | ☐      |
| 4 | Ruta por defecto sale por `ens34`                  | ☐      |
| 5 | `ens35` NO tiene gateway por defecto               | ☐      |
| 6 | `sysctl net.ipv4.ip_forward = 1`                  | ☐      |
| 7 | Servicio `nftables` activo                        | ☐      |
| 8 | `nft list ruleset` muestra `masquerade`            | ☐      |
| 9 | `ping -c 4 8.8.8.8` exitoso desde RLIMENGANO     | ☐      |
|10 | `curl -I https://google.com` exitoso              | ☐      |
|11 | `ping 10.250.20.1` exitoso desde RLIM1            | ☐      |
|12 | `ping 8.8.8.8` exitoso desde RLIM1               | ☐      |
|13 | `traceroute 8.8.8.8` primer salto = `10.250.20.1` | ☐      |
|14 | `ping 10.250.20.1` exitoso desde RLIM2            | ☐      |
|15 | `ping 8.8.8.8` exitoso desde RLIM2               | ☐      |
|16 | Backups existen en `/root/backups/rlimengano/`    | ☐      |

---

## Comandos de Diagnóstico Rápido

```bash
# Snapshot completo del estado del sistema
echo "=== HOSTNAME ===" && hostname
echo "=== INTERFACES ===" && ip -br addr
echo "=== RUTAS ===" && ip route
echo "=== FORWARDING ===" && sysctl net.ipv4.ip_forward
echo "=== NFTABLES STATUS ===" && systemctl is-active nftables
echo "=== NFTABLES MASQUERADE ===" && nft list ruleset | grep masquerade
echo "=== PING 8.8.8.8 ===" && ping -c 2 8.8.8.8
```
