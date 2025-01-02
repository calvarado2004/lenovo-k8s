version: 2
ethernets:
  eth0:
    addresses:
      - ${ip_address}/24
    gateway4: 192.168.122.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4

