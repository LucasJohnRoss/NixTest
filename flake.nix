{
  description = "NixOS test-laptop configuration — Hyprland daily-driver trial (migrating from CachyOS)";

  # ---------------------------------------------------------------------------
  # INPUTS — every external source this configuration depends on.
  # Exact revisions are pinned in flake.lock (created on first build).
  # Update them all with:  nix flake update   (or: nh os switch --update)
  # ---------------------------------------------------------------------------
  inputs = {
    # Rolling package set — closest match to CachyOS/Arch.
    # For the stable release instead, use "github:NixOS/nixpkgs/nixos-26.05"
    # and change home-manager below to "github:nix-community/home-manager/release-26.05".
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Make Home Manager use *our* nixpkgs instead of downloading its own copy.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Flatpak management (imported in home/home.nix, section 10).
    # `latest` always points at the newest stable release (v0.8.0 at time of writing).
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  # ---------------------------------------------------------------------------
  # OUTPUTS — what this flake builds.
  # ---------------------------------------------------------------------------
  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";

      # ---- EDIT THESE ---------------------------------------------------------
      # Single source of truth for personal values. Passed to every module as
      # `vars`, so you never have to hunt through files to change your username.
      vars = rec {
        username = "lucas"; # your login name
        fullName = "Lucas Ross"; # used for the account description and git
        email = "lucasross72@outlook.com"; # used for git
        hostname = "nixos-test"; # machine name; also the flake output name
        timezone = "Europe/London";
        locale = "en_GB.UTF-8";
        keyboardLayout = "gb";
        # Where this repo lives once installed (used for dotfile symlinks and `nh`)
        flakeDir = "/home/${username}/nixos-config";
      };
      # -------------------------------------------------------------------------
    in
    {
      # `sudo nixos-rebuild switch --flake .#nixos-test` builds this.
      nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
        # Extra arguments made available to every NixOS module
        specialArgs = { inherit inputs vars; };

        modules = [
          ./hosts/test-laptop/configuration.nix

          # Home Manager running as a NixOS module: one `nixos-rebuild switch`
          # updates the system AND your user environment together.
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true; # share the system's nixpkgs (and allowUnfree)
              useUserPackages = true; # install user packages into /etc/profiles
              backupFileExtension = "hm-backup"; # rename clashing files instead of failing
              extraSpecialArgs = { inherit inputs vars; };
              users.${vars.username} = import ./home/home.nix;
            };
          }
        ];
      };

      # `nix fmt` formats every .nix file in the repo
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
