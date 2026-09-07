{ mkKpackage
, mkNativePackage
, fetchurl
,
}:
let
  nativePackage = mkNativePackage {
    id = "ranki";
    displayName = "RAnki";
    destination = "/mnt/us/extensions/ranki";
    payloadPath = "payload/ranki";
    preservedPaths = [ "config.ini" ];
    scriptlets = [
      {
        source = "scriptlets/RAnki.sh";
        destination = "/mnt/us/documents/RAnki.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "ranki";
    name = "RAnki";
    author = "CrazyElectron";
    description = "Anki flashcard client for Kindle";
    version = [
      0
      2
      0
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/crazy-electron/ranki/releases/download/v0.2/ranki.zip";
      hash = "sha256-IbiLv3T6hPUBOPPpeZ7xTLzDYTV3r1Ygt12We83VOdY=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d payload
      sed -n 's|^# Icon: data:image/png;base64,||p' payload/ranki/shortcut_ranki.sh \
        | base64 -d > payload/ranki/ranki-cover.png
      rm payload/ranki/shortcut_ranki.sh
      chmod 755 payload/ranki/ranki.sh
      printf '%s\n' \
        '# Name: RAnki' \
        '# Icon: /mnt/us/extensions/ranki/ranki-cover.png' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch ranki' \
        > scriptlets/RAnki.sh
      ${nativePackage.buildInventory}
    '';
    installScript = nativePackage.installScript;
    uninstallScript = nativePackage.uninstallScript;
    launchScript = ./launch.sh;
    scriptlet = {
      name = "RAnki.sh";
      path = "scriptlets/RAnki.sh";
      icon = "payload/ranki/ranki-cover.png";
      installedIcon = "/mnt/us/extensions/ranki/ranki-cover.png";
    };
    passthru = {
      native = nativePackage.passthru;
      consumer.cases = {
        kindlehf.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [ "RAnki executable boundary" ];
            actualApplicationExecution = false;
            setup = ''
              TARGET=/mnt/us/extensions/ranki/ranki.sh
              test -x "''${TARGET}"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s\n" "''${PWD}" "''${*}" > /var/lib/kpm-consumer/ranki.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/ranki.log
            '';
            verify = "grep -Fx -- '/mnt/us/kmc/kpm/packages/ranki ' /var/lib/kpm-consumer/ranki.log";
            cleanup = ''
              TARGET=/mnt/us/extensions/ranki/ranki.sh
              if [ -e "''${TARGET}.kpm-consumer-original" ]; then mv "''${TARGET}.kpm-consumer-original" "''${TARGET}"; fi
            '';
          }
        ];
        kindlepw2.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [ "RAnki executable boundary" ];
            actualApplicationExecution = false;
            setup = ''
              TARGET=/mnt/us/extensions/ranki/ranki.sh
              test -x "''${TARGET}"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s\n" "''${PWD}" "''${*}" > /var/lib/kpm-consumer/ranki.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/ranki.log
            '';
            verify = "grep -Fx -- '/mnt/us/kmc/kpm/packages/ranki ' /var/lib/kpm-consumer/ranki.log";
            cleanup = ''
              TARGET=/mnt/us/extensions/ranki/ranki.sh
              if [ -e "''${TARGET}.kpm-consumer-original" ]; then mv "''${TARGET}.kpm-consumer-original" "''${TARGET}"; fi
            '';
          }
        ];
      };
    };
  })
]
