# 1. Introduction

Welcome to the official documentation for HomestakerOS, a web-based user interface that simplifies the creation of a custom Linux operating system designed specifically for Ethereum homestaking.
By democratizing the homestaking process, it enables more individuals to participate in the Ethereum network securely and efficiently.

## What is HomestakerOS?

HomestakerOS produces Linux disk images based on NixOS, allowing configurations to be public, deterministic, and self-upgrading.
The system is designed to be user-friendly - you can configure and build your host through a simple form interface without requiring extensive knowledge of the Nix language.

> **Note:** The ephemeral nature of HomestakerOS means your operating system runs entirely in RAM, making it secure and easy to reset if needed. This approach follows the "Erase Your Darlings" philosophy (https://grahamc.com/blog/erase-your-darlings/), which enhances security by ensuring the system starts fresh on each boot, eliminating persistent threats and configuration drift.

The resulting images deploy by loading the entire operating system into RAM, making it possible to use various deployment methods:

- [Kernel execution](https://wiki.archlinux.org/title/Kexec)
- [Netbooting](https://networkboot.org/fundamentals/)
- [rEFInd boot manager](http://www.rodsbooks.com/refind/)

## Table of Contents

Here's how it would look with your addition:

1. [Introduction](1-introduction.md) - Overview of the system (you are here)
2. Getting Started
   - [2.1 Prepare the System](2.1-prepare_system.md) - Setting up your local system
   - [2.2 Accessing the Web UI](2.2-accessing_webui.md) - Set up environment for accessing the Web UI
   - [2.3 Configure and Deploy](2.3-configure_deploy.md) - Building and deploying your node
   - [2.4 Managing Your Configurations with Git](2.4-git_management.md) - Version control for your configurations
3. Tutorials
   - [3.1 WireGuard VPN Setup](3.1-wireguard_vpn.md) - Adding secure networking
   - [3.2 SSV Node Setup](3.2-ssv_node.md) - Setting up a Secret Shared Validator node
4. [Reference](4-reference.md) - Complete reference for all configuration settings

## Quick Links

- Live Web UI: [https://homestakeros.com](https://homestakeros.com)
- GitHub Repository: [https://github.com/ponkila/HomestakerOS](https://github.com/ponkila/HomestakerOS)
