{ lib, pkgs }:
let
  mkKpackage = import ../lib/mk-kpackage.nix { inherit lib pkgs; };
  packageArguments = {
    inherit mkKpackage;
    inherit (pkgs) fetchurl;
  };
  packageIds = [
    "toggleads"
    "updateblockstatus"
    "kwordle"
    "kpomo"
    "kships"
    "kreate"
    "larkplayer"
    "gargoyle"
  ];
  loadPackage = packageId:
    import (./. + "/${packageId}/package.nix") packageArguments;
in
lib.concatMap loadPackage packageIds
