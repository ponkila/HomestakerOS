# Getting started
Before deploying HomestakerOS, you need to have a machine running Linux already. This will serve as the underlying fallback operating system. Any flavour of Linux will do, preferably a headless, minimal one like CoreOS.

We are going to need to format the drives manually and set up the necessary files. These files include things like the WireGuard interface configuration and the secret token that ensures a safe connection between beacon node (consensus client) and execution node (execution client).

## Format drives
To begin, we will format the drives to store the secrets and blockchain using the [Btrfs filesystem](https://wiki.archlinux.org/title/btrfs). We prefer Btrfs due to its [Copy-on-Write](https://en.m.wikipedia.org/wiki/Copy-on-write) (COW) resource management technique, allowing efficient snapshot creation. For more information, you can check out this [introduction to Btrfs](https://itsfoss.com/btrfs/).

Let's proceed with creating a Btrfs filesystem with subvolumes for secrets, erigon and lighthouse on a single hard drive or SSD. If you are unsure about whether your drive space is enough, you can check the current size of the mainnet Ethereum blockchain on [ycharts](https://ycharts.com/indicators/ethereum_chain_full_sync_data_size).

1. Check the available drives and partitions:

    ```shell
    lsblk -e7
    ```

    This command displays information about the drives and partitions. Locate your target drive (e.g. `nvme0n1`). The '-e7' option filters out virtual block devices.

2. Format the target drive with Btrfs:

    ```shell
    mkfs.btrfs -l homestaker /dev/nvme0n1
    ```

    This command will **format** `/dev/nvme0n1` as a partitionless Btrfs disk with the label "homestaker". Using a label simplifies referencing it in the frontend.

3. Mount the Btrfs filesystem:

    ```shell
    mount /dev/nvme0n1 /mnt
    ```

    This command mounts the Btrfs disk located at `/dev/nvme0n1` to the `/mnt` directory, enabling subvolume creation.

4. Create the subvolumes:

    ```shell
    btrfs subvolume create /mnt/secrets
    btrfs subvolume create /mnt/erigon
    btrfs subvolume create /mnt/lighthouse
    ```

    These commands create three subvolumes named "secrets", "erigon" and "lighthouse" within the mounted Btrfs filesystem. Once the subvolumes are created, unmount the device `/dev/nvme0n1` using the following command:

    ```shell
    umount /mnt
    ```

5. Create the mountpoints:

    ```shell
    mkdir /mnt/secrets
    mkdir /mnt/erigon
    mkdir /mnt/lighthouse
    ```
    These commands create mountpoints for each subvolume within the `/mnt` directory.

6. Mount the subvolumes:

    ```shell
    mount -o subvol=secrets /dev/nvme0n1 /mnt/secrets
    mount -o subvol=erigon /dev/nvme0n1 /mnt/erigon
    mount -o subvol=lighthouse /dev/nvme0n1 /mnt/lighthouse
    ```
    These commands mount each subvolume under the corresponding subdirectory. Once mounted, you can access the contents of each subvolume in their respective directories.

Now that we have set up the drive as needed, we can define them as [systemd mount](https://www.freedesktop.org/software/systemd/man/systemd.mount.html) units on the frontend when creating the NixOS boot media. 

<details>

<summary> Frontend: How to define systemd mounts for partitionless Btrfs disk</summary>
&nbsp;

To reference the formatted drive, we simply use the label we set. In this case, we can refer to it with `/dev/disk/by-label/homestaker`. Please note that we also need to add `subvol=<subvolumeName>` to the mount options.

```conf
description = "Secrets";
what = "/dev/disk/by-label/homestaker";
where = "/mnt/secrets";
options = "noatime subvol=secrets";
type = "btrfs";
```
```conf
description = "Erigon";
what = "/dev/disk/by-label/homestaker";
where = "/mnt/erigon";
options = "noatime subvol=erigon";
type = "btrfs";
```
```conf
description = "Lighthouse";
what = "/dev/disk/by-label/homestaker";
where = "/mnt/lighthouse";
options = "noatime subvol=lighthouse";
type = "btrfs";
```
</details>

## Secrets

### WireGuard 
[WireGuard](https://www.wireguard.com) is a free and open-source communication protocol. It allows us to connect each machine in our infrastructure via an encrypted virtual private network (VPN). 

Note: __This guide does not provide instructions on setting up the WireGuard server itself at the moment.__

First, we need to install `wireguard-tools`. Then we can create a new private key and derive a corresponding public key for it:

```shell
apt-get install wireguard-tools
wg genkey | tee clientPrivateKey | wg pubkey > clientPublicKey
```

Now that we have the keys, we need to create a `wg-quick` configuration file and a directory for it in the subvolume we created earlier:

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
Our machine needs its own SSH key pair. Let's create a directory for them at `/mnt/secrets/ssh`.

```shell
mkdir /mnt/secrets/ssh
```

The keys can be manually created and placed there, but if absent, NixOS will generate the keys automatically. If you choose to place it manually, please note that the keys should be in Ed25519 format.

In addition, make sure to configure the private SSH key path in the SSH settings on the frontend. In this case, the path should be set to `/mnt/secrets/ssh/id_ed25519`.

## Deployment

Now that the target machine is pre-configured, we can proceed to create the NixOS boot media using the frontend and deploy it. For deployment, we will use the [kexec](https://wiki.archlinux.org/title/kexec) method, which allows loading and booting into another kernel without a power cycle.

It's important to note that HomestakerOS is running entirely on RAM. Therefore, any user-generated directories and files will not persist across reboots or power cycles.

To deploy, we need to install `kexec-tools`. Then, we can execute the `kexec-boot` script, which will "reboot" the machine into HomestakerOS. This can be done using the following commands:

```shell
apt-get install kexec-tools
sudo ./result/kexec-boot
```

At this point, we should not need to access the underlying operating system again unless serious problems occur. To update the system, obtain the boot media files to the HomestakerOS and execute the `kexec-boot` script again to kexec the machine into a up-to-date version.
