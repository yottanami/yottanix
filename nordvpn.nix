# ./nordvpn.nix
{ config, lib, pkgs, ... }:

let
  # This derivation packages the NordVPN CLI client from its .deb file.
  nordVpnPkg = pkgs.callPackage ({
    autoPatchelfHook,
    buildFHSEnvChroot,
    dpkg,
    fetchurl,
    lib,
    stdenv,
    sysctl,
    iptables,
    iproute2,
    procps,
    cacert,
    libxml2,
    libidn2,
    zlib,
    wireguard-tools,
  }: let
    pname = "nordvpn";
    version = "3.19.0"; # Updated version

    nordVPNBase = stdenv.mkDerivation {
      inherit pname version;

      src = fetchurl {
        url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn_${version}_amd64.deb";
        # Updated hash for version 3.19.0
        hash = "sha256-o6hE8G3lS97Ouy1bM+oD+iIOM9oY+0kQn0A1k+sP2zU=";
      };

      buildInputs = [ libxml2 libidn2 ];
      nativeBuildInputs = [ dpkg autoPatchelfHook stdenv.cc.cc.lib ];

      dontConfigure = true;
      dontBuild = true;

      unpackPhase = ''
        runHook preUnpack
        dpkg --extract $src .
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        mv usr/* $out/
        mv var/ $out/
        mv etc/ $out/
        runHook postInstall
      '';
    };

    # The NordVPN daemon requires a FHS environment to function correctly.
    nordVPNfhs = buildFHSEnvChroot {
      name = "nordvpnd";
      runScript = "nordvpnd";

      targetPkgs = pkgs: [
        nordVPNBase
        sysctl
        iptables
        iproute2
        procps
        cacert
        libxml2
        libidn2
        zlib
        wireguard-tools
      ];
    };
  in
    stdenv.mkDerivation {
      inherit pname version;
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin $out/share
        ln -s ${nordVPNBase}/bin/nordvpn $out/bin
        ln -s ${nordVPNfhs}/bin/nordvpnd $out/bin
        ln -s ${nordVPNBase}/share/* $out/share/
        ln -s ${nordVPNBase}/var $out/
        runHook postInstall
      '';

      meta = with lib; {
        description = "Official CLI client for NordVPN";
        homepage = "https://www.nordvpn.com";
        license = licenses.unfreeRedistributable;
        maintainers = with maintainers; [ ]; # Not maintained in nixpkgs
        platforms = [ "x86_64-linux" ];
      };
    }) { };
in
with lib; {
  options.services.nordvpn.enable = mkOption {
    type = types.bool;
    default = false;
    description = ''
      Whether to enable the NordVPN daemon.
      Note that you must add your user to the "nordvpn" group.
    '';
  };

  config = mkIf config.services.nordvpn.enable {
    # 1. Allow unfree packages for NordVPN
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [ "nordvpn" ];

    # 2. Add the nordvpn package to the system
    environment.systemPackages = [ nordVpnPkg ];

    # 3. Required firewall setting for NordVPN
    networking.firewall.checkReversePath = false;

    # 4. Create the 'nordvpn' group
    users.groups.nordvpn = { };

    # 5. Define the systemd service for the NordVPN daemon
    systemd.services.nordvpn = {
      description = "NordVPN daemon.";
      serviceConfig = {
        ExecStart = "${nordVpnPkg}/bin/nordvpnd";
        # This script ensures the state directory exists and is populated on first run
        ExecStartPre = pkgs.writeShellScript "nordvpn-start" ''
          mkdir -m 700 -p /var/lib/nordvpn;
          if [ -z "$(ls -A /var/lib/nordvpn)" ]; then
            cp -r ${nordVpnPkg}/var/lib/nordvpn/* /var/lib/nordvpn;
          fi
        '';
        NonBlocking = true;
        KillMode = "process";
        Restart = "on-failure";
        RestartSec = 5;
        RuntimeDirectory = "nordvpn";
        RuntimeDirectoryMode = "0750";
        Group = "nordvpn";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
