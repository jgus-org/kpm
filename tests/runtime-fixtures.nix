{ lib, pkgs }:

let
  makeFixture =
    { name
    , url
    , hash
    , toolchain
    , glibc
    , kernel
    , floatAbi
    }:
    pkgs.runCommand name
      {
        src = pkgs.fetchurl { inherit url hash; };
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.zstd
        ];
        passthru = {
          inherit floatAbi glibc kernel;
        };
      }
      ''
        EXTRACT_ROOT=extracted
        mkdir "''${EXTRACT_ROOT}"
        ${lib.getExe pkgs.gnutar} \
          --use-compress-program=${lib.getExe' pkgs.zstd "unzstd"} \
          -xf "''${src}" \
          -C "''${EXTRACT_ROOT}" \
          "x-tools/${toolchain}/${toolchain}/sysroot/lib" \
          "x-tools/${toolchain}/${toolchain}/sysroot/usr/lib"
        SYSROOT="''${EXTRACT_ROOT}/x-tools/${toolchain}/${toolchain}/sysroot"
        mkdir -p "''${out}"
        cp -a "''${SYSROOT}/lib" "''${SYSROOT}/usr" "''${out}/"
      '';
in
{
  kindlehf = makeFixture {
    name = "koreader-kindlehf-runtime-2026.08";
    url = "https://github.com/koreader/koxtoolchain/releases/download/2026.08/kindlehf.tar.zst";
    hash = "sha256-jMffvXGr14+elH1rLiBnAoikQC7cewcXa8p5H36vh9A=";
    toolchain = "arm-kindlehf-linux-gnueabihf";
    glibc = "2.20";
    kernel = "4.1";
    floatAbi = "hard";
  };
  kindlepw2 = makeFixture {
    name = "koreader-kindlepw2-runtime-2026.08";
    url = "https://github.com/koreader/koxtoolchain/releases/download/2026.08/kindlepw2.tar.zst";
    hash = "sha256-hLyLQUN5a6DJ5jBq78WWyi4mhc+RdKKFuxTzZCXegQQ=";
    toolchain = "arm-kindlepw2-linux-gnueabi";
    glibc = "2.12.2";
    kernel = "3.0.35";
    floatAbi = "soft";
  };
}
