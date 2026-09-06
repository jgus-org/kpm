{ mkKpackage, fetchurl }:
[
  (mkKpackage {
    id = "updateblockstatus";
    name = "UpdateBlock Status";
    author = "Neura, Dammit Jeff";
    description = "Display OTA update blocker status";
    version = [
      1
      1
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://raw.githubusercontent.com/KindleTweaks/Repository/512437b4bcb2d9994dedd52feb2f0c7b4c426344/UpdateBlockStatus/assets/updateblock.sh";
      hash = "sha256-npzBAVnt8Br9xrSI9QJqUPfbukuwpGKgkkldh9+gVLQ=";
    };
    buildPayload = ''
      mkdir -p payload
      cp "''${SOURCE}" payload/updateblock.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' "''${SOURCE}" | base64 -d > payload/updateblock.png
      mkdir scriptlets
      {
        sed -n '/^# Icon: data:image\/png;base64,/p' "''${SOURCE}"
        printf '%s\n' '# DontUseFBInk' 'exec /var/local/kmc/bin/kpm launch updateblockstatus'
      } > scriptlets/updateblock.sh
    '';
    scriptlet = {
      name = "updateblock.sh";
      icon = "payload/updateblock.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall.sh;
    launchScript = ./launch.sh;
  })
]
