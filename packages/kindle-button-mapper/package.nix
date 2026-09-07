{ mkWafPackage, pkgs }:

let
  inherit (pkgs) lib;
  revision = "fa3a851ef1d26f3045ef27c7dc3465e45d56de14";
  source = pkgs.fetchFromGitHub {
    owner = "zampierilucas";
    repo = "kindle-button-mapper-rs";
    rev = revision;
    hash = "sha256-nu549O2v47azO90ez1vPo7HV0YLPsKC0NG1wANndbLU=";
  };
  mapperEnvironment = {
    BUILD_SHA = builtins.substring 0 8 revision;
    KPM_INSTALL_BINARY = "/mnt/us/kindle-button-mapper/kindle-button-mapper";
    KPM_DAEMON_PID_FILE = "/tmp/kpm-kindle-button-mapper-daemon.pid";
    KPM_HELPER_PID_FILE = "/tmp/kpm-kindle-button-mapper-helper.pid";
    KPM_DAEMON_LOG = "/mnt/us/kindle-button-mapper/daemon.log";
    KPM_HELPER_LOG = "/mnt/us/kindle-button-mapper/manager.log";
  };
  buildMapper = rustPlatform: extraEnvironment:
    rustPlatform.buildRustPackage ({
      pname = "kindle-button-mapper";
      version = "1.6.0-kpm1";
      src = source;
      patches = [ ./kpm-lifecycle.patch ];
      cargoHash = "sha256-k9RaOZl9aa6/nWAifpCGkCU47Z5seWYZ40+jgeRezMo=";
      doCheck = false;
    } // mapperEnvironment // extraEnvironment);
  mapper = buildMapper pkgs.pkgsCross.armv7l-hf-multiplatform.pkgsStatic.rustPlatform { };
  lifecycleTestDirectory = "/tmp/kpm-button-mapper-lifecycle-test";
  nativeMapper = buildMapper pkgs.rustPlatform {
    doCheck = true;
    KPM_INSTALL_BINARY = "${lifecycleTestDirectory}/kindle-button-mapper";
    KPM_DAEMON_PID_FILE = "${lifecycleTestDirectory}/daemon.pid";
    KPM_HELPER_PID_FILE = "${lifecycleTestDirectory}/helper.pid";
    KPM_DAEMON_LOG = "${lifecycleTestDirectory}/daemon.log";
    KPM_HELPER_LOG = "${lifecycleTestDirectory}/manager.log";
  };
  lifecycleCheck = pkgs.runCommand "kindle-button-mapper-lifecycle-check"
    {
      nativeBuildInputs = [ pkgs.curl pkgs.gawk ];
    }
    ''
      sh ${./check-lifecycle.sh} ${lib.getExe' nativeMapper "kindle-button-mapper"} ${source}/config.ini
      touch "''${out}"
    '';
  binaryCheck = pkgs.runCommand "kindle-button-mapper-binary-check"
    { }
    ''
      BINARY=${lib.getExe' mapper "kindle-button-mapper"}
      ${lib.getExe pkgs.file} "''${BINARY}" \
        | ${lib.getExe pkgs.gnugrep} -F 'ELF 32-bit LSB' \
        | ${lib.getExe pkgs.gnugrep} -F 'ARM' \
        | ${lib.getExe pkgs.gnugrep} -F 'statically linked'
      ${lib.getExe' pkgs.binutils "readelf"} -h "''${BINARY}" \
        | ${lib.getExe pkgs.gnugrep} -F 'Machine:' \
        | ${lib.getExe pkgs.gnugrep} -F 'ARM'
      ${lib.getExe' pkgs.binutils "readelf"} -h "''${BINARY}" \
        | ${lib.getExe pkgs.gnugrep} -F 'hard-float ABI'
      if ${lib.getExe' pkgs.binutils "readelf"} -l "''${BINARY}" | ${lib.getExe pkgs.gnugrep} -F 'INTERP'; then
        exit 1
      fi
      if ${lib.getExe' pkgs.binutils "strings"} "''${BINARY}" | ${lib.getExe pkgs.gnugrep} -F '/sbin/initctl'; then
        exit 1
      fi
      touch "''${out}"
    '';
  consumerMapper = pkgs.writeShellScript "kindle-button-mapper-consumer-recorder" ''
    printf '%s\n' "''${*}" >> /var/lib/kpm-consumer/kindle-button-mapper-exec.log
  '';
  assertManagedProcessesStopped = ''
    MANAGED_BINARY='/mnt/us/kindle-button-mapper/kindle-button-mapper'
    for PROCESS_EXE in /proc/[0-9]*/exe; do
      [ -e "''${PROCESS_EXE}" ] || [ -L "''${PROCESS_EXE}" ] || continue
      PROCESS_TARGET="$(readlink "''${PROCESS_EXE}" 2>/dev/null || true)"
      case "''${PROCESS_TARGET}" in
        "''${MANAGED_BINARY}"|"''${MANAGED_BINARY} (deleted)")
          echo 'a Kindle Button Mapper process is still active' >&2
          exit 1
          ;;
      esac
    done
  '';
  stopManagedProcesses = ''
    MANAGED_BINARY='/mnt/us/kindle-button-mapper/kindle-button-mapper'
    if command -v lipc-set-prop >/dev/null 2>&1; then
      lipc-set-prop com.lab126.appmgrd stop 'app://com.lzampier.mappermanager'
    fi
    if [ -x "''${MANAGED_BINARY}" ]; then
      if [ -f /tmp/kpm-kindle-button-mapper-daemon.pid ] || [ -f /tmp/kpm-kindle-button-mapper-helper.pid ]; then
        "''${MANAGED_BINARY}" --kpm-stop-all
      fi
    fi
    ${assertManagedProcessesStopped}
  '';
  packageBase = mkWafPackage {
    id = "kindle-button-mapper";
    name = "Kindle Button Mapper";
    author = "Lucas Zampieri";
    description = "Map input-device events with an on-device manager";
    version = [ 1 6 0 ];
    platforms = [ "kindlehf" ];
    src = source;
    payloadDirectory = "payload/manager";
    mesquiteDirectory = "/var/local/mesquite/com.lzampier.mappermanager";
    appId = "com.lzampier.mappermanager";
    scriptletName = "MapperManager.sh";
    scriptletIcon = {
      path = "payload/manager-icon.png";
      mediaSubtype = "png";
    };
    legacyPaths = [ "/mnt/us/documents/KindleButtonMapper.sh" ];
    documents = {
      directory = "/mnt/us/kindle-button-mapper";
      payloadDirectory = "payload/application";
      retainedPaths = [
        "config.ini"
        "scripts/auto.sh"
      ];
    };
    launchPrelude = ''
      /mnt/us/kindle-button-mapper/kindle-button-mapper \
        --kpm-start-helper \
        /mnt/us/kindle-button-mapper/config.ini
    '';
    installPrelude = ''
      if { [ "''${HAD_OWNED_DEPLOYMENT}" -eq 1 ] && [ "''${MARKER_STATE}" != retained ]; } || \
        { [ "''${HAD_OWNED_DOCUMENTS}" -eq 1 ] && [ "''${DOCUMENTS_MARKER_STATE}" != retained ]; }; then
        ${assertManagedProcessesStopped}
      fi
    '';
    uninstallPrelude = ''
      if { [ -n "''${MARKER_STATE}" ] && [ "''${MARKER_STATE}" != retained ]; } || \
        { [ -n "''${DOCUMENTS_MARKER_STATE}" ] && [ "''${DOCUMENTS_MARKER_STATE}" != retained ]; }; then
        ${stopManagedProcesses}
      fi
    '';
    passthru = {
      consumer.cases.kindlehf = {
        launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [
              "packaged ARM helper executable recorder"
              "LIPC app manager dispatch"
            ];
            actualApplicationExecution = false;
            setup = ''
              mv /mnt/us/kindle-button-mapper/kindle-button-mapper \
                /mnt/us/kindle-button-mapper/kindle-button-mapper.consumer-original
              ln -s ${consumerMapper} /mnt/us/kindle-button-mapper/kindle-button-mapper
              rm -f /var/lib/kpm-consumer/kindle-button-mapper-exec.log \
                /var/lib/kpm-consumer/lipc-set-prop.log
            '';
            verify = [
              "grep -Fx -- '--kpm-start-helper /mnt/us/kindle-button-mapper/config.ini' /var/lib/kpm-consumer/kindle-button-mapper-exec.log"
              "grep -F -- 'com.lab126.appmgrd start app://com.lzampier.mappermanager' /var/lib/kpm-consumer/lipc-set-prop.log"
            ];
            cleanup = ''
              rm /mnt/us/kindle-button-mapper/kindle-button-mapper
              mv /mnt/us/kindle-button-mapper/kindle-button-mapper.consumer-original \
                /mnt/us/kindle-button-mapper/kindle-button-mapper
            '';
          }
        ];
        installAssertions = [
          "test -x /mnt/us/kindle-button-mapper/kindle-button-mapper"
          "test -f /mnt/us/kindle-button-mapper/.kpm-kindle-button-mapper"
        ];
        uninstallAssertions = [
          "test \"$(cat /mnt/us/kindle-button-mapper/.kpm-kindle-button-mapper)\" = retained"
          "test -f /mnt/us/kindle-button-mapper/config.ini"
          "test ! -e /mnt/us/kindle-button-mapper/kindle-button-mapper"
        ];
      };
      tests = {
        binary = binaryCheck;
        lifecycle = lifecycleCheck;
      };
    };
    buildPayload = ''
      mkdir -p payload/application payload/manager
      cp ${lib.getExe' mapper "kindle-button-mapper"} payload/application/kindle-button-mapper
      cp "''${SOURCE}/config.ini" payload/application/config.ini
      cp "''${SOURCE}/LICENSE" payload/application/LICENSE
      cp -R "''${SOURCE}/scripts" payload/application/scripts
      cp -R "''${SOURCE}/illusion/MapperManager/." payload/manager/
      sed -n 's|^# Icon: data:image/png;base64,||p' "''${SOURCE}/illusion/MapperManager.sh" \
        | base64 -d > payload/manager-icon.png
      chmod -R u+w payload
      chmod 755 payload/application/kindle-button-mapper payload/application/scripts/*.sh
    '';
  };
  hookRecoveryCheck = pkgs.runCommand "kindle-button-mapper-hook-recovery-check"
    {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.sqlite
      ];
    }
    ''
      sh ${./check-recovery.sh} ${packageBase}/${packageBase.kpm.filename} ${lib.getExe pkgs.gawk}
      touch "''${out}"
    '';
  package = packageBase.overrideAttrs (previous: {
    passthru = previous.passthru // {
      tests = previous.passthru.tests // {
        hookRecovery = hookRecoveryCheck;
      };
    };
  });
in
[ package ]
