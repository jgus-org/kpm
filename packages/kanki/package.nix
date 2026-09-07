{ mkKpackage
, fetchurl
, writeTextFile
,
}:

let
  mkWafPackage = import ../../lib/mk-waf-package.nix { inherit mkKpackage writeTextFile; };
  legacySrc = fetchurl {
    url = "https://github.com/crizmo/KAnki/releases/download/v1.1.2/kanki-legacy.zip";
    hash = "sha256-eTCUm7weZFc/IoRAd1Es1VNACQMXGKcnqrKFH3i2TsA=";
  };
in
[
  (mkWafPackage {
    id = "kanki";
    name = "KAnki";
    author = "Kurizu";
    description = "Flashcard app for Kindle";
    version = [
      1
      1
      2
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/crizmo/KAnki/releases/download/v1.1.2/kanki.zip";
      hash = "sha256-ADQI7ffHcLXs/UsN/10NM0V15rd1iobfu18O+rr3voc=";
    };
    buildPayload = ''
      mkdir -p payload/modern payload/legacy
      unzip -q "''${SOURCE}" -d payload/modern
      unzip -q "${legacySrc}" -d payload/legacy
      unzip -p "''${SOURCE}" kanki.sh \
        | sed -n 's|^# Icon: data:image/png;base64,||p' \
        | base64 -d > payload/kanki-cover.png
    '';
    payloadDirectory = "payload/modern/kanki";
    legacyPayloadDirectory = "payload/legacy/kanki";
    legacyFirmwareMaximum = [
      5
      12
      2
      2
    ];
    mesquiteDirectory = "/var/local/mesquite/kanki";
    appId = "xyz.kurizu.kanki";
    scriptletName = "KAnki.sh";
    scriptletIcon = {
      path = "payload/kanki-cover.png";
      mediaSubtype = "png";
    };
    documents = {
      directory = "/mnt/us/documents/kanki";
      payloadDirectory = null;
      retainedPaths = [
        "assets/fonts/language.ttf"
        "js/kanki_config.js"
      ];
    };
    launchPrelude = ''
      cp /mnt/us/documents/kanki/assets/fonts/language.ttf /var/local/mesquite/kanki/assets/fonts/language.ttf
      cp /mnt/us/documents/kanki/js/kanki_config.js /var/local/mesquite/kanki/js/kanki_config.js
    '';
    legacyPaths = [
      "/mnt/us/documents/kanki"
      "/mnt/us/documents/kanki.sh"
    ];
    passthru.consumer.cases = {
      kindlehf.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = ''
            printf '%s' language-font > /mnt/us/documents/kanki/assets/fonts/language.ttf
            printf '%s' kanki-configuration > /mnt/us/documents/kanki/js/kanki_config.js
            rm -f /var/lib/kpm-consumer/lipc-set-prop.log
          '';
          verify = ''
            cmp -s /mnt/us/documents/kanki/assets/fonts/language.ttf /var/local/mesquite/kanki/assets/fonts/language.ttf
            cmp -s /mnt/us/documents/kanki/js/kanki_config.js /var/local/mesquite/kanki/js/kanki_config.js
            grep -F -- 'com.lab126.appmgrd start app://xyz.kurizu.kanki' /var/lib/kpm-consumer/lipc-set-prop.log
          '';
        }
      ];
      kindlepw2.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = ''
            printf '%s' language-font > /mnt/us/documents/kanki/assets/fonts/language.ttf
            printf '%s' kanki-configuration > /mnt/us/documents/kanki/js/kanki_config.js
            rm -f /var/lib/kpm-consumer/lipc-set-prop.log
          '';
          verify = ''
            cmp -s /mnt/us/documents/kanki/assets/fonts/language.ttf /var/local/mesquite/kanki/assets/fonts/language.ttf
            cmp -s /mnt/us/documents/kanki/js/kanki_config.js /var/local/mesquite/kanki/js/kanki_config.js
            grep -F -- 'com.lab126.appmgrd start app://xyz.kurizu.kanki' /var/lib/kpm-consumer/lipc-set-prop.log
          '';
        }
      ];
    };
  })
]
