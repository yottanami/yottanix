{
  description = "Yottanami's NixOS configuration";

  inputs = {
    # NixOS official package source
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url  = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    noteditor.url = "path:/home/yottanami/src/personal/noteditor";
    noteditor.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      mkHost = hostPath: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ hostPath ];
        specialArgs = { inherit inputs; }; # Pass inputs to host modules
      };
    in {
      nixosConfigurations = {
        yottapersonal = mkHost ./hosts/yottaPersonal;
        yottawork = mkHost ./hosts/yottaWork;
      };
    };
}
