{ lib, pkgs }:
{ artifacts }:

let
  fixtures = import ./runtime-fixtures.nix { inherit lib pkgs; };
  armHardFloat = pkgs.pkgsCross.armv7l-hf-multiplatform;
  emulationRuntimes = {
    nix-armhf = {
      loader = "${armHardFloat.glibc}/lib/ld-linux-armhf.so.3";
      libraryPaths = [
        "${armHardFloat.stdenv.cc.cc.lib}/${armHardFloat.stdenv.targetPlatform.config}/lib"
        "${armHardFloat.zlib}/lib"
        "${armHardFloat.glibc}/lib"
      ];
    };
    nix-armel.unavailableReason = "no genuine soft-float Nix ARM runtime is available";
  };
  configuration = pkgs.writeText "kpm-abi-check.json" (builtins.toJSON {
    artifacts = map
      (artifact: {
        id = artifact.kpm.id;
        archive = "${artifact}/${artifact.kpm.filename}";
        platforms = artifact.kpm.platforms;
        runtimeContexts = artifact.abi.runtimeContexts or [ ];
        functionalTests = map
          (test: {
            inherit (test) name;
            script = toString test.script;
          } // lib.optionalAttrs (test ? runtime) { inherit (test) runtime; })
          (artifact.abi.functionalTests or [ ]);
      })
      artifacts;
    fixtures = lib.mapAttrs
      (platform: fixture: {
        path = toString fixture;
        inherit (fixture) floatAbi glibc kernel;
      })
      fixtures;
    inherit emulationRuntimes;
  });
in
pkgs.runCommand "kpm-abi-check"
{
  nativeBuildInputs = [
    pkgs.qemu-user
    (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyelftools ]))
  ];
}
  ''
    python ${./abi/check.py} ${configuration} "''${out}"
  ''
