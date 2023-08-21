# SNO ansible scripts

Just a couple of horrible tasks to deploy an SNO cluster on a powerful box I have

This assumes that:
- The remote host (kuemper) has a bridge interface
- It is assumed that for every snoX VM dns and dhcp are so configured that
  sno1.domainname and *.sno1.domainname point to the VMs IP address.
  On my env I have something like this on the DNS/DHCP server:
  ```
  zone "ocplab.ocp" IN {
        type master;
        file "/etc/named/db.ocplab.ocp";
        allow-update { none; };
  };
  # /etc/named/db.ocplab.ocp
  $ORIGIN ocplab.ocp.
  $TTL 1W
  @               IN SOA  @   hostmaster (
                                  2023080539      ; serial
                                  2D              ; refresh
                                  4H              ; retry
                                  6W              ; expiry
                                  1W )            ; minimum
                          IN NS   ns
                          IN A    172.16.15.254


  ns                      IN      A       172.16.15.254
  sno1                    IN      A       172.16.11.50
  *.sno1          300     IN      A       172.16.11.50
  ```
  DHCP:
  ```
  host sno1 {
        hardware ethernet 52:54:00:00:01:66;
        option host-name "sno1.ocplab.ocp";
        fixed-address 172.16.11.50;
  }
  ```
