# Getting started
To start, you need to have a machine running Linux already. This will serve as the underlying fallback operating system. Any flavour of Linux will do, preferably a headless, minimal one like CoreOS. We are going to need to format the drives manually and set up the necessary files before deploying the HomestakerOS. These files include things like the WireGuard interface configuration and the secret token that ensures a safe connection between beacon node (aka. consensus client) and execution node (aka. execution client).


## Format drives
Firstly, we need to set up the drives for the secrets and blockchain, and we will be using the [BTRFS filesystem](https://wiki.archlinux.org/title/btrfs). We prefer BTRFS for numerous reasons, primarily because of its Copy-on-Write resource management technique. When a file is modified or written to the drive, a copy of the file is created instead of replacing the original. This enables the creation of snapshots with minimal size since unmodified files do not need to be copied when creating snapshots. Snapshots can be used to restore the state of the system and the blockchain if needed. If you want to know more, here is a good [introduction to Btrfs](https://itsfoss.com/btrfs/).

Let's create a Btrfs filesystem for a single hard drive or SSD with subvolumes for secrets, erigon, and lighthouse. If you are unsure about whether your drive space is enough, please check the current size of the mainnet Ethereum blockchain on [ycharts](https://ycharts.com/indicators/ethereum_chain_full_sync_data_size).

```shell
# Check the drives and partitions
lsblk -e7

# Create a partitionless Btrfs disk with 'homestaker' label
mkfs.btrfs -l homestaker /dev/nvme0n1

# To create the subvolumes, the btrfs filesystem must be mounted
sudo mount /dev/nvme0n1 /mnt

# Create the subvolumes
btrfs subvolume create /mnt/secrets
btrfs subvolume create /mnt/erigon
btrfs subvolume create /mnt/lighthouse
```

Now that we have set up the drive as needed, we can define them as [systemd mount](https://www.freedesktop.org/software/systemd/man/systemd.mount.html) units on the frontend when creating the NixOS boot media. We can refer to the formatted drive by its label, which in this case is `/dev/disk/by-label/homestakeros`."


## Secrets

### WireGuard 
[WireGuard](https://www.wireguard.com) is a free and open-source communication protocol. It allows us to connect each machine in our infrastructure via an encrypted virtual private network (VPN). 

Note: __This guide does not provide instructions on setting up the WireGuard server itself at the moment.__

Let's install `wireguard-tools` and create a new private key and derive a corresponding public key for it:

```shell
apt-get install wireguard-tools
wg genkey | tee clientPrivateKey | wg pubkey > clientPublicKey
```

Now that we have the keys, we need to create a `wg-quick` configuration file (`wg0.conf`) and place it to the subvolume we created earlier, at `/var/mnt/secrets/wireguard/wg0.conf`. Your `wg-quick` configuration should look something like this:

```conf
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

```shell
openssl rand -hex 32 | tr -d "\n" > "jwt.hex"
```

This same token needs to be available for both the beacon node and the execution node. Let's copy this token we generated to their corresponding subvolumes we created earlier:

```shell
cp jwt.hex /var/mnt/erigon
cp jwt.hex /var/mnt/lighthouse
rm jwt.hex
```

### SSH
Our machine needs its own private SSH key. Let's create a directory for it at `/mnt/secrets/ssh`. 

```shell
mkdir /mnt/secrets/ssh
```

The key can either be manually created and placed there, but if absent, NixOS will generate this key automatically. If you choose to place it manually, please note that the key should be in Ed25519 format. Additionally, this path should be configured in the SSH settings on the frontend. In this case, the path would be `/mnt/secrets/ssh/id_ed25519`.

You can derive the public key for automatically generated private key with the following command:

```shell
ssh-keygen -f /mnt/secrets/ssh/id_ed25519 -y > /mnt/secrets/ssh/id_ed25519.pub
```


## Deployment

Now that we have the target machine pre-configured, we can create the NixOS boot media through our frontend and deploy it. The deployment method we are going to use is [kexec](https://wiki.archlinux.org/title/kexec), which enables us to load and boot into another kernel from the currently running kernel without a power cycle. HomestakerOS is ephemeral, meaning that it will run entirely on RAM, providing significant performance benefits by reducing I/O operations. This means that __any user generated directories and/or files are NOT persistent.__

First, we need to install `kexec-tools`. Then, we can execute the `kexec-boot` script, which will "reboot" the machine to HomestakerOS. This can be done using the following commands:

```shell
apt-get install kexec-tools
sudo ./result/kexec-boot
```

At this point, we should not need to access the underlying operating system again unless serious problems occur. To update the system, obtain the boot media files to the HomestakerOS and execute the `kexec-boot` script again to kexec the machine into a up-to-date version.