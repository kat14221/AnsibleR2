# Diseño de la DMZ y el Servicio Web (Lima y AWS)

## Concepto de DMZ (Zona Desmilitarizada)
Una DMZ (Demilitarized Zone) es una subred física o lógica que aloja los servicios externos (públicos) de una organización y los expone a una red no confiable, usualmente Internet. Actúa como un nodo de seguridad que previene el acceso directo desde el exterior hacia la red interna segura. 

## Rol de la VLAN 50 en JHALEX
En la arquitectura del proyecto JHALEX, la **VLAN 50 (192.168.50.16/28)** es la DMZ oficial de la sede Lima. Esta red está altamente controlada por el firewall (OPNsense) y tiene estrictamente prohibido el inicio de conexiones hacia la LAN interna (VLANs 10, 20, 30, 40, etc.).

## WEB-DMZ-LIMA vs Backup
Es crucial aclarar que la DMZ no se utiliza para copias de seguridad de datos institucionales. La VLAN 80 está dedicada exclusivamente a backups y almacenamiento documental.

La VM **`WEB-DMZ-LIMA`** alojada en la VLAN 50 tiene un propósito específico: actuar como **servidor web de contingencia**.

## Topología de Alta Disponibilidad Web
El servicio web institucional (`www.jhalex.local` o externo) está diseñado de la siguiente manera:
1. **WEB-AWS (Principal)**: Aloja el servicio web en la nube pública de Amazon Web Services, garantizando escalabilidad y alta disponibilidad global.
2. **WEB-DMZ-LIMA (Respaldo)**: Si el servicio AWS sufre una interrupción catastrófica o hay una caída del túnel VPN-AWS, el tráfico puede redirigirse a este servidor local alojado de forma segura en la DMZ de Lima.

Esta separación garantiza que, incluso si el servidor web local llegase a verse comprometido, los atacantes quedarían atrapados en la DMZ y no podrían vulnerar Active Directory (VLAN 40) ni la información de los usuarios (VLAN 20).
