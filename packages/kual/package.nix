{ mkKpackage
, mkNativePackage
, fetchurl
, pkgs
,
}:

let
  license = fetchurl {
    url = "https://raw.githubusercontent.com/KindleTweaks/PEKI/179993e278869e81ae0377aa3855dd915de7dc57/LICENSE";
    hash = "sha256-E0mkthSEkrRPYp5k7tZ2YS4jT+moOeTzsnfBSCyISfE=";
  };
  native = mkNativePackage {
    id = "kual";
    displayName = "PEKI KUAL Installer";
    destination = "/mnt/us/documents/PEKI";
    payloadPath = "payload/PEKI";
    scriptlets = [
      {
        source = "scriptlets/PEKI-KUAL.sh";
        destination = "/mnt/us/documents/PEKI-KUAL.sh";
      }
    ];
  };
  consumerMntroot = pkgs.writeShellScript "kual-consumer-mntroot" ''
    printf '%s\n' "''${*}" >> /var/lib/kpm-consumer/kual-mntroot.log
  '';
in
[
  (mkKpackage {
    id = "kual";
    name = "PEKI KUAL Installer";
    author = "KindleTweaks";
    description = "Install or launch KUAL through PEKI";
    version = [
      1
      0
      0
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/KindleTweaks/PEKI/releases/download/v1.0/PEKI.zip";
      hash = "sha256-9lMEWQntIwSWw9gXbJkB06ah9pPFK0iFab5qYOCFJJk=";
    };
    buildPayload = ''
      unzip -q "''${SOURCE}" -d unpacked
      mkdir -p payload/PEKI scriptlets
      cp unpacked/KUAL.jar payload/PEKI/KUAL.jar
      cp ${./peki.sh} payload/PEKI/peki.sh
      cp ${license} payload/PEKI/LICENSE
      {
        sed -n '1,5p' unpacked/KUAL.sh
        printf '%s\n' 'exec /var/local/kmc/bin/kpm launch kual'
      } > scriptlets/PEKI-KUAL.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' unpacked/KUAL.sh | base64 -d > payload/PEKI/icon.png
      chmod +x payload/PEKI/peki.sh
      ${native.buildInventory}
    '';
    scriptlet = {
      name = "PEKI-KUAL.sh";
      path = "scriptlets/PEKI-KUAL.sh";
      icon = "payload/PEKI/icon.png";
    };
    passthru = {
      native = native.passthru;
      consumer.cases = pkgs.lib.genAttrs [ "kindlehf" "kindlepw2" ] (_: {
        launches = [
          {
            mode = "maintenance";
            args = [ ];
            boundaries = [
              "root-mount service shim"
              "LIPC app manager dispatch"
            ];
            actualApplicationExecution = true;
            pathPrefix = [ "/var/lib/kpm-consumer/kual/bin" ];
            setup = ''
              mkdir -p /opt/amazon/ebook/booklet /var/local/kmc/hotfix /var/lib/kpm-consumer/kual/bin
              printf '%s\n' 'HOTFIX_VERSION="2.3.7"' > /var/local/kmc/hotfix/libhotfixutils
              ln -sf ${consumerMntroot} /var/lib/kpm-consumer/kual/bin/mntroot
              rm -f /opt/amazon/ebook/booklet/KUALBooklet.jar \
                /opt/amazon/ebook/booklet/.kpm-peki-kual \
                /var/lib/kpm-consumer/kual-mntroot.log \
                /var/lib/kpm-consumer/lipc-set-prop.log
            '';
            verify = [
              "cmp /mnt/us/documents/PEKI/KUAL.jar /opt/amazon/ebook/booklet/KUALBooklet.jar"
              "test \"$(cat /opt/amazon/ebook/booklet/.kpm-peki-kual)\" = installed"
              "grep -Fx -- rw /var/lib/kpm-consumer/kual-mntroot.log"
              "grep -Fx -- ro /var/lib/kpm-consumer/kual-mntroot.log"
              "test \"$(sqlite3 /var/local/appreg.db \"SELECT COUNT(*) FROM handlerIds WHERE handlerId = 'com.mobileread.ixtab.kindlelauncher';\")\" = 1"
              "grep -F -- 'com.lab126.appmgrd start app://com.mobileread.ixtab.kindlelauncher' /var/lib/kpm-consumer/lipc-set-prop.log"
            ];
          }
        ];
        uninstallAssertions = [
          "test -f /opt/amazon/ebook/booklet/KUALBooklet.jar"
          "test -f /opt/amazon/ebook/booklet/.kpm-peki-kual"
          "test \"$(sqlite3 /var/local/appreg.db \"SELECT COUNT(*) FROM handlerIds WHERE handlerId = 'com.mobileread.ixtab.kindlelauncher';\")\" = 1"
          "rm -f /opt/amazon/ebook/booklet/KUALBooklet.jar /opt/amazon/ebook/booklet/.kpm-peki-kual"
        ];
      });
      tests.recovery = pkgs.runCommand "peki-recovery-check" { } ''
        sh ${./check-recovery.sh} ${./peki.sh}
        touch "''${out}"
      '';
    };
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
