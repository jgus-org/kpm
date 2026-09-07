{ mkKpackage, mkNativePackage, fetchurl }:

let
  native = mkNativePackage {
    id = "gambatte-k2";
    displayName = "Gambatte-K2";
    destination = "/mnt/us/extensions/gambatte-k2";
    payloadPath = "payload/gambatte-k2";
    preservedPaths = [ "config.ini" ];
    scriptlets = [
      {
        source = "scriptlets/GambatteK2.sh";
        destination = "/mnt/us/documents/GambatteK2.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "gambatte-k2";
    name = "Gambatte-K2";
    author = "CrazyElectron";
    description = "Game Boy and Game Boy Color emulator";
    version = [
      1
      0
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://github.com/crazy-electron/gambatte-k2/releases/download/1.0/gambatte-k2.zip";
      hash = "sha256-fy4G34Ky+C3PUYWN+OzcqUCu10F+pnFEA8bFZ9lcNaY=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d payload
      sed -n '1,6p' payload/gambatte-k2/shortcut_gambatte-k2.sh > scriptlets/GambatteK2.sh
      printf '%s\n' 'exec /var/local/kmc/bin/kpm launch gambatte-k2' >> scriptlets/GambatteK2.sh
      ${native.buildInventory}
    '';
    scriptlet = {
      name = "GambatteK2.sh";
      path = "scriptlets/GambatteK2.sh";
      icon = null;
    };
    passthru.native = native.passthru;
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
