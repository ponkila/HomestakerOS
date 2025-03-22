# The Workflow

I'll be explaining the workflow behind the HomestakerOS frontend, focusing on its infrastructure and the interactions among its components.
I've divided this into two main sections: "Initialization" and "Build Process".
But before we dive into the inner workings, let me have a quick word about the repositories:

- “**[homestaking-infra](https://github.com/ponkila/homestaking-infra)**” - This was the initial effort of this project, where I began on "nixifying" the Ethereum infrastructure, which was originally put together by Juuso and Tommi.
Now, this uses the same modules as the hosts made with HomestakerOS.

- “**[Nixobolus](https://github.com/ponkila/nixobolus)**” - Initially considered as the backend of the project, we later realized that the logic had to be written within the same repository as the frontend.
Today, this repository primarily serves as a hub for maintaining and sharing essential modules.
These modules were derived from the initial configurations created for the homestaking-infra repository.

- “**[HomestakerOS](https://github.com/ponkila/HomestakerOS)**” - The final part of this trilogy, you are here.

## Initialization

In the development environment, there is a mission-control script that can be executed using the `, server` command.
This script includes a couple of commands that will execute some more scripts and initialize the web server.
This section essentially explains what exactly that command does.

### 1. Fetch Schema

First, we need to fetch the module options from Nixobolus.
These module options are made accessible in Nixobolus by creating an unknown flake output called "exports", which has been defined to contain the evaluated, parsed data of the module options.
The options have to be evaluated with `evalModules` before dumping them into the exports -- otherwise, we would only see the options as a lambda value.

<details>

<summary>A snippet from the Nixobolus' flake</summary>
<br/>

See the whole thing at: <https://github.com/ponkila/nixobolus/blob/main/flake.nix>

```nix
let
  inherit (self) outputs;

  # Function to format module options
  parseOpts = options:
    nixpkgs.lib.attrsets.mapAttrsRecursiveCond (v: !  nixpkgs.lib.options.isOption v)
      (k: v: {
        type = v.type.name;
      default = v.default;
      description = if v ? description then v.description else null;
      example = if v ? example then v.example else null;
     })
     options;

  # Function to get options from module(s)
  getOpts = modules:
   builtins.removeAttrs (nixpkgs.lib.evalModules {
     inherit modules;
     specialArgs = { inherit nixpkgs; };
   }).options [ "_module" ];
in
{
  # Module option exports for the frontend
  # Accessible through 'nix eval --json .#exports'
  exports = parseOpts (getOpts [
   ./modules/homestakeros/options.nix
  ]);
}
```

</details>

So, the initial step is fetching those module options and it is done like this:

```shell
nix eval --json github:ponkila/nixobolus#exports.homestakeros | jq -r '.[]'
```

The resulting data is saved at `webui/public/schema.json`.

### 2. Update JSON Files

Next, the `update-json` script will be executed.
If there are already configured hosts before initializing the web server, this script retrieves the hostnames of those hosts and obtains a JSON-formatted version of the configurations for each of them.
All of this data is saved under the `webui/public/nixosConfigurations` directory.

Here is how the script retrieves the hostnames using the `attrNames` built-in function:

```shell
nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]'
```

And here is how the configuration data is retrieved:

```shell
nix eval --json .#nixosConfigurations."$hostname".config.homestakeros | jq -r '.[]'
```

### 3. Frontend

I'm not gonna lie, I don't know much about what's happening with the frontend.
However, the following commands are going to be executed and essentially, the web server is built and launched, making it accessible at <http://localhost:8081>.

```shell
yarn install && yarn build
```

```shell
nix run .#homestakeros
```

Additionally, a "First In, First Out" (FIFO) file named "pipe" is created, which I will explain shortly.

And that's it — we have the HomestakerOS web UI up and running.
The web UI should display a configuration option form that is dynamically generated based on the schema retrieved earlier.

## Build Process

Here is where things get interesting.
In this section, I'll explain what happens in the background when the user submits the form payload containing the host configuration by clicking the `#BUIDL` button to build the host.

### 1. Execution via "pipe"

The frontend appends a string that represents a command to the FIFO file:

```shell
echo '${JSON.stringify(homestakerConfig)}' | nix run .#buidl -- -n '${hostname}' -b homestakeros\n
```

The variable `homestakerConfig` contains the form payload with the configured module options defined via the user interface.

The background process running the following command constantly reads the FIFO file and redirects its contents into a shell to be executed.

```
tail -f pipe | sh
```

### 2. JSON to Nix Conversion

Now that the frontend has initialized the build process, the `buidl` script takes the provided JSON data and converts it into a Nix expression file using the `json2nix` script.
The script will escape the double quotes in the JSON data and convert it to a Nix expression like this:

```
nix-instantiate --eval --expr "builtins.fromJSON \"$esc_json_data\""
```

The output of this is saved to `nixosConfigurations/"$hostname"/default.nix`.

### 3. Nix build

Then, the host is built as the script runs the following command:

```shell
nix build .#nixosConfigurations."$hostname".config.system.build."$format"
```

The media boot files are generated in a result folder under the host directory, which will be located at `webui/public/nixosConfigurations/"$hostname"/result`.

### 4. Update JSON Files

Finally, the `update-json` script is run to conclude the process, which is the exact same procedure as in the web server initialization process.

## Thats it

A few of words about the dynamic aspect of this before it's time to say goodbye: if you are familiar with Nix and flakes, you probably have some hard-coded variables in your flake for all of your hosts.
Since we want the user to be able to define the hostname, we use a map function to read all the directory names within the `nixosConfigurations` directory and map them as the hostnames.

<details>

<summary>A snippet from the HomestakerOS' flake</summary>
<br/>

See the whole thing at: <https://github.com/ponkila/HomestakerOS/blob/main/flake.nix>

```nix
nixosConfigurations = let
    ls = builtins.readDir ./nixosConfigurations;
    hostnames =
      builtins.filter
      (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
      (builtins.attrNames ls);
  in
    nixpkgs.lib.mkIf (
      builtins.pathExists ./nixosConfigurations
    ) (
      builtins.listToAttrs (map (hostname: {
          name = hostname;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {inherit inputs outputs;};
            modules =
              [
                nixobolus.nixosModules.kexecTree
                nixobolus.nixosModules.homestakeros
                ./nixosConfigurations/${hostname}
                {
                  system.stateVersion = "23.05";
                  # Bootloader for x86_64-linux / aarch64-linux
                  boot.loader.systemd-boot.enable = true;
                  boot.loader.efi.canTouchEfiVariables = true;
                }
              ];
          };
        })
        hostnames)
    );
```

</details>

There is still work to do regarding the ability to define the system architecture and output format of the boot media files.

~ **[Tupakkatapa](https://github.com/tupakkatapa)**
