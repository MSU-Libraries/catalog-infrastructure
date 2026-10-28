#!/usr/bin/env python3

import sys
import ipaddress

def parse_line(line: str) -> str:
    return line.split('#')[0].strip()

def filter_ips(ip_file: str, exclude_file: str) -> None:
    exact_ips = set()
    cidr_networks = []

    # Parse exclusion list: IPs and CIDR ranges
    with open(exclude_file, 'r', encoding='utf-8') as f:
        for line in f:
            cleaned = parse_line(line)
            if not cleaned:
                continue
            try:
                if '/' in cleaned:
                    # strict=False allows host bits to be set in network definitions
                    cidr_networks.append(ipaddress.ip_network(cleaned, strict=False))
                else:
                    exact_ips.add(ipaddress.ip_address(cleaned))
            except ValueError:
                sys.stderr.write(f"Warning: Skipping invalid entry in {exclude_file}: {cleaned}\n")

    # Process IP list
    with open(ip_file, 'r', encoding='utf-8') as f:
        for line in f:
            cleaned = parse_line(line)
            if not cleaned:
                continue
            try:
                ip = ipaddress.ip_address(cleaned)

                if ip in exact_ips:
                    continue
                if any(ip in net for net in cidr_networks):
                    continue

                print(ip)

            except ValueError:
                sys.stderr.write(f"Warning: Skipping invalid IP in {ip_file}: {cleaned}\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"Usage: python3 {sys.argv[0]} <ip_list_file> <exclusion_file>")

    filter_ips(sys.argv[1], sys.argv[2])
