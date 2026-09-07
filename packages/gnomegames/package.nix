{ mkKpackage, mkNativePackage, fetchurl }:

let
  native = mkNativePackage {
    id = "gnomegames";
    displayName = "Gnome Games Suite";
    destination = "/mnt/us/extensions/gnomegames";
    payloadPath = "payload/gnomegames";
    scriptlets = [
      {
        source = "scriptlets/GnomeChess.sh";
        destination = "/mnt/us/documents/GnomeChess.sh";
      }
      {
        source = "scriptlets/GnomeMines.sh";
        destination = "/mnt/us/documents/GnomeMines.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "gnomegames";
    name = "Gnome Games Suite";
    author = "CrazyElectron";
    description = "Chess and Mines games for Kindle";
    version = [
      1
      1
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://github.com/crazy-electron/GnomeGames4Kindle/releases/download/v1.1/gnomegames.zip";
      hash = "sha256-OsAZvMomNNDMaMoUFGLqomzzV+4SR8AJn+qTn3SWlEg=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d payload
      sed -n '1,6p' payload/gnomegames/shortcut_gnomechess.sh > scriptlets/GnomeChess.sh
      printf '%s\n' 'exec /var/local/kmc/bin/kpm launch gnomegames chess' >> scriptlets/GnomeChess.sh
      sed -n '1,6p' payload/gnomegames/shortcut_gnomine.sh > scriptlets/GnomeMines.sh
      printf '%s\n' 'exec /var/local/kmc/bin/kpm launch gnomegames mines' >> scriptlets/GnomeMines.sh
      ${native.buildInventory}
    '';
    passthru.native = native.passthru;
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
