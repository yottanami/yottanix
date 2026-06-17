{ config, pkgs, lib, inputs, ... }:

let
  xautolockLocker = pkgs.writeShellScript "xautolock-locker" ''
    exec ${pkgs.lightdm}/bin/dm-tool lock
  '';

  xautolockCleanup = pkgs.writeShellScript "xautolock-cleanup" ''
    ${pkgs.procps}/bin/pkill xautolock || true
  '';

  audientMonitor = pkgs.writeShellApplication {
    name = "audient-monitor";
    runtimeInputs = with pkgs; [ pipewire gnugrep ];
    text = ''
      set -euo pipefail

      if [[ $# -ne 1 || ( "$1" != "on" && "$1" != "off" ) ]]; then
        echo "usage: audient-monitor on|off" >&2
        exit 1
      fi

      capture_prefix="alsa_input.usb-Audient_Audient_iD14-00.pro-input-0:capture_AUX"
      playback_ports=(
        "alsa_output.usb-Audient_Audient_iD14-00.pro-output-0:playback_AUX0"
        "alsa_output.usb-Audient_Audient_iD14-00.pro-output-0:playback_AUX1"
      )

      capture_ports=()
      available_ports="$(${pkgs.pipewire}/bin/pw-link -o)"

      for index in 0 1 2 3 4 5 6 7 8 9 10 11; do
        port="''${capture_prefix}''${index}"
        if printf '%s\n' "$available_ports" | grep -qxF "$port"; then
          capture_ports+=("$port")
        fi
      done

      if [[ ''${#capture_ports[@]} -eq 0 ]]; then
        echo "No Audient iD14 capture ports were found." >&2
        exit 1
      fi

      # With ADAT attached the iD14 exposes 12 capture channels:
      # 10 physical inputs followed by 2 loopback channels.
      if [[ ''${#capture_ports[@]} -ge 12 ]]; then
        capture_ports=("''${capture_ports[@]:0:10}")
      fi

      pw_link_args=()
      if [[ "$1" == "off" ]]; then
        pw_link_args=(-d)
      fi

      for capture_port in "''${capture_ports[@]}"; do
        for playback_port in "''${playback_ports[@]}"; do
          ${pkgs.pipewire}/bin/pw-link "''${pw_link_args[@]}" "$capture_port" "$playback_port" || true
        done
      done
    '';
  };

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
  networking.hostId = "8425e349";
  networking.networkmanager.enable = true;
  # Allow the dev backend (uvicorn :8000) to be reached from a phone on the LAN.
  networking.firewall.allowedTCPPorts = [ 8000 ];

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

  users.groups.realtime = { };

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
      flameshot
      jetbrains.idea
      kicad-small
      firefox
      typescript
      typescript-language-server
      svelte-language-server
      antlr4
      teensy-udev-rules
      teensy-loader-cli
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

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "plexamp"
      "slack"
      "teensy-udev-rules"
      "teensyduino"
      "idea-ultimate"
      "unrar"
      "zoom"
      "cursor"
      "terraform"
      "postman"
      "via"
      "spotify"
    ];

  nixpkgs.config.allowUnfree = true;

  environment.sessionVariables = {
    NOTEDITOR_WM_PATH = "/home/yottanami/src/personal/noteditor/";
  };

  environment.systemPackages = with pkgs; [
    wget
    emacs
    pcmanfm
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
    claude-code
    ntfs3g
    mixid
    # `adb` for Flutter on-device dev. systemd (>=258) sets udev uaccess rules
    # automatically, so no `programs.adb`/`adbusers` group is needed anymore.
    android-tools
  ];

  programs.udevil.enable = true;
  programs.nix-ld.enable = true;
  programs.java.enable = true;

  programs.fish = {
    enable = true;
    shellAliases = {
      monitor-on = "${audientMonitor}/bin/audient-monitor on";
      monitor-off = "${audientMonitor}/bin/audient-monitor off";
    };
  };

  services.udev.packages = [ pkgs.via pkgs.teensy-udev-rules ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="2708", MODE="0660", GROUP="audio"
  '';

  nixpkgs.overlays = [
    (final: prev: {
      udevil = prev.udevil.overrideAttrs (_: {
        postInstall = ''
          sed -i 's/^allowed_types =.*/allowed_types = $KNOWN_FILESYSTEMS, file, cifs, nfs, curlftpfs, ftpfs, sshfs, davfs/' \
            $out/etc/udevil/udevil.conf
        '';
      });
    })

    (final: prev: {
      mixid = prev.stdenv.mkDerivation rec {
        pname = "mixid";
        version = "0.1.6";

        src = prev.fetchFromGitHub {
          owner = "TheOnlyJoey";
          repo = "MixiD";
          rev = version;
          hash = "sha256-IGiwnODVJ8TOrBVb+AkZGvY+yUgKCcAB/oMqsvRTD5A=";
        };

        imguiSrc = prev.fetchFromGitHub {
          owner = "ocornut";
          repo = "imgui";
          rev = "v1.92.4";
          hash = "sha256-DyQ2fh749S41UFdLto7TtxsnBsd7CBzAUFq36LeZZ5Y=";
        };

        nativeBuildInputs = with prev; [
          cmake
          pkg-config
        ];

        buildInputs = with prev; [
          glfw
          glew
          libusb1
          libGL
          libx11
          libxcursor
          libxi
          libxinerama
          libxrandr
          wayland
        ];

        cmakeFlags = [
          "-DLIBUSB_INCLUDE_DIR=${prev.libusb1.dev}/include/libusb-1.0"
          "-DLIBUSB_INCLUDE_DIRS=${prev.libusb1.dev}/include/libusb-1.0"
          "-DLIBUSB_LIBRARIES=${prev.libusb1}/lib/libusb-1.0.so"
        ];

        postPatch = ''
          substituteInPlace CMakeLists.txt \
            --replace-fail \
              'URL https://github.com/ocornut/imgui/archive/refs/tags/v1.92.4.tar.gz' \
              'SOURCE_DIR ${imguiSrc}'
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 MixiD $out/bin/MixiD
          ln -s $out/bin/MixiD $out/bin/mixid
          runHook postInstall
        '';

        meta = with prev.lib; {
          description = "Unofficial Linux control panel for Audient iD interfaces";
          homepage = "https://github.com/TheOnlyJoey/MixiD";
          license = licenses.mit;
          platforms = platforms.linux;
          mainProgram = "mixid";
        };
      };
    })
  ];

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

  # sops = {
  #   defaultSopsFile = ./secrets/openrouter.yaml;
  #   age.keyFile = "/var/keys/host.agekey";
  #   secrets.OPENROUTER_API_KEY = { };
  # };
  # environment.sessionVariables.OPENROUTER_API_KEY =
  #   config.sops.secrets.OPENROUTER_API_KEY;

  system.stateVersion = "24.06";
}
