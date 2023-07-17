# Getting started
To start, you need to have a machine running Linux already. This will serve as the underlying fallback operating system. Any flavour of Linux will do, preferably a headless, minimal one like CoreOS. We are going to need to format the drives manually and set up the necessary files before deploying the HomestakerOS. These files include things like the WireGuard interface configuration and the secret token that ensures a safe connection between beacon node (aka. consensus client) and execution node (aka. execution client).


## Format drives
Firstly, we need to set up the drives for the secrets and blockchain, and we will be using the [BTRFS filesystem](https://wiki.archlinux.org/title/btrfs). We prefer BTRFS for numerous reasons, primarily because of its [Copy-on-Write](https://en.m.wikipedia.org/wiki/Copy-on-write) (COW) resource management technique. When a file is modified or written to the drive, a copy of the file is created instead of replacing the original. This enables the creation of snapshots with minimal size since unmodified files do not need to be copied when creating snapshots. Snapshots can be used to restore the state of the system and the blockchain if needed. If you want to know more, here is a good [introduction to Btrfs](https://itsfoss.com/btrfs/).

Let's create a Btrfs filesystem for a single hard drive or SSD with subvolumes for secrets, erigon, and lighthouse. If you are unsure about whether your drive space is enough, please check the current size of the mainnet Ethereum blockchain on [ycharts](https://ycharts.com/indicators/ethereum_chain_full_sync_data_size).

1. Check the drives and partitions:
    ```shell
    lsblk -e7
    ```
    This command will display information about available drives and partitions. Look for your target drive -- I will be using the `nvme0n1`. The option '-e7' filters out loop devices, which are virtual block devices. 

2. Create a Btrfs disk:
    ```shell
    mkfs.btrfs -l homestaker /dev/nvme0n1
    ```
    This command will format the `/dev/nvme0n1` disk as a partitionless Btrfs disk with the label 'homestaker', allowing us to reference it without using the UUID in the frontend.

3. Mount the Btrfs filesystem:
    ```shell
    sudo mount /dev/nvme0n1 /mnt
    ```
    This command will mount the Btrfs disk located at `/dev/nvme0n1` to the `/mnt` directory. This is required to enable subvolume creation.

4. Create the subvolumes:
    ```shell
    btrfs subvolume create /mnt/secrets
    btrfs subvolume create /mnt/erigon
    btrfs subvolume create /mnt/lighthouse
    ```
    These commands will create three subvolumes named 'secrets', 'erigon', and 'lighthouse' respectively within the mounted Btrfs filesystem.

Now that we have set up the drive as needed, we can define them as [systemd mount](https://www.freedesktop.org/software/systemd/man/systemd.mount.html) units on the frontend when creating the NixOS boot media. To reference the formatted drive, we simply use the label we set, in this case: `/dev/disk/by-label/homestaker`.

<details>

<summary> Frontend: How to define systemd mounts for partitionless Btrfs disk</summary>

```conf
description = "Secrets";
what = "/dev/disk/by-label/homestaker";
where = "/mnt/secrets";
options = "noatime subvol=/mnt/secrets";
type = "btrfs";
```
```conf
description = "Erigon";
what = "/dev/disk/by-label/homestaker";
where = "/mnt/erigon";
options = "noatime subvol=/mnt/erigon";
type = "btrfs";
```
```conf
description = "Lighthouse";
what = "/dev/disk/by-label/homestaker";
where = "/mnt/lighthouse";
options = "noatime subvol=/mnt/lighthouse";
type = "btrfs";
```
</details>


## Secrets

### WireGuard 
[WireGuard](https://www.wireguard.com) is a free and open-source communication protocol. It allows us to connect each machine in our infrastructure via an encrypted virtual private network (VPN). 

Note: __This guide does not provide instructions on setting up the WireGuard server itself at the moment.__

Let's install `wireguard-tools` and create a new private key and derive a corresponding public key for it:

```shell
apt-get install wireguard-tools
wg genkey | tee clientPrivateKey | wg pubkey > clientPublicKey
```

Now that we have the keys, we need to create a `wg-quick` configuration file to the subvolume we created earlier:
```shell
mkdir /mnt/secrets/wireguard
touch /mnt/secrets/wireguard/wg0.conf
```

Your configuration should look something like this:

```conf
[Interface]
Address = 192.168.1.120/32
PrivateKey = 0F3OWcop34EQOW+UpJnPkPCb3FKZbCY73U9T8ovo70s=

[Peer]
PublicKey = r4JYV53tLdbS/Yp50jgZpLQ0/snMtqBaFftN/Vcseh8=
AllowedIPs = 192.168.1.0/24
Endpoint = ponkila.com:51820
PersistentKeepalive = 25
```

<details>

<summary>Let's brake the configuration down..</summary>

#### [Interface]

- **Address** = `<serverIP>/32`: This is the IP address of the WireGuard server. This is the IP address assigned to the server in the VPN network.
- **PrivateKey** = `<clientPrivateKey>`: This is the private key we just generated for the WireGuard client. This key is used to authenticate the client.

#### [Peer]

- **PublicKey** = `<serverPublicKey>`: This is the public key of the WireGuard tunnel. This key is used to authenticate the tunnel.
- **AllowedIPs** = `<AllowedIPs>`: This field specifies the IP addresses or IP ranges that are allowed to be accessed through the WireGuard tunnel.
- **Endpoint** = `<serverEndpoint>:51820`: This is the IP address or hostname of the WireGuard server endpoint. The 51820 is the default WireGuard port.
- **PersistentKeepalive** = 25: This option ensures that the connection stays active by sending a keepalive signal every 25 seconds.

For more information: https://man7.org/linux/man-pages/man8/wg.8.html

</details>


### JWT
The HTTP connection between your beacon node and execution node needs to be authenticated using a JSON Web Token (JWT). There are several ways to generate this token, but let's keep it simple and create it using the OpenSSL command line tool:

```shell
openssl rand -hex 32 | tr -d "\n" > "jwt.hex"
```

This same token needs to be available for both the beacon node and the execution node. Let's copy this token we generated to their corresponding subvolumes we created earlier:

```shell
cp jwt.hex /mnt/erigon
cp jwt.hex /mnt/lighthouse
rm jwt.hex
```

### SSH
Our machine needs its own private SSH key. Let's create a directory for it at `/mnt/secrets/ssh`. 

```shell
mkdir /mnt/secrets/ssh
```

The key can be manually created and placed there, but if absent, NixOS will generate this key automatically. If you choose to place it manually, please note that __the key should be in Ed25519 format__. Additionally, this path should be configured in the SSH settings on the frontend. In this case, the path would be `/mnt/secrets/ssh/id_ed25519`.

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