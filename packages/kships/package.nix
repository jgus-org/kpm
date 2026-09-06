{ mkKpackage, fetchurl, writeTextFile }:
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
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://github.com/LOT-PL/KShips/releases/download/1.5.6/KShips.zip";
      hash = "sha256-j88Nl9hsJUxYohUXHQTCkAHdAg8oes4XNUVANaNPnrE=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
    '';
    payloadDirectory = "payload/KShips";
    mesquiteDirectory = "/var/local/mesquite/KShips";
    appId = "xyz.lotpl.kships";
    scriptletName = "KShips.sh";
    legacyPaths = [
      "/mnt/us/documents/KShips"
      "/mnt/us/documents/KShips.sh"
    ];
  })
]
