{ config, pkgs, ... }:

let
  setDefaultSinkScript = ''
    #!/bin/bash
    # Set the default sink to your desired sink
    echo "Setting default sink to ProFX Mixer"
    pactl set-default-sink alsa_output.usb-LOUD_Technologies_Inc._ProFX-00.iec958-stereo
  '';
in {
  environment.etc."set_default_sink.sh".text = setDefaultSinkScript;
  environment.etc."set_default_sink.sh".mode = "0755";

  environment.etc."udev/rules.d/99-profx.rules".text = ''
    SUBSYSTEM=="sound", ACTION=="add", ATTR{idVendor}=="your_vendor_id", ATTR{idProduct}=="your_product_id", RUN+="/etc/set_default_sink.sh"
  '';

  systemd.services.udev-reload = {
    description = "Reload udev rules";
    after = [ "udev.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.udev}/bin/udevadm control --reload-rules; ${pkgs.udev}/bin/udevadm trigger";
    };
  };
}
