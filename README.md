# HomestakerOS

Web frontend source code of [HomestakerOS.com](https://homestakeros.com).

## Abstract

[Nixobolus](https://github.com/ponkila/nixobolus) is first used to generate HTML frontend from Nix `nixosModules` flakes interface. E.g., to generate JSON schema for [erigon](https://github.com/ledgerwatch/erigon) run `nix eval --json .#erigon`. See the `justfile` for more. Next, the schemas are used on the frontend to generate a HTML form. On form submission, the form payload is passed to Nixobolus, which then starts a NixOS build process. On completion, the links to build artifacts (either an ISO file, or a [kexec](https://en.wikipedia.org/wiki/Kexec) script is given to user for download.

## Building

1. Install [Nix](https://nixos.org). This project uses [direnv](https://direnv.net) integration in Nix to build pre-requisite tooling.
2. `git clone https://github.com/ponkila/HomestakerOS && cd HomestakerOS`
3. `direnv allow`
4. `npm run`
