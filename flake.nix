{
  description = "KPM development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , treefmt-nix
    , ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      treefmtEval = system: treefmt-nix.lib.evalModule (import nixpkgs { inherit system; }) ./treefmt.nix;
      packageSet =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          artifacts = import ./packages {
            inherit (pkgs) lib;
            inherit pkgs;
          };
          repository =
            import ./lib/mk-repository.nix
              {
                inherit (pkgs) lib;
                inherit pkgs;
              }
              {
                inherit artifacts;
              };
        in
        {
          inherit artifacts pkgs repository;
        };
    in
    {
      formatter = eachSystem (system: (treefmtEval system).config.build.wrapper);
      packages = eachSystem (
        system:
        let
          packageData = packageSet system;
          artifactName =
            artifact:
            let
              sameId = candidate: candidate.kpm.id == artifact.kpm.id;
            in
            if builtins.length (builtins.filter sameId packageData.artifacts) > 1 then
              "${artifact.kpm.id}-${builtins.concatStringsSep "-" artifact.kpm.platforms}"
            else
              artifact.kpm.id;
          namedArtifacts = builtins.listToAttrs (
            map
              (artifact: {
                name = artifactName artifact;
                value = artifact;
              })
              packageData.artifacts
          );
        in
        namedArtifacts
        // {
          default = packageData.repository;
          repository = packageData.repository;
        }
      );
      checks = eachSystem (
        system:
        let
          packageData = packageSet system;
        in
        {
          formatting = (treefmtEval system).config.build.check self;
          repository =
            import ./lib/check-repository.nix
              {
                inherit (packageData.pkgs) lib;
                pkgs = packageData.pkgs;
              }
              {
                inherit (packageData) artifacts repository;
              };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          abi =
            import ./tests/check-abi.nix
              {
                inherit (packageData.pkgs) lib;
                pkgs = packageData.pkgs;
              }
              {
                inherit (packageData) artifacts;
              };
          kpm-consumer =
            import ./tests/kpm-consumer.nix
              {
                inherit (packageData.pkgs) lib;
                pkgs = packageData.pkgs;
              }
              {
                inherit (packageData) artifacts repository;
              };
        }
      );
      devShells = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ (treefmtEval system).config.build.devShell ];
            packages = [ pkgs.shellcheck ];
          };
        }
      );
    };
}
