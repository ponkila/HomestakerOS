# HomestakerOS

HomestakerOS is a web UI which creates custom Linux OS for Ethereum homestaking. It aims to democratize homestaking by simplifying the process of creating and maintaining servers in home environments.

The wizard produces Linux disk images based on NixOS. NixOS allows configurations to be public, deterministic, and self-upgrading. Further, by loading the whole operating system into the RAM, we can eliminate the works on my machine tantrum, while also making it possible to be booted by double-clicking a kernel execution script -- and if you want to return to your previous distribution, just restart your computer.

## How to Run (alpha)

1. **Install Nix:** [nixos.org](https://nixos.org/download.html)

2. **Clone this Repository**
  ```
  git clone https://github.com/ponkila/HomestakerOS && cd HomestakerOS
  ```

3. **Set Up a Development Environment**
- With Nix: `nix develop`
- With [direnv](https://direnv.net/): `direnv allow`

4. **Install Dependencies and Build**
  ```
  yarn install && yarn build
  ```

5. **Start the Web UI**
  ```
  , server
  ```

6. **Open a Command Runner** (optional)
  ```
  tail -f pipe | sh
  ```
  The front end runs its commands through this; leave it open for functionality.

7. **Check it out:** [http://localhost:8081](http://localhost:8081)
