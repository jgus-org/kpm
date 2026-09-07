{ mkKpackage
, mkNativePackage
, fetchurl
,
}:

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
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
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
    passthru = {
      native = native.passthru;
      consumer.cases = {
        kindlehf.launches = [
          {
            mode = "dispatch";
            args = [ "chess" ];
            boundaries = [ "Gnome Chess executable boundary" ];
            actualApplicationExecution = false;
            setup = ''
              TARGET=/mnt/us/extensions/gnomegames/bin/armhf/glchess
              test -x "''${TARGET}"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s %s\n" "''${PWD}" "''${GSETTINGS_SCHEMA_DIR}" "''${*}" > /var/lib/kpm-consumer/gnomegames.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/gnomegames.log
            '';
            verify = "grep -Fx -- '/mnt/us/extensions/gnomegames /mnt/us/extensions/gnomegames/share/glib-2.0/schemas ' /var/lib/kpm-consumer/gnomegames.log";
            cleanup = "mv /mnt/us/extensions/gnomegames/bin/armhf/glchess.kpm-consumer-original /mnt/us/extensions/gnomegames/bin/armhf/glchess";
          }
          {
            mode = "dispatch";
            args = [ "mines" ];
            boundaries = [ "Gnome Mines executable boundary" ];
            actualApplicationExecution = false;
            setup = ''
              TARGET=/mnt/us/extensions/gnomegames/bin/armhf/gnomine
              test -x "''${TARGET}"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s %s\n" "''${PWD}" "''${GSETTINGS_SCHEMA_DIR}" "''${*}" > /var/lib/kpm-consumer/gnomegames.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/gnomegames.log
            '';
            verify = "grep -Fx -- '/mnt/us/extensions/gnomegames /mnt/us/extensions/gnomegames/share/glib-2.0/schemas ' /var/lib/kpm-consumer/gnomegames.log";
            cleanup = "mv /mnt/us/extensions/gnomegames/bin/armhf/gnomine.kpm-consumer-original /mnt/us/extensions/gnomegames/bin/armhf/gnomine";
          }
        ];
        kindlepw2.launches = [
          {
            mode = "dispatch";
            args = [ "chess" ];
            boundaries = [ "Gnome Chess executable boundary" ];
            actualApplicationExecution = false;
            setup = ''
              TARGET=/mnt/us/extensions/gnomegames/bin/armel/glchess
              test -x "''${TARGET}"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s %s\n" "''${PWD}" "''${GSETTINGS_SCHEMA_DIR}" "''${*}" > /var/lib/kpm-consumer/gnomegames.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/gnomegames.log
            '';
            verify = "grep -Fx -- '/mnt/us/extensions/gnomegames /mnt/us/extensions/gnomegames/share/glib-2.0/schemas ' /var/lib/kpm-consumer/gnomegames.log";
            cleanup = "mv /mnt/us/extensions/gnomegames/bin/armel/glchess.kpm-consumer-original /mnt/us/extensions/gnomegames/bin/armel/glchess";
          }
          {
            mode = "dispatch";
            args = [ "mines" ];
            boundaries = [ "Gnome Mines executable boundary" ];
            actualApplicationExecution = false;
            setup = ''
              TARGET=/mnt/us/extensions/gnomegames/bin/armel/gnomine
              test -x "''${TARGET}"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s %s\n" "''${PWD}" "''${GSETTINGS_SCHEMA_DIR}" "''${*}" > /var/lib/kpm-consumer/gnomegames.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/gnomegames.log
            '';
            verify = "grep -Fx -- '/mnt/us/extensions/gnomegames /mnt/us/extensions/gnomegames/share/glib-2.0/schemas ' /var/lib/kpm-consumer/gnomegames.log";
            cleanup = "mv /mnt/us/extensions/gnomegames/bin/armel/gnomine.kpm-consumer-original /mnt/us/extensions/gnomegames/bin/armel/gnomine";
          }
        ];
      };
    };
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
