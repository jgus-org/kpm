{ mkKpackage, fetchurl }:

[
  (mkKpackage {
    id = "larkplayer";
    name = "LARKPlayer";
    author = "Barna";
    description = "Libre audiobook reader for Kindle";
    version = [
      2
      8
      1
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/kbarni/LARKPlayer/releases/download/2.8.1/lark.zip";
      hash = "sha256-wtBErmAlz+RGkr/TQsQRMKzv1DvMbFUZ+nYIQzJe9zI=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
      chmod 755 payload/LARK/start_lark.sh
      sed -i '/^cd \/mnt\/us\/LARK$/,$d' payload/documents/lark.sh
      printf '%s\n' 'exec /var/local/kmc/bin/kpm launch larkplayer' >> payload/documents/lark.sh
    '';
    scriptlet = {
      name = "lark.sh";
      path = "payload/documents/lark.sh";
      icon = null;
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall.sh;
    launchScript = ./launch.sh;
    passthru = {
      abi.runtimeContexts = [
        {
          path = "payload/LARK/larkplayer";
          libraryPaths = [ "payload/LARK/libs_hf" ];
        }
        {
          path = "payload/LARK/larkplayer_pw2";
          libraryPaths = [ "payload/LARK/libs_pw2" ];
        }
      ];
      consumer.cases = {
        kindlehf.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [
              "LARKPlayer executable boundary"
              "LIPC Bluetooth service shim"
              "process-state shim"
              "sleep service shim"
            ];
            actualApplicationExecution = false;
            pathPrefix = [ "/var/lib/kpm-consumer/larkplayer/bin" ];
            setup = ''
              START=/mnt/us/LARK/start_lark.sh
              TARGET=/mnt/us/LARK/larkplayer
              BIN=/var/lib/kpm-consumer/larkplayer/bin
              test -x "''${START}"
              test -x "''${TARGET}"
              mkdir -p "''${BIN}"
              printf '%s\n' '#!/bin/sh' 'exit 1' > "''${BIN}/pgrep"
              chmod 755 "''${BIN}/pgrep"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s\n" "''${PWD}" "''${*}" > /var/lib/kpm-consumer/larkplayer.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/larkplayer.log
            '';
            verify = [
              "grep -Fx -- '/mnt/us/LARK ' /var/lib/kpm-consumer/larkplayer.log"
              "grep -F -- 'com.lab126.btfd BTenable 0:1' /var/lib/kpm-consumer/lipc-set-prop.log"
            ];
            cleanup = ''
              TARGET=/mnt/us/LARK/larkplayer
              if [ -e "''${TARGET}.kpm-consumer-original" ]; then mv "''${TARGET}.kpm-consumer-original" "''${TARGET}"; fi
            '';
          }
        ];
        kindlepw2.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [
              "LARKPlayer executable boundary"
              "LIPC Bluetooth service shim"
              "process-state shim"
              "sleep service shim"
            ];
            actualApplicationExecution = false;
            pathPrefix = [ "/var/lib/kpm-consumer/larkplayer/bin" ];
            setup = ''
              START=/mnt/us/LARK/start_lark.sh
              TARGET=/mnt/us/LARK/larkplayer_pw2
              BIN=/var/lib/kpm-consumer/larkplayer/bin
              test -x "''${START}"
              test -x "''${TARGET}"
              mkdir -p "''${BIN}"
              printf '%s\n' '#!/bin/sh' 'exit 1' > "''${BIN}/pgrep"
              chmod 755 "''${BIN}/pgrep"
              mv "''${TARGET}" "''${TARGET}.kpm-consumer-original"
              printf '%s\n' '#!/bin/sh' 'printf "%s %s\n" "''${PWD}" "''${*}" > /var/lib/kpm-consumer/larkplayer.log' > "''${TARGET}"
              chmod 755 "''${TARGET}"
              rm -f /var/lib/kpm-consumer/larkplayer.log
            '';
            verify = [
              "grep -Fx -- '/mnt/us/LARK ' /var/lib/kpm-consumer/larkplayer.log"
              "grep -F -- 'com.lab126.btfd BTenable 0:1' /var/lib/kpm-consumer/lipc-set-prop.log"
            ];
            cleanup = ''
              TARGET=/mnt/us/LARK/larkplayer_pw2
              if [ -e "''${TARGET}.kpm-consumer-original" ]; then mv "''${TARGET}.kpm-consumer-original" "''${TARGET}"; fi
            '';
          }
        ];
      };
    };
  })
]
