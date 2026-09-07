{ lib, pkgs }:
let
  mkKpackage = import ../lib/mk-kpackage.nix { inherit lib pkgs; };
  mkNativePackage = import ../lib/mk-native-package.nix { inherit lib pkgs; };
  mkWafPackage = import ../lib/mk-waf-package.nix {
    inherit mkKpackage;
    inherit (pkgs) writeTextFile;
  };
  packageArguments = {
    inherit mkKpackage mkNativePackage mkWafPackage pkgs;
    inherit (pkgs) fetchurl writeTextFile;
  };
  packageIds = [
    "alpinelinux"
    "toggleads"
    "updateblockstatus"
    "kwordle"
    "kpomo"
    "kships"
    "kreate"
    "larkplayer"
    "gargoyle"
    "hotfixupdater"
    "kindlecraft"
    "kindle-button-mapper"
    "kindlefetch"
    "kindle-hid-passthrough"
    "kinamp"
    "jarlauncher"
    "ranki"
    "gambatte-k2"
    "gnomegames"
    "kanki"
    "knotes"
    "kual"
    "sox"
    "textadept"
    "wordgrinder"
  ];
  loadPackage = packageId:
    let
      package = import (./. + "/${packageId}/package.nix");
    in
    package (lib.intersectAttrs (builtins.functionArgs package) packageArguments);
in
lib.concatMap loadPackage packageIds
