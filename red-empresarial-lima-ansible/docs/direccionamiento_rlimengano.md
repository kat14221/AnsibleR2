# Tabla de Direccionamiento – RLIMENGANO

> **Proyecto:** Red Empresarial Lima  
> **Documento:** Direccionamiento de Red – ISP Secundario Simulado  
> **Versión:** 1.0  
> **Fecha:** 2026-06-08

---

## Descripción del Dispositivo

**RLIMENGANO** es una VM Linux que actúa como **ISP secundario simulado** dentro del laboratorio VMware ESXi de la sede Lima.

No es un router empresarial interno. Su función es:
1. Tomar Internet real desde **VM Network** (ens34, DHCP)
2. Aplicar **NAT/PAT**
3. Entregar conectividad a Internet por **ENG-VM NETWORK** (ens35, IP estática)
4. Proveer una segunda WAN simulada para RLIM1 y RLIM2

---

## Interfaces de Red

| Interfaz | Red ESXi       | Función                   | Modo   | IP / Máscara      | Gateway     | MAC                |
|----------|----------------|---------------------------|--------|-------------------|-------------|--------------------|
| `ens34`  | VM Network     | WAN / Internet real ESXi  | DHCP   | Dinámica (≈172.17.25.71/24) | DHCP | `00:0c:29:19:1b:7c` |
| `ens35`  | ENG-VM NETWORK | LAN / ISP secundario      | Estática | `10.250.20.1/24` | **Ninguno** | `00:0c:29:19:1b:86` |

> **NOTA CRÍTICA:** `ens34` **nunca** debe configurarse con IP estática.  
> Es la vía de gestión SSH y la salida a Internet real.

---

## Tabla de Red – ENG-VM NETWORK

| Parámetro         | Valor               |
|-------------------|---------------------|
| Red               | `10.250.20.0/24`    |
| Máscara           | `255.255.255.0`     |
| Gateway (RLIMENGANO) | `10.250.20.1`    |
| Rango libre       | `10.250.20.2 – 10.250.20.10` |
| RLIM1-PRINCIPAL (WAN2) | `10.250.20.11` |
| RLIM2-SECUNDARIO (WAN2) | `10.250.20.12` |
| Rango DHCP (opcional) | `10.250.20.100 – 10.250.20.200` |
| Broadcast         | `10.250.20.255`     |
| DNS para clientes | `8.8.8.8`, `1.1.1.1` |

---

## Flujo de Tráfico NAT

```
┌─────────────────────────────────────────────────────────────┐
│                    VMware ESXi                              │
│                                                             │
│  VM Network (Internet real)                                 │
│       │                                                     │
│       │ DHCP (≈172.17.25.71/24)                            │
│       ▼                                                     │
│   ┌───────────────────────────┐                            │
│   │       RLIMENGANO          │                            │
│   │  ens34 ←──── WAN/DHCP    │                            │
│   │  ens35 ────► 10.250.20.1 │                            │
│   │  NAT Masquerade activo   │                            │
│   └───────────────────────────┘                            │
│                │                                            │
│    ENG-VM NETWORK (10.250.20.0/24)                         │
│       │              │                                      │
│       ▼              ▼                                      │
│  RLIM1-PRINCIPAL  RLIM2-SECUNDARIO                         │
│  10.250.20.11/24  10.250.20.12/24                          │
│  GW: 10.250.20.1  GW: 10.250.20.1                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Red de Gestión SSH

| Parámetro      | Valor               |
|----------------|---------------------|
| Red de gestión | `172.17.25.0/24`    |
| Puerto SSH     | `22/tcp`            |
| Acceso SSH     | Solo desde `172.17.25.0/24` |

---

## Reglas de nftables (Diseño NAT Router Mínimo)

> **Principio de diseño:** RLIMENGANO **no es un firewall de perímetro**.
> Su única función con nftables es habilitar el NAT entre ens35 (LAN) y ens34 (WAN).
> El tráfico destinado al propio RLIMENGANO (SSH, ICMP, DHCP) **no se restringe**.

### Cadena `input` — Política: **ACCEPT**

| Regla  | Descripción                                                              |
|--------|--------------------------------------------------------------------------|
| IN-01  | Paquetes con estado `invalid` → DROP                                     |
| *resto*| Todo lo demás: ACCEPT (SSH, ICMP, DHCP, gestión por ens34, sin restricción) |

> **Razón:** `ens34` entrega la IP DHCP de acceso SSH y es la interfaz de salida a Internet.
> Aplicar política DROP en input podría bloquear el acceso al administrador si la IP DHCP cambia.

### Cadena `forward` — Política: **DROP**

| Regla  | Origen           | Destino          | Protocolo | Acción  | Descripción                          |
|--------|------------------|------------------|-----------|---------|--------------------------------------|
| FWD-01 | cualquier        | cualquier        | INVÁLIDO  | DROP    | Descartar paquetes inválidos         |
| FWD-02 | `ens34` (WAN)    | `ens35` (LAN)    | ESTAB/REL | ACCEPT  | Retorno de respuestas a la LAN       |
| FWD-03 | `ens35` (LAN)    | `ens34` (WAN)    | cualquier | ACCEPT  | RLIM1/RLIM2 pueden salir a Internet  |
| *resto*| cualquier        | cualquier        | NEW       | DROP    | WAN no puede iniciar hacia LAN       |

### Tabla `ip nat` — Postrouting

| Regla  | Origen              | Salida   | Acción      | Descripción                      |
|--------|---------------------|----------|-------------|----------------------------------|
| NAT-01 | `10.250.20.0/24`    | `ens34`  | MASQUERADE  | SNAT dinámico: LAN sale a Internet como IP de ens34 |

---

## Variables Ansible Relacionadas

```yaml
# host_vars/rlimengano.yml
wan_interface: "ens34"
wan_mac: "00:0c:29:19:1b:7c"
lan_interface: "ens35"
lan_mac: "00:0c:29:19:1b:86"
lan_ip: "10.250.20.1"
lan_prefix: 24
lan_network: "10.250.20.0/24"
management_network: "172.17.25.0/24"
nat_enabled: true
enable_dhcp_isp2: false
```
