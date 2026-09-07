{ mkKpackage, fetchurl, pkgs }:
let
  consumerEips = pkgs.writeShellScript "updateblockstatus-consumer-eips" ''
    printf '%s\n' "''${*}" >> /var/lib/kpm-consumer/updateblockstatus-eips.log
  '';
in
[
  (mkKpackage {
    id = "updateblockstatus";
    name = "UpdateBlock Status";
    author = "Neura, Dammit Jeff";
    description = "Display OTA update blocker status";
    version = [
      1
      1
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://raw.githubusercontent.com/KindleTweaks/Repository/512437b4bcb2d9994dedd52feb2f0c7b4c426344/UpdateBlockStatus/assets/updateblock.sh";
      hash = "sha256-npzBAVnt8Br9xrSI9QJqUPfbukuwpGKgkkldh9+gVLQ=";
    };
    buildPayload = ''
      mkdir -p payload
      cp "''${SOURCE}" payload/updateblock.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' "''${SOURCE}" | base64 -d > payload/updateblock.png
      mkdir scriptlets
      {
        sed -n '/^# Icon: data:image\/png;base64,/p' "''${SOURCE}"
        printf '%s\n' '# DontUseFBInk' 'exec /var/local/kmc/bin/kpm launch updateblockstatus'
      } > scriptlets/updateblock.sh
    '';
    scriptlet = {
      name = "updateblock.sh";
      icon = "payload/updateblock.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall.sh;
    launchScript = ./launch.sh;
    passthru = {
      consumer.cases = pkgs.lib.genAttrs [ "kindlehf" "kindlepw2" ] (_: {
        launches = [
          {
            mode = "maintenance";
            args = [ ];
            boundaries = [
              "e-ink display service shim"
              "synthetic touch-input fixture"
              "LIPC app manager dispatch"
            ];
            actualApplicationExecution = true;
            pathPrefix = [ "/var/lib/kpm-consumer/updateblockstatus/bin" ];
            setup = ''
              mkdir -p /var/lib/kpm-consumer/updateblockstatus/bin
              printf '%s\n' \
                'Section "InputDevice"' \
                '  Option "Device" "/var/lib/kpm-consumer/updateblockstatus/touch"' \
                '  Option "CorePointer"' \
                'EndSection' \
                > /etc/xorg.conf
              printf '%s' touch-input > /var/lib/kpm-consumer/updateblockstatus/touch
              ln -sf ${consumerEips} /var/lib/kpm-consumer/updateblockstatus/bin/eips
              rm -f /var/lib/kpm-consumer/updateblockstatus-eips.log /var/lib/kpm-consumer/lipc-set-prop.log
            '';
            verify = [
              "grep -F -- 'OTA binaries are corrupted.' /var/lib/kpm-consumer/updateblockstatus-eips.log"
              "grep -F -- 'com.lab126.appmgrd start app://com.lab126.booklet.home' /var/lib/kpm-consumer/lipc-set-prop.log"
            ];
          }
        ];
        installAssertions = "test -f /mnt/us/documents/updateblock.sh";
        uninstallAssertions = "test ! -e /mnt/us/documents/updateblock.sh";
      });
      tests.callback = pkgs.runCommand "updateblockstatus-callback-check" { } ''
        sh ${./check-callback.sh} ${./install.sh} ${./uninstall.sh}
        touch "''${out}"
      '';
    };
  })
]
