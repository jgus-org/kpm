{ mkKpackage
, mkNativePackage
, fetchurl
, pkgs
,
}:

let
  license = fetchurl {
    url = "https://raw.githubusercontent.com/KindleTweaks/PEKI/179993e278869e81ae0377aa3855dd915de7dc57/LICENSE";
    hash = "sha256-E0mkthSEkrRPYp5k7tZ2YS4jT+moOeTzsnfBSCyISfE=";
  };
  native = mkNativePackage {
    id = "kual";
    displayName = "PEKI KUAL Installer";
    destination = "/mnt/us/documents/PEKI";
    payloadPath = "payload/PEKI";
    scriptlets = [
      {
        source = "scriptlets/PEKI-KUAL.sh";
        destination = "/mnt/us/documents/PEKI-KUAL.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "kual";
    name = "PEKI KUAL Installer";
    author = "KindleTweaks";
    description = "Install or launch KUAL through PEKI";
    version = [
      1
      0
      0
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/KindleTweaks/PEKI/releases/download/v1.0/PEKI.zip";
      hash = "sha256-9lMEWQntIwSWw9gXbJkB06ah9pPFK0iFab5qYOCFJJk=";
    };
    buildPayload = ''
      unzip -q "''${SOURCE}" -d unpacked
      mkdir -p payload/PEKI scriptlets
      cp unpacked/KUAL.jar payload/PEKI/KUAL.jar
      cp ${./peki.sh} payload/PEKI/peki.sh
      cp ${license} payload/PEKI/LICENSE
      {
        sed -n '1,5p' unpacked/KUAL.sh
        printf '%s\n' 'exec /var/local/kmc/bin/kpm launch kual'
      } > scriptlets/PEKI-KUAL.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' unpacked/KUAL.sh | base64 -d > payload/PEKI/icon.png
      chmod +x payload/PEKI/peki.sh
      ${native.buildInventory}
    '';
    scriptlet = {
      name = "PEKI-KUAL.sh";
      path = "scriptlets/PEKI-KUAL.sh";
      icon = "payload/PEKI/icon.png";
    };
    passthru = {
      native = native.passthru;
      tests.recovery = pkgs.runCommand "peki-recovery-check" { } ''
        sh ${./check-recovery.sh} ${./peki.sh}
        touch "''${out}"
      '';
    };
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
