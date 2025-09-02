# 🏠📈 HomestakerOS

HomestakerOS is a declaratively managed Linux distribution for [Ethereum homestaking](https://ethereum.org/en/staking/solo/).
Nodes can be managed either through a web UI or via text files.
Compared to Docker-based approaches which build on Ubuntu and the apt package manager, HomestakerOS builds on [NixOS](https://nixos.org/) and the Nix package manager.
And by _building_, we really mean building: both the web UI and the text files are actually instructions how to derive a self-contained Linux disk images (akin to ISO files) from zero.
By self-contained we mean that once the image is booted, there are no further commands to run for the node become operational.
A unique aspect of HomestakerOS is that you never "install" HomestakerOS, but instead you run it as an ephemeral [RAM disk](https://en.wikipedia.org/wiki/Initial_ramdisk) (a.k.a "live CD").

This repository contains open-source software tooling to create such images.
The main contribution is the web UI at [HomestakerOS.com](https://homestakeros.com) and its NixOS configuration page, which allows you to configure and build homestaking nodes using a web UI.
The main artifacts returned by the build process endorse [kexec](https://en.wikipedia.org/wiki/Kexec) as the boot approach: given an existing Linux installation, executing the `kexec-boot` file jumps the existing Linux into HomestakerOS.
The web UI also returns you [a pre-configured NixOS system template](https://github.com/ponkila/HomestakerOS-template).
Compared to Docker-based alternatives, this bootstraps you with more control over your node: you can manage the whole Linux distribution rather than only the Ethereum client software.

The main practical benefit of the approach endorsed by HomestakerOS is improved system reliability.
Tragicomically and anecdotally, Linux is easier to manage and troubleshoot when you delete it (so-called ["erase your darlings"](https://grahamc.com/blog/erase-your-darlings/) paradigm) on each boot.
This does not mean deleting everything -- blockchain state and other so-called "persistent" files are saved in an opt-in manner via disk mounts.


To get started, there exists a live demo which uses a publicly shared multi-node cluster: [https://homestakeros.com/ponkila/homestaking-infra](https://homestakeros.com/ponkila/homestaking-infra).

## 🛠️ Usage

1. **Install Nix** [nixos.org](https://nixos.org/download.html)

2. **Clone this Repository**

    ```
    git clone https://github.com/ponkila/HomestakerOS && cd HomestakerOS
    ```

3. **Start the backend**

    ```
    nix run .#backend
    ```

4. Visit [https://homestakeros.com/](https://homestakeros.com/)

5. Set the flake URI as `<github-username>/<repository-name>`

6. Click 'Submit' to load your configurations

## 🌟 Inspiration

This project was inspired by the challenges encountered while managing our existing Ethereum infrastructure.
The lack of knowledge about the setup and configuration of other maintainers' nodes within the same infrastructure leads to wasted time, effort, and downtime.
The declarative nature of NixOS configurations, combined with the ephemeral approach, significantly enhances management and collaboration among team maintainers.
It ensures that configurations are centralized and real-time information about the whole infrastructure is easily accessible by all participants.

You can see our running, real-time infrastructure right in [homestaking-infra](https://github.com/ponkila/homestaking-infra).

## 🧩 Clients and Addons

In the web user interface, you will configure your node under the 'NixOS config' tab.
You can select the Ethereum client(s) and any additional addons.
The packages for these mainly come from [ethereum.nix](https://github.com/nix-community/ethereum.nix) and are frequently updated by the collaborators who use them.
We look forward to adding more components on-demand and preferably upstreaming them if we package them ourselves.

## 🔍 Looking Ahead

For those interested in the details, let's dive into the documentation from here.

- [1. 📕 Getting Started](./docs/homestakeros/1-introduction.md)

  Learn how to set up your machine for deploying HomestakerOS, including essential setup and configurations.

- [2. 📗 Tutorial for Homestaking](./docs/tutorial_for_homestaking.md)

  This is our entry-level guide to Ethereum and homestaking.

- [3. 📘 Working with Nix](./docs/workflow.md) (**outdated**)

  An in-depth explanation of the HomestakerOS workflow, including the initialization process and build process.

- [4. 📙 Netbooting with Nixie](https://github.com/majbacka-labs/nixos.fi)

  Explore Nixie, a project designed for deploying and managing ephemeral operating systems.

## 💼 Backers and Support

HomestakerOS is still a work in progress, and while it has previously received support from a grant by the [Ethereum Foundation](https://ethereum.org/en/foundation/) and [ssv.network](https://ssv.network/), we are actively seeking additional funding and support to continue development.
If you're interested in contributing or funding this project, please reach out!
