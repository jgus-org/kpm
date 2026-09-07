{ mkKpackage
, fetchurl
, writeTextFile
,
}:
let
  mkWafPackage = import ../../lib/mk-waf-package.nix { inherit mkKpackage writeTextFile; };
in
[
  (mkWafPackage {
    id = "kships";
    name = "KShips";
    author = "LOT_PL";
    description = "Battleship for Kindle";
    version = [
      1
      5
      6
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/LOT-PL/KShips/releases/download/1.5.6/KShips.zip";
      hash = "sha256-j88Nl9hsJUxYohUXHQTCkAHdAg8oes4XNUVANaNPnrE=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
      unzip -p "''${SOURCE}" KShips.sh \
        | sed -n 's|^# Icon: data:image/png;base64,||p' \
        | base64 -d > payload/kships-cover.png
    '';
    payloadDirectory = "payload/KShips";
    mesquiteDirectory = "/var/local/mesquite/KShips";
    appId = "xyz.lotpl.kships";
    scriptletName = "KShips.sh";
    scriptletIcon = {
      path = "payload/kships-cover.png";
      mediaSubtype = "png";
    };
    legacyPaths = [
      "/mnt/us/documents/KShips"
      "/mnt/us/documents/KShips.sh"
    ];
    passthru.consumer.cases = {
      kindlehf.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.lotpl.kships' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
      kindlepw2.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.lotpl.kships' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
    };
  })
]
