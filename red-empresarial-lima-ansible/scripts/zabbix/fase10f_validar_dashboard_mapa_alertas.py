#!/usr/bin/env python3
import json
import requests
import yaml
import sys
import argparse

def zabbix_rpc(url, auth, method, params):
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1,
    }
    if auth:
        payload["auth"] = auth
    response = requests.post(url, json=payload, headers={'Content-Type': 'application/json-rpc'})
    return response.json().get('result')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()

    with open(args.config, 'r') as f:
        config = yaml.safe_load(f)

    url = config['zabbix_url']
    user = config['zabbix_user']
    password = config['zabbix_password']

    auth = zabbix_rpc(url, None, "user.login", {"username": user, "password": password})
    if not auth:
        print("FAIL: Autenticacion.")
        sys.exit(1)

    print("OK: Autenticacion Zabbix API.")

    # Validate Dashboard
    dash = zabbix_rpc(url, auth, "dashboard.get", {"filter": {"name": [config['dashboard_name']]}})
    if dash:
        print(f"OK: Dashboard '{config['dashboard_name']}' existe.")
    else:
        print(f"FAIL: Dashboard '{config['dashboard_name']}' no encontrado.")

    # Validate Map
    zmap = zabbix_rpc(url, auth, "map.get", {"filter": {"name": [config['map_name']]}})
    if zmap:
        print(f"OK: Mapa '{config['map_name']}' existe.")
    else:
        print(f"FAIL: Mapa '{config['map_name']}' no encontrado.")

    # Validate Groups
    for gname in config['host_groups']:
        grp = zabbix_rpc(url, auth, "hostgroup.get", {"filter": {"name": [gname]}})
        if grp:
            print(f"OK: Grupo '{gname}' existe.")
        else:
            print(f"FAIL: Grupo '{gname}' no encontrado.")

    # Validate Hosts and Tags
    lima_hosts = zabbix_rpc(url, auth, "host.get", {"searchTags": [{"tag": "site", "value": "lima"}], "selectTags": "extend"})
    if lima_hosts:
        print(f"OK: Se encontraron {len(lima_hosts)} hosts con el tag site=lima.")
    else:
        print("FAIL: No se encontraron hosts con el tag site=lima.")

    print("Validacion completada.")

if __name__ == "__main__":
    main()
