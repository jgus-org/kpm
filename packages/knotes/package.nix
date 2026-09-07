{ mkKpackage
, fetchurl
, writeTextFile
,
}:

let
  mkWafPackage = import ../../lib/mk-waf-package.nix { inherit mkKpackage writeTextFile; };
in
[
  (mkWafPackage {
    id = "knotes";
    name = "KNotes";
    author = "Kurizu";
    description = "Notes and kanban app for Kindle";
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
      url = "https://github.com/crizmo/KNotes/releases/download/v1.0-beta.1/KNotes.zip";
      hash = "sha256-uJ81ih+l+JZeaKTz0vweqeNg6HZHbLHUoGjIhFRA5Yg=";
    };
    buildPayload = ''
      mkdir -p payload/knotes
      unzip -q "''${SOURCE}" -d payload/knotes
      chmod 755 payload/knotes/KNotes/assets/UtildHF payload/knotes/KNotes/assets/UtildSF
      unzip -p "''${SOURCE}" KNotes.sh \
        | sed -n 's|^# Icon: data:image/png;base64,||p' \
        | base64 -d > payload/knotes-cover.png
    '';
    payloadDirectory = "payload/knotes/KNotes";
    mesquiteDirectory = "/var/local/mesquite/knotes";
    appId = "xyz.kurizu.knotes";
    scriptletName = "KNotes.sh";
    scriptletIcon = {
      path = "payload/knotes-cover.png";
      mediaSubtype = "png";
    };
    documents = {
      directory = "/mnt/us/documents/KNotes";
      payloadDirectory = null;
      retainedPaths = [ "notes" ];
    };
    launchPrelude = ''
      if ! lipc-get-prop com.kindlemodding.utild runCMD >/dev/null 2>&1; then
        if [ -e /lib/ld-linux-armhf.so.3 ]; then
          UTILD=/mnt/us/documents/KNotes/assets/UtildHF
        else
          UTILD=/mnt/us/documents/KNotes/assets/UtildSF
        fi
        "''${UTILD}"
        UTILD_ATTEMPTS=0
        until lipc-get-prop com.kindlemodding.utild runCMD >/dev/null 2>&1; do
          UTILD_ATTEMPTS=$((UTILD_ATTEMPTS + 1))
          if [ "''${UTILD_ATTEMPTS}" -eq 5 ]; then
            echo 'Utild did not become ready' >&2
            exit 1
          fi
          sleep 1
        done
      fi
    '';
    legacyPaths = [
      "/mnt/us/documents/KNotes"
      "/mnt/us/documents/KNotes.sh"
    ];
    passthru.consumer.cases = {
      kindlehf.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.kurizu.knotes' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
      kindlepw2.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.kurizu.knotes' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
    };
  })
]
