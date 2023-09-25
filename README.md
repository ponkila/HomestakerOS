# HomestakerOS

HomestakerOS is a web UI which creates custom Linux OS for Ethereum homestaking. It aims to democratize homestaking by simplifying the process of creating and maintaining servers in home environments.

The wizard produces Linux disk images based on NixOS. NixOS allows configurations to be public, deterministic, and self-upgrading. Further, by loading the whole operating system into the RAM, we can eliminate the works on my machine tantrum, while also making it possible to be booted by double-clicking a kernel execution script -- and if you want to return to your previous distribution, just restart your computer.

Check out the live demo at https://demo.homestakeros.com/

## How to Run

1. **Install Nix:** [nixos.org](https://nixos.org/download.html)

2. **Clone this Repository**
  ```
  git clone https://github.com/ponkila/HomestakerOS && cd HomestakerOS
  ```

3. **Set Up a Development Environment**
- With Nix: `nix develop`
- With [direnv](https://direnv.net/): `direnv allow`

4. **Start the Web UI**
  ```
  , server
  ```

5. **Open a Command Runner**
  ```
  tail -f pipe | sh
  ```
  The frontend runs its commands through this, leave it open for functionality.

6. **Check it out** 

  Go to [http://localhost:8081](http://localhost:8081) to start using the Web UI. 
