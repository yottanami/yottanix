{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./noteditor.nix
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

  services.xserver.displayManager.sessionCommands = ''
    xautolock -time 10 -locker "i3lock" &
  '';

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

    # extraConfig.pipewire = {
    #   "beep" = {
         #  "context.properties" = {
    #          "module.x11.bell" = false;
    #           };
    #   };
    #   "adam" = {
    #     "context.modules" = [
    #     {
    #       "name" = "libpipewire-module-loopback";
    #       "args" = {
    #         "node.description" = "Adam speakers";
    #         "capture.props" = {
    #           "node.name" = "Adam_speakers";
    #           "media.class" = "Audio/Sink";
         #     "audio.position" = "[ FL FR ]";
    #         };
    #         "playback.props" = {
    #            "node.name" = "playback.Adam_Speakers";
    #            "audio.position" = "[ FL FR ]";
    #            "target.object" = "alsa_input.usb-LOUD_Technologies_Inc._ProFX-00.iec958-stereo";
    #            "stream.dont-remix" = "true";
    #            "node.passive" = "true";
    #         };
    #       };
    #    }
    #    {
    #      "name" = "libpipewire-module-loopback";
    #       "args" = {
    #         "node.description" = "Adam speakers";
    #         "capture.props" = {
    #           "media.class" = "Audio/Sink";
    #           "audio.position" = "[ FL FR ]";
    #         };
    #         "playback.props" = {
    #             "node.name" = "playback.Adam_Speakers";
    #             "audio.position" = "[ RL RR ]";
    #             "target.object" = "alsa_input.usb-LOUD_Technologies_Inc._ProFX-00.iec958-stereo";
    #             "stream.dont-remix" = "true";
    #             "node.passive" = "true";
    #           };
    #         };
    #       }
    #    ];
    #   };
    # };
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
      graphviz plantuml vlc audacity gimp alacritty libreoffice brave git gh jq
      k9s pavucontrol musescore prusa-slicer blender plexamp kubectl awscli2
      saml2aws slack helvum flameshot ffmpeg jetbrains.idea-ultimate nixd
      kicad-small firefox typescript typescript-language-server svelte-language-server
      ruby-lsp antlr4 teensy-udev-rules libnotify zoom-us maven pianobooster
      code-cursor terraform-ls terraform-docs tflint terraform pre-commit postman
    ];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "plexamp" "slack" "teensy-udev-rules" "teensyduino" "idea-ultimate" "unrar"
    "zoom" "cursor" "terraform" "postman" "via"
  ];

  environment.sessionVariables = {
    NOTEDITOR_WM_PATH = "/home/yottanami/src/personal/noteditor/";
  };

  environment.systemPackages = with pkgs; [
    wget  emacs  spaceFM  spice-gtk  unzip  unrar  zip  socat
    nodejs docker-compose python3 python3Packages.pip
    platformio libuv cifs-utils vim xautolock system-config-printer
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

  services.hardware.bolt.enable = true;
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;

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

  system.stateVersion = "24.13";
}
