{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "yottapersonal";

  # HiDPI: panel is ~323 DPI (3840x2400 on ~14"). Set X DPI so the greeter and
  # all X11/EXWM sessions scale to a readable size instead of native 96 DPI.
  services.xserver.dpi = 192; # exact 2x of 96

  # HiDPI: larger console (TTY) font and X cursor so they aren't tiny.
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
  environment.variables.XCURSOR_SIZE = "48";

  services.desktopManager.gnome.enable = true;

  services.xserver.xkb.layout = "usnum,ir";
  services.xserver.xkb.options = "grp:alt_caps_toggle,lv3:ralt_switch";
  # Custom "us" with numbers on the QWERTY row via Right Alt (broken number row).
  # Right Alt + Q W E R T Y U I O P        -> 1 2 3 4 5 6 7 8 9 0
  # Right Alt + Shift + Q W E R T Y U I O P -> ! @ # $ % ^ & * ( )
  services.xserver.xkb.extraLayouts.usnum = {
    description = "US with number layer on QWERTY (Right Alt)";
    languages = [ "eng" ];
    symbolsFile = ../../xkb/usnum.xkb;
  };
}
