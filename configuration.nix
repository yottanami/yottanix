{ config, pkgs, lib, ... }:

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
  
  # Enable the graphical interface
  services.xserver.enable = true;
  services.xserver.windowManager.noteditor.enable = true;
  services.xserver.windowManager.exwm.enable = true;	
  services.xserver.xkb.layout = "us,ir";
  ##  services.xserver.xkb.options = "ctrl:swapcaps,grp:alt_caps_toggle";
  services.xserver.xkb.options = "grp:alt_caps_toggle";

  services.xserver.displayManager.sessionCommands = ''
    # Start xautolock to automatically lock the screen after 5 minutes
    xautolock -time 10 -locker "i3lock" &
  '';

  # Provides a standard interface for devices like touchpads, mice, and keyboards
  services.libinput.enable = true;
  
  # Allows unprivileged users to set their processes to run with real-time priority, which is necessary for pipewire
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    jack.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    
    # extraConfig.pipewire = {
    #   "beep" = {
	  #  "context.properties" = {
    #          "module.x11.bell" = false; 
    #    	 };        
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
    enable = true;
    setSocketVariable = true;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable Avahi service for network discovery
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
    extraGroups = [ "wheel" "audio" "realtime" "networkmanager" "docker"];
    packages = with pkgs; [
      graphviz
      plantuml
      vlc
      audacity
      gimp
      alacritty
      librewolf
      brave
      git
      gh
      jq # JSON QUERY
      k9s
      pavucontrol
      musescore
      prusa-slicer
      plexamp
      kubectl
      awscli2
      saml2aws
      slack
      helvum # A GTK patchbay for pipewire.
      flameshot # Screenshot tooljdk21
      ffmpeg
      jetbrains.idea-ultimate
      #sonic-pi
      nixd # Nix daemon
      kicad-small # Electronic design automation software
      firefox
      playwright-driver.browsers # Playwright browser drivers
      typescript
      typescript-language-server
      svelte-language-server
      ruby-lsp
      antlr4
      teensy-udev-rules
      dunst
      libnotify
    ];
  };
  
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
 	  "plexamp" "slack" "teensy-udev-rules" "teensyduino" "idea-ultimate" "unrar"
  ];
  
  environment.sessionVariables = {
    NOTEDITOR_WM_PATH = "/home/yottanami/src/personal/noteditor/";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };


  environment.systemPackages = with pkgs; [
    #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    emacs
    spaceFM
    spice-gtk
    unzip
    unrar
    zip
    socat
    nodejs
    docker-compose
    python3
    python3Packages.pip
    platformio
    libuv
    cifs-utils
    vim
    xautolock
    pianobooster
  ];

  programs.udevil.enable = true;
  programs.fish.enable = true;
  programs.nix-ld.enable = true;
  programs.java.enable = true;

  services.udev.packages = [ pkgs.via pkgs.teensy-udev-rules];
  ## services.udev.
  ## pkgs.openocd
  ###  pkgs.teensy-udev-rules
  ## ];

  nixpkgs.overlays = [ (final: prev: {
    udevil = prev.udevil.overrideAttrs (old: {
      postInstall = ''
      sed -i 's/^allowed_types =.*/allowed_types = \$KNWON_FILESYSTEMS, file, cifs, nfs, curlftpfs, ftpfs, sshfs, davfs/' \
      $out/etc/udevil/udevil.conf
   '';
    });
  }) ];
  
  services.logind.extraConfig = ''
    HandleLidSwitch=suspend-then-hibernate
    HandleLidSwitchExternalPower=suspend-then-hibernate
    HandleLidSwitchDocked=ignore
    LidSwitchIgnoreInhibited=yes
  '';

  services.hardware.bolt.enable = true;
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  services.blueman.enable = true;
  systemd.user.services.mpris-proxy = { # Using Bluetooth headset buttons to control media player
    description = "Mpris proxy";
    after = [ "network.target" "sound.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
};

  
  system.stateVersion = "24.13";


}
