# Getting Started

Before deploying HomestakerOS, you need to have a machine running Linux already. This will serve as the underlying fallback operating system. Any flavour of Linux will do, preferably a headless, minimal one like CoreOS.

We are going to need to format the drives manually and set up the necessary files. These files include things like the WireGuard interface configuration and the secret token that ensures a safe connection between beacon node (consensus client) and execution node (execution client).

## Format Drives
To begin, we will format the drives to store the secrets and blockchain using the [Btrfs filesystem](https://wiki.archlinux.org/title/btrfs). We prefer Btrfs due to its [Copy-on-Write](https://en.m.wikipedia.org/wiki/Copy-on-write) (COW) resource management technique, allowing efficient snapshot creation. For more information, you can check out this [introduction to Btrfs](https://itsfoss.com/btrfs/).

Let's proceed with creating a Btrfs filesystem with subvolumes for secrets, Erigon and Lighthouse on a single hard drive or SSD. If you are unsure about whether your drive space is enough, you can check the current size of the mainnet Ethereum blockchain on [ycharts](https://ycharts.com/indicators/ethereum_chain_full_sync_data_size).

1. Check the available drives and partitions

    ```shell
    lsblk -e7
    ```
    This command displays information about the drives and partitions. Locate your target drive (e.g. `nvme0n1`). The '-e7' option filters out virtual block devices.

2. Format the target drive with Btrfs

    ```shell
    mkfs.btrfs -l homestaker /dev/nvme0n1
    ```
    This command will **format** `/dev/nvme0n1` as a partitionless Btrfs disk with the label "homestaker". Using a label simplifies referencing it in the frontend.

3. Create the subvolumes

    ```shell
    mount /dev/nvme0n1 /mnt
    ```
    This command mounts the Btrfs filesystem located at `/dev/nvme0n1` to the `/mnt` directory, enabling subvolume creation.

    ```shell
    btrfs subvolume create /mnt/addons
    btrfs subvolume create /mnt/secrets
    btrfs subvolume create /mnt/erigon
    btrfs subvolume create /mnt/lighthouse
    ```
    These commands create three subvolumes named "addons", "secrets", "erigon" and "lighthouse" within the mounted Btrfs filesystem.

    ```shell
    umount /mnt
    ```
    This command unmounts the Btrfs filesystem mounted at `/mnt`.

4. Mount the subvolumes

    ```shell
    mkdir /mnt/addons /mnt/secrets /mnt/erigon /mnt/lighthouse
    ```
    This command create mountpoints for each subvolume within the `/mnt` directory.

    ```shell
	mount -o subvol=addons /dev/nvme0n1 /mnt/addons
	mount -o subvol=secrets /dev/nvme0n1 /mnt/secrets
    mount -o subvol=erigon /dev/nvme0n1 /mnt/erigon
    mount -o subvol=lighthouse /dev/nvme0n1 /mnt/lighthouse
    ```
    These commands mount each subvolume under the corresponding subdirectory. Once mounted, you can access the contents of each subvolume in their respective directories.

---

Now that we have set up the drive as needed, we can define them as [systemd mount](https://www.freedesktop.org/software/systemd/man/systemd.mount.html) units on the frontend when creating the NixOS boot media. 

<details>

<summary> Frontend: How to define systemd mounts for partitionless Btrfs disk</summary>
&nbsp;

To reference the formatted drive, we simply use the label we set. In this case, we can refer to it with `/dev/disk/by-label/homestaker`. Please note that we also need to add `subvol` options to the mount entries.


Create mount entries for each subvolume:
```conf
options -> subvol=<subvolumeName>
type    -> btrfs
what    -> /dev/disk/by-label/homestaker
where   -> /mnt/<subvolumeName>
```

</details>

## Secrets

### WireGuard 
[WireGuard](https://www.wireguard.com) is a free and open-source communication protocol. It allows us to connect each machine in our infrastructure via an encrypted virtual private network (VPN). 

Note: __This guide does not provide instructions on setting up the WireGuard server itself at the moment.__

1. Install the `wireguard-tools`

    ```shell
    apt-get install wireguard-tools
    ```

2. Create a new key pair

    ```shell
    wg genkey | tee clientPrivateKey | wg pubkey > clientPublicKey
    ```
    This command will generate a new private key and derive a corresponding public key for it. These keys will be saved as `clientPrivateKey` and `clientPublicKey`.

3. Create the configuration

    ```shell
    mkdir /mnt/secrets/wireguard
    touch /mnt/secrets/wireguard/wg0.conf
    ```
    These commands will create a directory and the configuration file in the subvolume we created earlier.

---
Now that we have the keys and an empty configuration file, it is time to set the WireGuard configuration. Your configuration should look something like this:

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
- **PersistentKeepalive** = `25`: This option ensures that the connection stays active by sending a keepalive signal every 25 seconds.

For more information: https://man7.org/linux/man-pages/man8/wg.8.html

</details>

### JWT
The HTTP connection between your beacon node and execution node needs to be authenticated using a JSON Web Token (JWT). There are several ways to generate this token, but let's keep it simple and create it using the OpenSSL command line tool.

1. Generate the JWT

    ```shell
    openssl rand -hex 32 | tr -d "\n" > "jwt.hex"
    ```
    This command generates a random 32-byte hexadecimal string and saves it to a file named `jwt.hex`.

2. Copy the JWT to the subvolumes of the nodes

    ```shell
    cp jwt.hex /mnt/erigon
    cp jwt.hex /mnt/lighthouse
    rm jwt.hex
    ```
    These commands will copy the generated JWT to both the "erigon" and "lighthouse" subvolumes we created earlier and then remove the original file.

### SSH
Our machine needs its own SSH key pair. Let's create a directory to store the SSH keys at at `/mnt/secrets/ssh`.

```shell
mkdir /mnt/secrets/ssh
```

The keys can be manually created and placed there, but if absent, NixOS will generate the keys automatically. If you choose to place it manually, please note that the keys should be in Ed25519 format.

You can generate the keys manually by running the following command:

```shell
ssh-keygen -t ed25519 -f /mnt/secrets/ssh/id_ed25519 -N ""
```

Either way, make sure to configure the private SSH key path in the SSH settings on the frontend. In this case, the path should be set to `/mnt/secrets/ssh/id_ed25519`.

## Addons

### SSV-node
The [ssv.network](https://ssv.network/overview/) is a fully decentralized, open-source, and trustless DVT Network that provides a reusable infrastructure solution for decentralizing Ethereum validators.

1. Generate a key pair

    ```shell
    nix run .#init-ssv -- <hostname>
    ```

2. Transfer the private key securely to the target machine to the path you have configured at the frontend

3. Register an SSV operator

    You can register an operator on the Web UI. For more information, see [these instructions](https://ssv-network.gitbook.io/guides/operator/registering-an-operator) by ssv.network.

4. Kernel execute to activate

## Web UI
Now that the target machine is pre-configured, we can proceed to create the NixOS boot media using the Web UI frontend. For running the Web UI, prefer a machine within the same network as your nodes, since the frontend has capability to interact with your nodes.

1. Install Nix: [nixos.org](https://nixos.org/download.html)

2. Create a template out of [HomestakerOS](https://github.com/ponkila/HomestakerOS) repository

3. Clone your new repository

    ```
    git clone git@github.com:<username>/HomestakerOS.git && cd HomestakerOS
    ```

4. Enter in a development environment

    - With Nix: `nix develop`
    - With [direnv](https://direnv.net/): `direnv allow`

5. Start the Web UI

    ```
    , server
    ```

6. Open a command runner in a new terminal

    ```
    tail -f pipe | sh
    ```
    The frontend runs its commands through this, leave it open for functionality.

7. Check it out
    
    Go to [http://localhost:8081](http://localhost:8081) to start using the Web UI.

---
After you have configured your target machine, hit the `#BUIDL` button to build the host. Your host will appear under "Nodes" tab where you can edit and download the boot media files. Please upstream the Nix files to your GitHub repository after you are done with creating and editing your nodes, the Web UI will automatically stage them for you.

## Deployment
For deployment, we will use the [kexec](https://wiki.archlinux.org/title/kexec) (kernel execute) method, which allows loading and booting into another kernel without a power cycle.

It's important to note that HomestakerOS is running entirely on RAM. Therefore, any user-generated directories and files will not persist across reboots or power cycles.

Obtain the boot media files for the target machine created via the Web UI and then proceed with the following steps:

1. Install the `kexec-tools`

    ```shell
    apt-get install kexec-tools
    ```

2. Kernel execute

    ```shell
    sudo ./kexec-boot
    ```
    This command will execute the `kexec-boot` script, which will "reboot" the machine into HomestakerOS.

---
At this point, we should not need to access the underlying operating system again unless serious problems occur. To update the system, obtain the boot media files to the HomestakerOS and execute the `kexec-boot` script again to kexec the machine into a up-to-date version.
