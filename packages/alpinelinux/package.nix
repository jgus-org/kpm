{ mkKpackage
, mkNativePackage
, fetchurl
, pkgs
,
}:

let
  source = fetchurl {
    url = "https://github.com/schuhumi/alpine_kindle/releases/download/v0.2-alpha2/alpine.zip";
    hash = "sha256-tTlmX9B//Clk1ji6L3P9biL0gBr3Ss8vzoSroBvnSlI=";
  };
  license = fetchurl {
    url = "https://raw.githubusercontent.com/schuhumi/alpine_kindle/v0.2-alpha2/LICENSE";
    hash = "sha256-OXLcl0T2SZ8Pmy2/dmlvKuetivmyPd5m1q+Gyd+zaYY=";
  };
  mountGuard = ''
    IMAGE=/mnt/us/alpine.ext3
    MOUNT_DIRECTORY=/tmp/alpinelinux
    if mount | grep -F " on ''${MOUNT_DIRECTORY} " >/dev/null \
      || losetup -a 2>/dev/null | grep -F "''${IMAGE}" >/dev/null; then
      printf '%s\n' 'Alpine Linux disk image is in use' >&2
      exit 1
    fi
  '';
  native = mkNativePackage {
    id = "alpinelinux";
    displayName = "Alpine Linux";
    destination = "/mnt/us/extensions/alpinelinux";
    payloadPath = "payload/alpinelinux";
    scriptlets = [
      {
        source = "scriptlets/Alpine Linux.sh";
        destination = "/mnt/us/documents/Alpine Linux.sh";
      }
      {
        source = "scriptlets/Alpine Linux Shell.sh";
        destination = "/mnt/us/documents/Alpine Linux Shell.sh";
      }
    ];
    installPreflight = mountGuard;
    uninstallPreflight = mountGuard;
  };
in
[
  (mkKpackage {
    id = "alpinelinux";
    name = "Alpine Linux";
    author = "Simon Schumann";
    description = "Alpine Linux chroot and MATE desktop";
    version = [
      0
      2
      2
    ];
    platforms = [ "kindlehf" ];
    dependencies = [
      {
        id = "kterm";
        min = [
          2
          6
          0
        ];
        max = [
          3
          0
          0
        ];
      }
    ];
    src = source;
    buildPayload = ''
      mkdir -p payload/alpinelinux scriptlets
      cp "''${SOURCE}" alpine.zip
      cp ${./run.sh} payload/alpinelinux/run.sh
      cp ${license} payload/alpinelinux/LICENSE
      printf '%s\n' \
        '# Name: Alpine Linux' \
        '# Author: Simon Schumann' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch alpinelinux gui' \
        > 'scriptlets/Alpine Linux.sh'
      printf '%s\n' \
        '# Name: Alpine Linux Shell' \
        '# Author: Simon Schumann' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch alpinelinux shell' \
        > 'scriptlets/Alpine Linux Shell.sh'
      chmod 755 payload/alpinelinux/run.sh
      ${native.buildInventory}
    '';
    scriptlet = {
      name = "Alpine Linux.sh";
      path = "scriptlets/Alpine Linux.sh";
      icon = null;
    };
    passthru = {
      native = native.passthru;
      tests.lifecycle = pkgs.runCommand "alpinelinux-lifecycle-check" { } ''
        export TMPDIR="$(${pkgs.lib.getExe' pkgs.coreutils "mktemp"} -d)"
        trap '${pkgs.lib.getExe' pkgs.coreutils "rm"} -rf "''${TMPDIR}"' EXIT
        ${pkgs.lib.getExe pkgs.dash} ${./check-lifecycle.sh} \
          ${native.installScript} ${native.uninstallScript} ${./run.sh} ${license}
        touch "''${out}"
      '';
      tests.runtime = pkgs.runCommand "alpinelinux-runtime-check"
        {
          nativeBuildInputs = [
            pkgs.unzip
            pkgs.zip
          ];
        }
        ''
          export TMPDIR="$(${pkgs.lib.getExe' pkgs.coreutils "mktemp"} -d)"
          trap '${pkgs.lib.getExe' pkgs.coreutils "rm"} -rf "''${TMPDIR}"' EXIT
          ${pkgs.lib.getExe pkgs.dash} ${./check-runtime.sh} ${./run.sh}
          touch "''${out}"
        '';
    };
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
