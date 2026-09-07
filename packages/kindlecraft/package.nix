{ mkKpackage, mkNativePackage, fetchurl }:

let
  revision = "13370ad3a36cd526270a9bc5a942bdf6ea1869d2";
  license = fetchurl {
    url = "https://raw.githubusercontent.com/gingrspacecadet/bareiron/${revision}/LICENSE";
    hash = "sha256-OXLcl0T2SZ8Pmy2/dmlvKuetivmyPd5m1q+Gyd+zaYY=";
  };
  native = mkNativePackage {
    id = "kindlecraft";
    displayName = "KindleCraft";
    destination = "/mnt/us/extensions/kindlecraft";
    payloadPath = "payload/kindlecraft";
    scriptlets = [
      {
        source = "scriptlets/KindleCraft.sh";
        destination = "/mnt/us/documents/KindleCraft.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "kindlecraft";
    name = "KindleCraft";
    author = "p2r3 and gingrspacecadet";
    description = "Minimal Minecraft Java Edition server";
    version = [
      1
      21
      8
    ];
    platforms = [ "kindlehf" ];
    src = fetchurl {
      url = "https://raw.githubusercontent.com/gingrspacecadet/bareiron/${revision}/cross";
      hash = "sha256-lN1wswxwzEwCvhhDcjxERdyqvgI9K5liTklf0moZhZQ=";
    };
    buildPayload = ''
      mkdir -p payload/kindlecraft scriptlets
      cp "''${SOURCE}" payload/kindlecraft/kindlecraft
      cp ${license} payload/kindlecraft/LICENSE
      chmod 755 payload/kindlecraft/kindlecraft
      printf '%s\n' \
        '# Name: KindleCraft' \
        '# Author: p2r3' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch kindlecraft' \
        > scriptlets/KindleCraft.sh
      ${native.buildInventory}
    '';
    scriptlet = {
      name = "KindleCraft.sh";
      path = "scriptlets/KindleCraft.sh";
      icon = null;
    };
    passthru.native = native.passthru;
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
