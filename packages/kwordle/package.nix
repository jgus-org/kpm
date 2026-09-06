{ mkKpackage, fetchurl }:
let
  mkWafPackage = import ../../lib/mk-waf-package.nix { inherit mkKpackage; };
  legacySrc = fetchurl {
    url = "https://github.com/crizmo/KWordle/releases/download/v1.6.0/kwordle-legacy.zip";
    hash = "sha256-g86S+hziyaz1NjTxDrKx3hlPaOMUOv3vFjV+sp+WbDE=";
  };
in
[
  (mkWafPackage {
    id = "kwordle";
    name = "KWordle";
    author = "Kurizu";
    description = "Wordle for Kindle e-readers";
    version = [
      1
      6
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://github.com/crizmo/KWordle/releases/download/v1.6.0/kwordle.zip";
      hash = "sha256-XnRn7lWYkaNNf0oxrsKEDa53R3JV5ynC5RfoagPewyM=";
    };
    buildPayload = ''
      mkdir -p payload/modern
      unzip -q "''${SOURCE}" -d payload/modern
      unzip -q "${legacySrc}" -d payload/legacy
    '';
    payloadDirectory = "payload/modern/kwordle";
    legacyPayloadDirectory = "payload/legacy/kwordle";
    mesquiteDirectory = "/var/local/mesquite/kwordle";
    appId = "xyz.kurizu.kwordle";
  })
]
