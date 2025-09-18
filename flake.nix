{
  description = "Yottanami's NixOS configuration";

  inputs = {
    # NixOS official package source
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url  = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.yottawork = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
      ];
      specialArgs = { inherit inputs; }; # Pass inputs to configuration.nix
    };
  };
}
