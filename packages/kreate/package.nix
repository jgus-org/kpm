{ mkKpackage, fetchurl }:
let
  mkWafPackage = import ../../lib/mk-waf-package.nix { inherit mkKpackage; };
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
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://raw.githubusercontent.com/KindleTweaks/Repository/512437b4bcb2d9994dedd52feb2f0c7b4c426344/Kreate/assets/kreate.zip";
      hash = "sha256-CiD6bbfZqztIHcfDADogBI28/iIyeNESk0EY5jdqsw4=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
    '';
    payloadDirectory = "payload/kreate";
    mesquiteDirectory = "/var/local/mesquite/kreate";
    appId = "xyz.foskya.kreate";
  })
]
