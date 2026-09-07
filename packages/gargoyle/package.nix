{ mkKpackage, fetchurl }:

let
  hfSource = fetchurl {
    url = "https://www.mobileread.com/forums/attachment.php?attachmentid=214325&d=1741982302";
    hash = "sha256-f+lYojl0pTqoTNNQpE2npyF60C2L3JsCkhZb12yAzTk=";
  };
in

[
  (mkKpackage {
    id = "gargoyle";
    name = "Gargoyle";
    author = "Barna, Pete330";
    description = "Text adventure interpreter";
    version = [
      0
      1
      0
    ];
    platforms = [ "kindlehf" ];
    src = hfSource;
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
      rm payload/gargoyle/dist/libm.so.6
      mkdir scriptlets
      {
        printf '%s\n' \
          '# Icon: /mnt/us/extensions/gargoyle/gargoyle.png' \
          '# DontUseFBInk' \
          'exec /var/local/kmc/bin/kpm launch gargoyle'
      } > scriptlets/Gargoyle.sh
    '';
    scriptlet = {
      name = "Gargoyle.sh";
      icon = "payload/gargoyle/gargoyle.png";
      installedIcon = "/mnt/us/extensions/gargoyle/gargoyle.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall-hf.sh;
    launchScript = ./launch.sh;
  })
  (mkKpackage {
    id = "gargoyle";
    name = "Gargoyle";
    author = "Barna, Pete330";
    description = "Text adventure interpreter";
    version = [
      0
      1
      0
    ];
    platforms = [ "kindlepw2" ];
    src = fetchurl {
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=168543&d=1545424119";
      hash = "sha256-co1Fv3SEwPnqTUKeiNmbIweQDVPZB5+jNqNHuh5u4ho=";
    };
    buildPayload = ''
      mkdir -p payload
      tar -xzf "''${SOURCE}" -C payload
      unzip -p "${hfSource}" gargoyle/gargoyle.png > payload/gargoyle/gargoyle.png
      mkdir scriptlets
      {
        printf '%s\n' \
          '# Icon: /mnt/us/extensions/gargoyle/gargoyle.png' \
          '# DontUseFBInk' \
          'exec /var/local/kmc/bin/kpm launch gargoyle'
      } > scriptlets/Gargoyle.sh
    '';
    scriptlet = {
      name = "Gargoyle.sh";
      icon = "payload/gargoyle/gargoyle.png";
      installedIcon = "/mnt/us/extensions/gargoyle/gargoyle.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall-sf.sh;
    launchScript = ./launch.sh;
  })
]
