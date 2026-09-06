{ lib, pkgs }:
let
  mkKpackage = import ../lib/mk-kpackage.nix { inherit lib pkgs; };
  packageArguments = {
    inherit mkKpackage;
    inherit (pkgs) fetchurl writeTextFile;
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
    let
      package = import (./. + "/${packageId}/package.nix");
    in
    package (lib.intersectAttrs (builtins.functionArgs package) packageArguments);
in
lib.concatMap loadPackage packageIds
