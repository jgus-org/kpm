{ mkKpackage, fetchurl }:
[
  (mkKpackage {
    id = "toggleads";
    name = "Toggle ADs";
    author = "Marek & Penguins";
    description = "Toggle Kindle advertisements";
    version = [
      1
      1
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://raw.githubusercontent.com/KindleTweaks/Repository/512437b4bcb2d9994dedd52feb2f0c7b4c426344/ToggleAds/assets/toggle-ads.sh";
      hash = "sha256-TsKUgSyv0Il40xyVxQ7K7zUtWGUeIcvMnY9f4HIHRgg=";
    };
    buildPayload = ''
      mkdir -p payload
      cp "''${SOURCE}" payload/toggle-ads.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' "''${SOURCE}" | base64 -d > payload/toggle-ads.png
      mkdir scriptlets
      {
        sed -n '/^# Icon: data:image\/png;base64,/p' "''${SOURCE}"
        printf '%s\n' '# DontUseFBInk' 'exec /var/local/kmc/bin/kpm launch toggleads'
      } > scriptlets/toggle-ads.sh
    '';
    scriptlet = {
      name = "toggle-ads.sh";
      icon = "payload/toggle-ads.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall.sh;
    launchScript = ./launch.sh;
  })
]
