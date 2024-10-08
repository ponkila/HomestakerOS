# HomestakerOS

HomestakerOS is a web UI which creates custom Linux OS for Ethereum homestaking. It aims to democratize homestaking by simplifying the process of creating and maintaining servers in home environments.

The wizard produces Linux disk images based on NixOS. NixOS allows configurations to be public, deterministic, and self-upgrading. Further, by loading the whole operating system into the RAM, we can eliminate the works on my machine tantrum, while also making it possible to be booted by double-clicking a kernel execution script -- and if you want to return to your previous distribution, just restart your computer.

Check out the live demo at https://demo.homestakeros.com/

## How to Run

1. **Install Nix:** [nixos.org](https://nixos.org/download.html)

2. **Create a template from this repository**

3. **Clone this Repository**
  ```
  git clone https://github.com/<owner>/<repository-name> && cd <repository-name>
  ```

4. **Start the Web UI**
  ```
  nix run .#
  ```

5. **Check it out**

  Go to [http://localhost:8081](http://localhost:8081) to start using the Web UI.

## Configuration

In the web user interface, you will configure your node under the 'NixOS config' tab. Now, you can:

- Select the Ethereum client(s) and any additional addons
- Configure SSH keys for secure access (leave `privateKeyFile` and `hostPublicKey` empty for now)
- We will format the disks manually after deployment, so no need to configure mount options yet

Once configured, click '#BUIDL' to generate the boot image and other artifacts. The time taken for this will vary based on your machine’s resources.

## Deployment

The image is in kernel + initrd format, and it can be deployed in various ways. For now, we will use the [kexec](https://wiki.archlinux.org/title/kexec) (kernel execute) method, which allows loading and booting into another kernel without a power cycle. It's important to note that HomestakerOS runs entirely in RAM. Therefore, any user-generated directories and files will not persist across reboots or power cycles.

Obtain the boot media files for the target machine created via the WebUI, and then proceed with the following steps:

1. Install `kexec-tools`

    ```shell
    apt-get install kexec-tools
    ```

2. Kernel execute

    ```shell
    sudo ./kexec-boot
    ```
    This command will execute the `kexec-boot` script, which will "reboot" the machine into HomestakerOS.

Here is some more information about other deployment methods:

- Netboot: [Network Boot](https://networkboot.org/fundamentals/) | [nixos.fi](https://github.com/majbacka-labs/nixos.fi)
- rEFInd: [ArchWiki - rEFInd](https://wiki.archlinux.org/title/REFInd)

### Setup Persistent Storage

While HomestakerOS images are ephemeral and do not require a storage device, we need one for storing the blockchain and some secrets. Most secrets are generated automatically and rotated on every reboot, but some must remain the same. If you are unsure whether your drive has enough space, you can check the current size of the Ethereum mainnet blockchain on [ycharts](https://ycharts.com/indicators/ethereum_chain_full_sync_data_size).

Once deployed, we will manually format the drives on the target machine and set up a directory structure for all persistent data. In this example, we will format the drive to a [Btrfs filesystem](https://wiki.archlinux.org/title/btrfs).

1. Check the available drives and partitions

    ```shell
    lsblk -e7
    ```
    This command displays information about the drives and partitions. Locate your target drive (e.g., `sda`). The `-e7` option filters out virtual block devices.

2. Format the target drive with Btrfs

    ```shell
    mkfs.btrfs -l homestaker /dev/sda
    ```
    This command will **format** `/dev/sda` as a partitionless Btrfs disk with the label "homestaker". Using a label simplifies referencing it in the frontend.

3. Create the subvolumes

    ```shell
    mkdir /mnt
    mount /dev/sda /mnt
    ```
    This command mounts the Btrfs filesystem located at `/dev/sda` to the `/mnt` directory, enabling subvolume creation.

    ```shell
    btrfs subvolume create /mnt/addons
    btrfs subvolume create /mnt/secrets
    btrfs subvolume create /mnt/ethereum
    ```
    These commands create three subvolumes named "addons", "secrets", and "ethereum" within the mounted Btrfs filesystem.

    ```shell
    umount /mnt
    ```
    This command unmounts the Btrfs filesystem from `/mnt`.

4. Mount the subvolumes

    ```shell
    mkdir -p /mnt/{addons,secrets,ethereum}
    ```
    This command creates mount points for each subvolume within the `/mnt` directory.

    ```shell
    mount -o subvol=addons /dev/sda /mnt/addons
    mount -o subvol=secrets /dev/sda /mnt/secrets
    mount -o subvol=ethereum /dev/sda /mnt/ethereum
    ```
    These commands mount each subvolume under the corresponding subdirectory. Once mounted, you can access the contents of each subvolume in their respective directories.

Finally, retrieve the automatically generated host SSH keys from `/etc/ssh/` and place them in a persistent location you set up for them, such as `/mnt/secrets/ssh`.

## Activation

After the first deployment, launch the WebUI again and load your configuration. This time, add the `privateKeyFile` and `hostPublicKey` under the *ssh* options. Also, configure the *mounts* options according to your formatting and directory structure from earlier. Once everything is set, click '#BUIDL' again to generate the image for the activation deployment.

Deploy the image again using your preferred method, just like before. After deployment, sensitive information such as private keys will be decrypted using your own SSH key in `authorizedKeys`, and your node will be activated.

Happy homestaking! :)

