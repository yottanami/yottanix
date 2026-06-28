{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "yottawork";

  services.xserver.xkb.layout = "us,ir";
  services.xserver.xkb.options = "grp:alt_caps_toggle";
}
