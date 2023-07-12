To start, you need to have a machine running Linux already. This will serve as the underlying fallback operating system. Any flavour of Linux will do, preferably a headless, minimal one like CoreOS. We are going to need to format the drives manually and set up the necessary files before deploying the HomestakerOS. These files include things like the WireGuard interface configuration and the secret token that ensures a safe connection between beacon node (aka. consensus client) and execution node (aka. execution client).


## Format drives

Firstly, we need to set up the drives for the secrets and blockchain, and we will be using the BTRFS filesystem. We prefer BTRFS for numerous reasons, primarily because of its Copy-on-Write resource management technique. When a file is modified or written to the drive, a copy of the file is created instead of replacing the original. This enables the creation of snapshots with minimal size since unmodified files do not need to be copied when creating snapshots. Snapshots can be used to restore the state of the system and the blockchain if needed.

Let's create a Btrfs filesystem for one drive with following subvolumes:

- /var/mnt/secrets
- /var/mnt/erigon
- /var/mnt/lighthouse

TODO: [commands and stuff]

Now that we have set up the drives as needed, we can define them as systemd mount units on the frontend when creating the NixOS boot media.


## Secrets

### WireGuard 
WireGuard is a free and open-source communication protocol. It allows us to connect each machine in our infrastructure via an encrypted virtual private network (VPN). 

Note: __This guide does not provide instructions on setting up the WireGuard server itself at the moment.__

Let's install `wireguard-tools` and create a new private key and derive a corresponding public key for it:

```
apt-get install wireguard-tools
wg genkey | tee clientPrivateKey | wg pubkey > clientPublicKey
```

Now that we have the keys, we need to create a `wg-quick` configuration file (`wg0.conf`) and place it, for example at `/var/mnt/secrets/wireguard/wg0.conf` , to the subvolume we created the `/var/mnt/secrets` subvolume earlier. Your `wg-quick` configuration should look something like this:

```
[Interface]
Address = <serverIP>/32
PrivateKey = <clientPrivateKey> 

[Peer]
PublicKey = <serverPublicKey>
AllowedIPs =
Endpoint = <endpoint>:51820
PersistentKeepalive = 25
```

TODO: Let's brake the configuration down..

### JWT
The HTTP connection between your beacon node and execution node needs to be authenticated using a JSON Web Token (JWT). There are several ways to generate this token, but let's keep it simple and create it using the OpenSSL command line tool:

```
openssl rand -hex 32 | tr -d "\n" > "jwt.hex"
```

This same token needs to be available for both the beacon node and the execution node. Let's copy this token we generated to their corresponding subvolumes we created earlier:

```
cp jwt.hex /var/mnt/erigon
cp jwt.hex /var/mnt/lighthouse
rm jwt.hex
```


## Deployment

Now that we have the target machine pre-configured, we can create the NixOS boot media through our frontend and deploy it. The deployment method we are going to use is kexec, which enables us to load and boot into another kernel from the currently running kernel without a power cycle. HomestakerOS is ephemeral, meaning that it will run entirely on RAM, providing significant performance benefits by reducing I/O operations. This means that __any user generated directories and/or files are NOT persistent.

First, we need to install `kexec-tools`. Then, we can execute the `kexec-boot` script, which will "reboot" the machine to HomestakerOS. This can be done using the following commands:

```
apt-get install kexec-tools
sudo ./result/kexec-boot
```

At this point, we should not need to access the underlying operating system again unless serious problems occur.


## Updating

TODO: To update the system..


## References

Format drives:
- [Btrfs Wiki - Arch Linux](https://wiki.archlinux.org/title/btrfs)
- [Introduction to Btrfs - It's FOSS](https://itsfoss.com/btrfs/)
- [systemd.mount - systemd Documentation](https://www.freedesktop.org/software/systemd/man/systemd.mount.html)

Secrets, WireGuard:
- [WireGuard Quick Start Guide](https://www.wireguard.com/quickstart/)
- [wg-quick(8) — Debian Manpages](https://manpages.debian.org/unstable/wireguard-tools/wg-quick.8.en.html)

Secrets, JWT:
- [Configure JWT authentication - Prysm](https://docs.prylabs.network/docs/execution-node/authentication)

Deployment, kexec:
- [kexec - Arch Linux Wiki](https://wiki.archlinux.org/title/kexec)