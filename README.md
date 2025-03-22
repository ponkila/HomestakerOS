# 🏠📈 HomestakerOS

HomestakerOS is a web UI that creates a custom Linux OS for Ethereum homestaking.
It aims to democratize homestaking by simplifying the process of creating and maintaining servers in home environments.

Check out the live demo at [https://homestakeros.com/ponkila/homestaking-infra](https://homestakeros.com/ponkila/homestaking-infra)

## 📋 Overview

The wizard produces Linux disk images based on NixOS.
NixOS allows configurations to be public, deterministic, and self-upgrading.
You can configure and build your host with a simple form and push of a button, without requiring extensive knowledge of the Nix language.
The resulting images are deployed by loading the entire operating system into RAM.
This makes it possible to deploy the OS in various ways, such as netbooting, or even booting by double-clicking a kernel execution script.
If you want to return to your previous distribution, just restart your computer!

It also offers a dashboard where you can inspect and manage the entire infrastructure from a single point.
Information is presented in an intuitive way, with automatically generated graphs and diagrams, representing the entire cluster of machines and real-time data about the services they manage.

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
