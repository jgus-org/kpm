{ mkKpackage, mkNativePackage, fetchurl }:

let
  variants = [
    {
      platform = "kindlehf";
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=216964&d=1752870631";
      hash = "sha256-ZFZEmaiiRzsOUibB6JXMknsTHBVDKWDeW1K73Vcugnk=";
    }
    {
      platform = "kindlepw2";
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=216965&d=1752870631";
      hash = "sha256-lNz/GE16bEZo6lFtnxXKcF8x4uH18NFIFN6n0aYbAJc=";
    }
  ];
  makePackage =
    variant:
    let
      nativePackage = mkNativePackage {
        id = "sox";
        displayName = "SOX Media Player";
        destination = "/mnt/us/extensions/sox";
        payloadPath = "payload/sox";
        preservedPaths = [ "menu.json" ];
        scriptlets = [
          {
            source = "scriptlets/SOX.sh";
            destination = "/mnt/us/documents/SOX.sh";
          }
        ];
      };
    in
    mkKpackage {
      id = "sox";
      name = "SOX Media Player";
      author = "Dhdurgee";
      description = "Bluetooth and USB audio player";
      version = [
        3
        0
        0
      ];
      platforms = [ variant.platform ];
      src = fetchurl {
        inherit (variant) url hash;
      };
      buildPayload = ''
        mkdir -p payload scriptlets
        unzip -q "''${SOURCE}" -d unpacked
        mv unpacked/extensions/sox payload/sox
        chmod 755 payload/sox/*.sh payload/sox/sox payload/sox/soxi
        printf '%s\n' \
          '# Name: SOX Media Player' \
          '# DontUseFBInk' \
          'exec /var/local/kmc/bin/kpm launch sox' \
          > scriptlets/SOX.sh
        ${nativePackage.buildInventory}
      '';
      installScript = nativePackage.installScript;
      uninstallScript = nativePackage.uninstallScript;
      launchScript = ./launch.sh;
      scriptlet = {
        name = "SOX.sh";
        path = "scriptlets/SOX.sh";
        icon = null;
      };
      passthru.native = nativePackage.passthru;
    };
in
map makePackage variants
