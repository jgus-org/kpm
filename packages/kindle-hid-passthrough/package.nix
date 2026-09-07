{ mkWafPackage, fetchurl, pkgs }:
let
  source = fetchurl {
    url = "https://github.com/zampierilucas/kindle-hid-passthrough/releases/download/v3.16.0/kindle-hid-passthrough.kpkg";
    hash = "sha256-WtDJb31ENigzsR4yejVI8ZFcHIiivBMJY8xOa6JuabA=";
  };
  runtimePrelude = builtins.readFile ./stop-runtime.sh;
  assertRuntimeStopped = ''
    APPLICATION_DIRECTORY=/mnt/us/kindle_hid_passthrough
    DAEMON_PATTERN="^''${APPLICATION_DIRECTORY}/dist/ld-linux-armhf[.]so[.]3 --library-path ''${APPLICATION_DIRECTORY}/dist ''${APPLICATION_DIRECTORY}/dist/main[.]bin --daemon$"
    if pgrep -f "''${DAEMON_PATTERN}" >/dev/null 2>&1; then
      echo 'Kindle HID Passthrough daemon is still running' >&2
      exit 1
    fi
  '';
  runtimeCheck = pkgs.runCommand "kindle-hid-passthrough-runtime-check" { } ''
    sh ${./check-runtime.sh} ${./stop-runtime.sh}
    touch "''${out}"
  '';
  moduleGateCheck = pkgs.runCommand "kindle-hid-passthrough-module-gate-check"
    {
      nativeBuildInputs = [ pkgs.gnused ];
    }
    ''
      FIXTURE_DIRECTORY="$(mktemp -d)"
      export FIXTURE_DIRECTORY
      trap 'rm -rf "''${FIXTURE_DIRECTORY}"' EXIT
      mkdir -p "''${FIXTURE_DIRECTORY}/bin" "''${FIXTURE_DIRECTORY}/proc" "''${FIXTURE_DIRECTORY}/etc" "''${FIXTURE_DIRECTORY}/dev" "''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/dist/kindle_hid_passthrough/modules"
      printf '%s' G000PP > "''${FIXTURE_DIRECTORY}/proc/usid"
      printf '%s\n' Kindle-476967 > "''${FIXTURE_DIRECTORY}/etc/version.txt"
      : > "''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/dist/kindle_hid_passthrough/modules/uhid-4.1.15-lab126-476967-rex.ko"
      cat > "''${FIXTURE_DIRECTORY}/bin/uname" <<'SCRIPT'
      printf '%s\n' 4.1.15-lab126
      SCRIPT
      cat > "''${FIXTURE_DIRECTORY}/bin/insmod" <<'SCRIPT'
      test "''${1}" = "''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/dist/kindle_hid_passthrough/modules/uhid-4.1.15-lab126-476967-rex.ko"
      : > "''${FIXTURE_DIRECTORY}/insmod-called"
      touch "''${FIXTURE_DIRECTORY}/dev/uhid"
      SCRIPT
      cat > "''${FIXTURE_DIRECTORY}/bin/pgrep" <<'SCRIPT'
      EXPECTED_PATTERN="^''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/dist/ld-linux-armhf[.]so[.]3 --library-path ''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/dist ''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/dist/main[.]bin --daemon$"
      test "''${1}" = -f
      test "''${2}" = "''${EXPECTED_PATTERN}"
      if [ -f "''${FIXTURE_DIRECTORY}/daemon-running" ]; then
        exit 0
      fi
      exit 1
      SCRIPT
      cat > "''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/kindle-hid-passthrough" <<'SCRIPT'
      printf x >> "''${FIXTURE_DIRECTORY}/started"
      SCRIPT
      chmod 755 "''${FIXTURE_DIRECTORY}/bin/"* "''${FIXTURE_DIRECTORY}/mnt/us/kindle_hid_passthrough/kindle-hid-passthrough"
      sed \
        -e "s#/mnt/us#''${FIXTURE_DIRECTORY}/mnt/us#g" \
        -e "s#/dev/uhid#''${FIXTURE_DIRECTORY}/dev/uhid#g" \
        -e "s#/proc/usid#''${FIXTURE_DIRECTORY}/proc/usid#g" \
        -e "s#/etc/version.txt#''${FIXTURE_DIRECTORY}/etc/version.txt#g" \
        -e "s#/sys/class/misc/uhid/dev#''${FIXTURE_DIRECTORY}/sys/class/misc/uhid/dev#g" \
        -e "s#/sbin/insmod#insmod#g" \
        ${./launch-prelude.sh} > "''${FIXTURE_DIRECTORY}/launch.sh"
      PATH="''${FIXTURE_DIRECTORY}/bin:''${PATH}" sh "''${FIXTURE_DIRECTORY}/launch.sh"
      sleep 1
      test -f "''${FIXTURE_DIRECTORY}/started"
      rm -f "''${FIXTURE_DIRECTORY}/dev/uhid" "''${FIXTURE_DIRECTORY}/started" "''${FIXTURE_DIRECTORY}/insmod-called"
      printf '%s\n' Kindle-476968 > "''${FIXTURE_DIRECTORY}/etc/version.txt"
      if PATH="''${FIXTURE_DIRECTORY}/bin:''${PATH}" sh "''${FIXTURE_DIRECTORY}/launch.sh"; then
        exit 1
      fi
      test ! -e "''${FIXTURE_DIRECTORY}/started"
      touch "''${FIXTURE_DIRECTORY}/dev/uhid"
      PATH="''${FIXTURE_DIRECTORY}/bin:''${PATH}" sh "''${FIXTURE_DIRECTORY}/launch.sh"
      sleep 1
      test -f "''${FIXTURE_DIRECTORY}/started"
      test ! -e "''${FIXTURE_DIRECTORY}/insmod-called"
      rm "''${FIXTURE_DIRECTORY}/started"
      touch "''${FIXTURE_DIRECTORY}/daemon-running"
      PATH="''${FIXTURE_DIRECTORY}/bin:''${PATH}" sh "''${FIXTURE_DIRECTORY}/launch.sh"
      sleep 1
      test ! -e "''${FIXTURE_DIRECTORY}/started"
      touch "''${out}"
    '';
in
[
  (mkWafPackage {
    id = "kindle-hid-passthrough";
    name = "Kindle HID Passthrough";
    author = "Lucas Zampieri";
    description = "On-demand Bluetooth HID host and manager";
    version = [ 3 16 0 ];
    platforms = [ "kindlehf" ];
    src = source;
    payloadDirectory = "payload";
    mesquiteDirectory = "/mnt/us/kindle_hid_passthrough";
    appId = "com.lzampier.btmanager";
    scriptletName = "BTManager.sh";
    scriptletIcon = {
      path = "payload/illusion/BTManager.png";
      mediaSubtype = "png";
    };
    legacyPaths = [ ];
    retainedPayloadPaths = [ "cache" "config.ini" "devices.conf" ];
    launchPrelude = builtins.readFile ./launch-prelude.sh;
    installPrelude = ''
      if [ "''${HAD_OWNED_DEPLOYMENT}" -eq 1 ]; then
        ${assertRuntimeStopped}
      fi
    '';
    uninstallPrelude = ''
      if [ -n "''${MARKER_STATE}" ]; then
        ${runtimePrelude}
      fi
    '';
    lifecycleFailureFixture = true;
    passthru.tests = {
      moduleGate = moduleGateCheck;
      runtime = runtimeCheck;
    };
    buildPayload = ''
      mkdir payload
      tar -xJf "''${SOURCE}" -C payload
      patch -p1 < ${./disable-autostart.patch}
      sed -n 's|^# Icon: data:image/png;base64,||p' payload/illusion/BTManager.sh \
        | base64 -d > payload/illusion/BTManager.png
    '';
  })
]
