{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./noteditor.nix
    inputs.sops-nix.nixosModules.sops 
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "yottawork";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Amsterdam";

  services.openssh.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.xserver.enable = true;
  services.xserver.windowManager.noteditor.enable = true;
  services.xserver.windowManager.exwm.enable = true;  
  services.xserver.xkb.layout = "us,ir";
  ##  services.xserver.xkb.options = "ctrl:swapcaps,grp:alt_caps_toggle";
  services.xserver.xkb.options = "grp:alt_caps_toggle";

  systemd.user.services.xautolock = {
    description = "Start xautolock with cleanup";
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.procps}/bin/pkill xautolock || true";
      ExecStart = "${pkgs.xautolock}/bin/xautolock -time 10 -locker 'dm-tool lock'";
      Restart = "always";
    };
    wantedBy = [ "default.target" ];
  };

  # Provides a standard interface for devices like touchpads, mice, and keyboards
  services.libinput.enable = true;
  
  # Allows unprivileged users to set their processes to run with real-time priority, which is necessary for pipewire
  security.rtkit.enable   = true;

  services.pipewire = {
    enable          = true;
    jack.enable     = true;
    alsa.enable     = true;
    alsa.support32Bit = true;
    pulse.enable    = true;
  };

  users.groups.realtime = {};

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable           = true;
    setSocketVariable = true;
  };

  services.printing.enable = true;

  # Enable Avahi service for network discovery
  services.avahi = {
    enable       = true;
    nssmdns4     = true;
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
    shell        = pkgs.fish;
    extraGroups  = [ "wheel" "audio" "realtime" "networkmanager" "docker" ];
    packages     = with pkgs; [
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
      awscli2
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
      terraform-docs
      terraform-ls
      pre-commit
      postman
      aider-chat-full
      spotify 
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
  ];

  programs.udevil.enable = true;
  programs.fish.enable   = true;
  programs.nix-ld.enable = true;

  programs.java = { enable = true; };

  services.udev.packages = [ pkgs.via pkgs.teensy-udev-rules ];

  nixpkgs.overlays = [
    (final: prev: {
      udevil = prev.udevil.overrideAttrs (_: {
        postInstall = ''
          sed -i 's/^allowed_types =.*/allowed_types = $KNWON_FILESYSTEMS, file, cifs, nfs, curlftpfs, ftpfs, sshfs, davfs/' \
            $out/etc/udevil/udevil.conf
        '';
      });
    })
  ];

  services.logind.extraConfig = ''
    HandleLidSwitch=suspend-then-hibernate
    HandleLidSwitchExternalPower=suspend-then-hibernate
    HandleLidSwitchDocked=ignore
    LidSwitchIgnoreInhibited=yes
  '';

  services.hardware.bolt.enable  = true;
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;

  ## REMOVE ME
  # hardware.enableAllFirmware = true;
  # hardware.enableRedistributableFirmware = true;
  # nixpkgs.config.allowUnfree = true;

  systemd.user.services.mpris-proxy = {
    description   = "Mpris proxy";
    after         = [ "network.target" "sound.target" ];
    wantedBy      = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  system.autoUpgrade = {
    enable  = true;
    flake   = inputs.self.outPath;
    flags   = [ "--update-input" "nixpkgs" "-L" ];
    dates   = "02:00";
    randomizedDelaySec = "45min";
  };


  ########################################
  ##  SOPS‑NIX: secrets → env‑file
  ########################################

  # sops = {
  #   defaultSopsFile = ./secrets/openrouter.yaml;
  #   age.keyFile     = "/var/keys/host.agekey";
  #   secrets.OPENROUTER_API_KEY = { };
  # };

  # # export to every new login shell
  # environment.sessionVariables.OPENROUTER_API_KEY =
  #   config.sops.secrets.OPENROUTER_API_KEY;
  system.stateVersion = "24.14";
}
