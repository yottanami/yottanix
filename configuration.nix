{ config, pkgs, lib, inputs, ... }:

let
  xautolockLocker = pkgs.writeShellScript "xautolock-locker" ''
    exec ${pkgs.lightdm}/bin/dm-tool lock
  '';

  xautolockCleanup = pkgs.writeShellScript "xautolock-cleanup" ''
    ${pkgs.procps}/bin/pkill xautolock || true
  '';

  bluezWithCodecs = pkgs.bluezFull or pkgs.bluez;

in {
  imports = [
    ./hardware-configuration.nix
    ./noteditor.nix
    inputs.sops-nix.nixosModules.sops
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];


  networking.hostName = "yottawork";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  services.openssh.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.xserver.enable = true;
  services.xserver.windowManager.noteditor.enable = true;
  services.xserver.windowManager.exwm.enable = true;
  services.xserver.xkb.layout = "us,ir";
  services.xserver.xkb.options = "grp:alt_caps_toggle";

  systemd.user.services.xautolock = {
    description = "Start xautolock with cleanup";
    after = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = xautolockCleanup;
      ExecStart = "${pkgs.xautolock}/bin/xautolock -time 10 -locker ${xautolockLocker}";
      Restart = "always";
    };
  };

  services.libinput.enable = true;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
  };

  users.groups.realtime = {};

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  services.printing.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      vazir-fonts
    ];
  };

  users.users.yottanami = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "audio" "realtime" "networkmanager" "docker" "dialout" ];
    packages = with pkgs; [
      graphviz
      plantuml
      vlc
      audacity
      gimp
      alacritty
      libreoffice
      brave
      git
      gh
      jq
      k9s
      pavucontrol
      musescore
      prusa-slicer
      blender
      plexamp
      kubectl
      saml2aws
      slack
      helvum
      flameshot
      jetbrains.idea-ultimate
      kicad-small
      firefox
      typescript
      typescript-language-server
      svelte-language-server
      antlr4
      teensy-udev-rules
      libnotify
      zoom-us
      maven
      pianobooster
      tflint
      terraform
      terraform-ls
      pre-commit
      postman
      aider-chat-full
      spotify
      awscli2
    ];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "plexamp" "slack" "teensy-udev-rules" "teensyduino" "idea-ultimate" "unrar"
    "zoom" "cursor" "terraform" "postman" "via" "spotify"
  ];

  environment.sessionVariables = {
    NOTEDITOR_WM_PATH = "/home/yottanami/src/personal/noteditor/";
  };

  environment.systemPackages = with pkgs; [
    wget
    emacs
    spaceFM
    spice-gtk
    unzip
    unrar
    zip
    socat
    ffmpeg
    nodejs
    docker-compose
    python3
    python3Packages.pip
    platformio
    libuv
    cifs-utils
    xautolock
    system-config-printer
    ruby-lsp
    ruby
    rubyPackages.rubocop
    rubyPackages.rubocop-performance
    age
    htop
    nixd
    codex
    ntfs3g
  ];

  programs.udevil.enable = true;
  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.java.enable = true;

  services.udev.packages = [ pkgs.via pkgs.teensy-udev-rules ];

  # Keep your udevil overlay tweak
  nixpkgs.overlays = [
    (final: prev: {
      udevil = prev.udevil.overrideAttrs (_: {
        postInstall = ''
          sed -i 's/^allowed_types =.*/allowed_types = $KNOWN_FILESYSTEMS, file, cifs, nfs, curlftpfs, ftpfs, sshfs, davfs/' \
            $out/etc/udevil/udevil.conf
        '';
      });
    })
  ];

  # NEW: structured systemd-logind settings (replace old lidSwitch* + extraConfig)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
    LidSwitchIgnoreInhibited = true;
  };

  services.hardware.bolt.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = bluezWithCodecs;
  };
  services.blueman.enable = true;

  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/bluetooth.lua.d/51-high-quality.lua" ''
      bluez_monitor.properties = {
        ["bluez5.enable-sbc-xq"] = true;
        ["bluez5.enable-msbc"] = true;
        ["bluez5.enable-hw-volume"] = true;
        ["bluez5.default.profile"] = "a2dp-sink";
        ["bluez5.codecs"] = {
          "ldac", "aptx", "aptx_hd", "aac", "sbc_xq", "sbc"
        };
      }
    '')
  ];

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;

  systemd.user.services.mpris-proxy = {
    description = "Mpris proxy";
    after = [ "network.target" "sound.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [ "--update-input" "nixpkgs" "-L" ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  ## Uncomment once the secret file is staged.
  # sops = {
  #   defaultSopsFile = ./secrets/openrouter.yaml;
  #   age.keyFile = "/var/keys/host.agekey";
  #   secrets.OPENROUTER_API_KEY = { };
  # };
  # environment.sessionVariables.OPENROUTER_API_KEY =
  #   config.sops.secrets.OPENROUTER_API_KEY;

  system.stateVersion = "24.06";
}
