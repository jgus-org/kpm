{ mkKpackage
, fetchurl
, writeTextFile
,
}:
let
  mkWafPackage = import ../../lib/mk-waf-package.nix { inherit mkKpackage writeTextFile; };
  legacySrc = fetchurl {
    url = "https://github.com/crizmo/KPomo/releases/download/v1.0.0/kpomo-legacy.zip";
    hash = "sha256-RUeqpLMUq3BBmpahooIw5zAH172S7aw12j3amfyRroU=";
  };
in
[
  (mkWafPackage {
    id = "kpomo";
    name = "KPomo";
    author = "Kurizu";
    description = "Pomodoro focus timer for Kindle";
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
      url = "https://github.com/crizmo/KPomo/releases/download/v1.0.0/kpomo.zip";
      hash = "sha256-RFR0viIkw0HUg3FAGsj3BE0sJu9i5gX9pd3voH6RWG4=";
    };
    buildPayload = ''
      mkdir -p payload/modern
      unzip -q "''${SOURCE}" -d payload/modern
      unzip -q "${legacySrc}" -d payload/legacy
      unzip -p "''${SOURCE}" kpomo.sh \
        | sed -n 's|^# Icon: data:image/png;base64,||p' \
        | base64 -d > payload/kpomo-cover.png
    '';
    payloadDirectory = "payload/modern/kpomo";
    legacyPayloadDirectory = "payload/legacy/kpomo";
    legacyFirmwareMaximum = [
      5
      6
      1
      1
    ];
    mesquiteDirectory = "/var/local/mesquite/kpomo";
    appId = "xyz.kurizu.kpomo";
    scriptletName = "KPomo.sh";
    scriptletIcon = {
      path = "payload/kpomo-cover.png";
      mediaSubtype = "png";
    };
    legacyPaths = [
      "/mnt/us/documents/kpomo"
      "/mnt/us/documents/kpomo.sh"
    ];
    passthru.consumer.cases = {
      kindlehf.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.kurizu.kpomo' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
      kindlepw2.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.kurizu.kpomo' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
    };
  })
]
