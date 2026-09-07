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
    id = "kreate";
    name = "Kreate";
    author = "Foskya";
    description = "Simple drawing application for Kindle";
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
      url = "https://raw.githubusercontent.com/KindleTweaks/Repository/512437b4bcb2d9994dedd52feb2f0c7b4c426344/Kreate/assets/kreate.zip";
      hash = "sha256-CiD6bbfZqztIHcfDADogBI28/iIyeNESk0EY5jdqsw4=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
      unzip -p "''${SOURCE}" kreate/kreate.sh \
        | sed -n 's|^# Icon: data:image/png;base64,||p' \
        | base64 -d > payload/kreate-cover.png
    '';
    payloadDirectory = "payload/kreate";
    mesquiteDirectory = "/var/local/mesquite/kreate";
    appId = "xyz.foskya.kreate";
    scriptletName = "Kreate.sh";
    scriptletIcon = {
      path = "payload/kreate-cover.png";
      mediaSubtype = "png";
    };
    legacyPaths = [ "/mnt/us/documents/kreate" ];
    passthru.consumer.cases = {
      kindlehf.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.foskya.kreate' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
      kindlepw2.launches = [
        {
          mode = "dispatch";
          args = [ ];
          boundaries = [ "LIPC app manager dispatch" ];
          actualApplicationExecution = false;
          setup = "rm -f /var/lib/kpm-consumer/lipc-set-prop.log";
          verify = "grep -F -- 'com.lab126.appmgrd start app://xyz.foskya.kreate' /var/lib/kpm-consumer/lipc-set-prop.log";
        }
      ];
    };
  })
]
