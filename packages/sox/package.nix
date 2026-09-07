{ mkKpackage, mkNativePackage, fetchurl, pkgs }:

let
  variants = [
    {
      platform = "kindlehf";
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=216964&d=1752870631";
      hash = "sha256-ZFZEmaiiRzsOUibB6JXMknsTHBVDKWDeW1K73Vcugnk=";
    }
    {
      platform = "kindlepw2";
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=216965&d=1752870631";
      hash = "sha256-lNz/GE16bEZo6lFtnxXKcF8x4uH18NFIFN6n0aYbAJc=";
    }
  ];
  consumerSox = pkgs.writeShellScript "sox-consumer-recorder" ''
    printf '%s\n' "''${*}" >> /var/lib/kpm-consumer/sox-exec.log
  '';
  consumerAplay = pkgs.writeShellScript "sox-consumer-aplay" ''
    printf '%s\n' "''${*}" >> /var/lib/kpm-consumer/sox-aplay.log
    if [ "''${#}" -eq 0 ]; then
      cat > /dev/null
    fi
  '';
  makePackage =
    variant:
    let
      nativePackage = mkNativePackage {
        id = "sox";
        displayName = "SOX Media Player";
        destination = "/mnt/us/extensions/sox";
        payloadPath = "payload/sox";
        preservedPaths = [ "menu.json" ];
        scriptlets = [
          {
            source = "scriptlets/SOX.sh";
            destination = "/mnt/us/documents/SOX.sh";
          }
        ];
      };
    in
    mkKpackage {
      id = "sox";
      name = "SOX Media Player";
      author = "Dhdurgee";
      description = "Bluetooth and USB audio player";
      version = [
        3
        0
        0
      ];
      platforms = [ variant.platform ];
      src = fetchurl {
        inherit (variant) url hash;
      };
      buildPayload = ''
        mkdir -p payload scriptlets
        unzip -q "''${SOURCE}" -d unpacked
        mv unpacked/extensions/sox payload/sox
        chmod 755 payload/sox/*.sh payload/sox/sox payload/sox/soxi
        printf '%s\n' \
          '# Name: SOX Media Player' \
          '# DontUseFBInk' \
          'exec /var/local/kmc/bin/kpm launch sox' \
          > scriptlets/SOX.sh
        ${nativePackage.buildInventory}
      '';
      installScript = nativePackage.installScript;
      uninstallScript = nativePackage.uninstallScript;
      launchScript = ./launch.sh;
      scriptlet = {
        name = "SOX.sh";
        path = "scriptlets/SOX.sh";
        icon = null;
      };
      passthru = {
        native = nativePackage.passthru;
        consumer.cases.${variant.platform} = {
          launches = [
            {
              mode = "dispatch";
              args = [ ];
              boundaries = [
                "packaged ARM SoX executable recorder"
                "ALSA playback service shim"
              ];
              actualApplicationExecution = false;
              pathPrefix = [ "/var/lib/kpm-consumer/sox/bin" ];
              setup = ''
                mkdir -p /mnt/us/music /var/lib/kpm-consumer/sox/bin
                printf '%s' audio-fixture > /mnt/us/music/consumer.wav
                ln -sf ${consumerAplay} /var/lib/kpm-consumer/sox/bin/aplay
                mv /mnt/us/extensions/sox/sox /mnt/us/extensions/sox/sox.consumer-original
                ln -s ${consumerSox} /mnt/us/extensions/sox/sox
                rm -f /var/lib/kpm-consumer/sox-exec.log /var/lib/kpm-consumer/sox-aplay.log
              '';
              verify = [
                "grep -Fx -- '/var/tmp/playlist.m3u -t wav - trim 0' /var/lib/kpm-consumer/sox-exec.log"
                "grep -Fx -- '/mnt/us/extensions/sox/silence.wav' /var/lib/kpm-consumer/sox-aplay.log"
                "grep -Fx -- '/mnt/us/music/consumer.wav' /var/tmp/playlist.m3u"
              ];
              cleanup = ''
                rm /mnt/us/extensions/sox/sox
                mv /mnt/us/extensions/sox/sox.consumer-original /mnt/us/extensions/sox/sox
              '';
            }
          ];
          uninstallAssertions = [
            "test \"$(cat /mnt/us/extensions/sox/.kpm-sox)\" = retained"
            "test -f /mnt/us/extensions/sox/menu.json"
            "test ! -e /mnt/us/extensions/sox/sox"
          ];
        };
        abi = {
          runtimeContexts = [
            {
              pathPrefix = "payload/sox/";
              libraryPaths = [ "payload/sox/library" ];
            }
          ];
          functionalTests = [
            {
              name = "synthesize-wav";
              runtime = if variant.platform == "kindlehf" then "nix-armhf" else "nix-armel";
              script = pkgs.writeShellScript "sox-${variant.platform}-abi-check" ''
                set -eu
                LIBRARY_PATH="''${KPM_ABI_PACKAGE_ROOT}/payload/sox/library:''${KPM_ABI_EMULATION_LIBRARY_PATH}"
                "''${KPM_ABI_QEMU}" \
                  "''${KPM_ABI_EMULATION_LOADER}" \
                  --library-path "''${LIBRARY_PATH}" \
                  "''${KPM_ABI_PACKAGE_ROOT}/payload/sox/sox" \
                  -D -n -r 8000 -c 1 -b 16 "''${KPM_ABI_WORK_DIRECTORY}/tone.wav" synth 0.01 sine 1000
                SAMPLES="$("''${KPM_ABI_QEMU}" \
                  "''${KPM_ABI_EMULATION_LOADER}" \
                  --library-path "''${LIBRARY_PATH}" \
                  "''${KPM_ABI_PACKAGE_ROOT}/payload/sox/soxi" \
                  -s "''${KPM_ABI_WORK_DIRECTORY}/tone.wav")"
                test "''${SAMPLES}" = 80
                printf '%s  %s\n' \
                  c2107fdaf0aa234fb5e356b8fc6337b7580953bf012e5b557ee28e5c00e61a74 \
                  "''${KPM_ABI_WORK_DIRECTORY}/tone.wav" \
                  | sha256sum -c -
              '';
            }
          ];
        };
      };
    };
in
map makePackage variants
