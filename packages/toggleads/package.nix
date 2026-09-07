{ mkKpackage, fetchurl, pkgs }:
let
  consumerSqlite = pkgs.writeShellScript "toggleads-consumer-sqlite" ''
    DATABASE="''${1}"
    QUERY="''${2}"
    printf '%s\n' \
      '.output /dev/null' \
      '.dbconfig dqs_dml on' \
      '.output stdout' \
      "''${QUERY}" \
      | ${pkgs.lib.getExe pkgs.sqlite} "''${DATABASE}"
  '';
in
[
  (mkKpackage {
    id = "toggleads";
    name = "Toggle ADs";
    author = "Marek & Penguins";
    description = "Toggle Kindle advertisements";
    version = [
      1
      1
      0
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://raw.githubusercontent.com/KindleTweaks/Repository/512437b4bcb2d9994dedd52feb2f0c7b4c426344/ToggleAds/assets/toggle-ads.sh";
      hash = "sha256-TsKUgSyv0Il40xyVxQ7K7zUtWGUeIcvMnY9f4HIHRgg=";
    };
    buildPayload = ''
      mkdir -p payload
      cp "''${SOURCE}" payload/toggle-ads.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' "''${SOURCE}" | base64 -d > payload/toggle-ads.png
      mkdir scriptlets
      {
        sed -n '/^# Icon: data:image\/png;base64,/p' "''${SOURCE}"
        printf '%s\n' '# DontUseFBInk' 'exec /var/local/kmc/bin/kpm launch toggleads'
      } > scriptlets/toggle-ads.sh
    '';
    scriptlet = {
      name = "toggle-ads.sh";
      icon = "payload/toggle-ads.png";
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
              "Kindle SQLite DQS mode shim"
              "reboot service shim"
            ];
            actualApplicationExecution = true;
            pathPrefix = [ "/var/lib/kpm-consumer/toggleads/bin" ];
            setup = ''
              mkdir -p /var/lib/kpm-consumer/toggleads/bin
              ln -sf ${consumerSqlite} /var/lib/kpm-consumer/toggleads/bin/sqlite3
              sqlite3 /var/local/appreg.db \
                "INSERT INTO properties(handlerId, name, value) VALUES('com.lab126.test', 'adunit.viewable', 'false');"
              rm -f /var/lib/kpm-consumer/boundary.log
            '';
            verify = [
              "test \"$(sqlite3 /var/local/appreg.db \"SELECT value FROM properties WHERE name = 'adunit.viewable';\")\" = true"
              "grep -F -- reboot /var/lib/kpm-consumer/boundary.log"
            ];
          }
        ];
        installAssertions = "test -f /mnt/us/documents/toggle-ads.sh";
        uninstallAssertions = "test ! -e /mnt/us/documents/toggle-ads.sh";
      });
      tests.callback = pkgs.runCommand "toggleads-callback-check" { } ''
        sh ${./check-callback.sh} ${./install.sh} ${./uninstall.sh}
        touch "''${out}"
      '';
    };
  })
]
