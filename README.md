The First Boot Wizard aims to be a walkthrough tool to setup a node of a Community Network.

It will help the owner to set up the node, either creating a new network or joining an existing one,
and being able to configure the specific parameters of this node (like its name).

## Some notes about what is needed

* Welcome Captive Portal
* Detect nearby networks (BSSID cafecoffee)
* Option to join a network, to create a new Network, or restore a saved configuration
* Join a network:
    * Fetch info from nearby node (wget config from neigh)
    * Customize node
* Create a new Network
    * Configure Network
    * Network Name
        * Advanced: Channels
        * Advanced: IP range
        * Advanced: DNS IP
        * Advanced: Log Server IP
        * Advanced: CollectD Server IP
        * Advanced: Captive Portal Config
    * Customize node
* Restore a saved configuration
* Customize Node
    * Node Name
    * Advanced: Node IP
    * Advanced: AP enabled
    * Advanced: AP password
* Submit

Files that need to be configured:
* /etc/config/lime
* /etc/config/lime-defaults
Also, any other service that we think are base, like the LibreServer, could be here.

Potential strategy: Start with just one AP in 2.4Ghz, Use 5Ghz radio to scan

## Useful commands:

Name of the network:
```
cat /etc/config/lime | grep ap_ssid | awk '{print $3}' | tr -d \'
quintana.libre.org.ar
```

List of LiMe ssid networks:
```
iwinfo | grep -B 1 CA:FE:00:C0:FF:EE | grep ESSID | awk '{print $3}' | tr -d \"
LiMe.nicojesigioia
LiMe.oncelotes
```

List of Lime ssid on wlan1 with channel
```
$ iwinfo | grep -B 1 -A 1 CA:FE:00:C0:FF:EE | grep -A 2 wlan1
wlan1-adhoc ESSID: "LiMe.oncelotes"
          Access Point: CA:FE:00:C0:FF:EE
          Mode: Ad-Hoc  Channel: 112 (5.560 GHz)
```

For the file server, use uhttpd.
We can add a temporary route while in setup, that will be removed afterwards, like a symbolic link.
Can be done through a set of ubus commands, and a specific webpage that uses them.

Get config from routers:
```
iw <iface> set type ibss
ip link set <iface> up
iw dev <iface> ibss join <SSID> <freq in MHz> HT20 <freq> <fixed bssid>
```

```
iw dev wlp2s0 ibss join LiMe.nicopace 2412 HT20 2412 CA:FE:00:C0:FF:EE
IPADDR=$(ping6 -n -L -c 1 ${count:+-c 2} -w 1 ff02::2%$iface | grep "^64 bytes" | awk '{print $4}')
wget http://$IPADDR:8080/ -o /tmp/config.tmp.zip
```

