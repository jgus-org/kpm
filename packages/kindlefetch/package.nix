{ mkKpackage
, mkNativePackage
, fetchurl
,
}:
let
  nativePackage = mkNativePackage {
    id = "kindlefetch";
    displayName = "KindleFetch";
    destination = "/mnt/us/extensions/kindlefetch";
    payloadPath = "payload/kindlefetch";
    preservedPaths = [
      "bin/kindlefetch_config"
      "bin/zlib_cookies.txt"
    ];
    scriptlets = [
      {
        source = "scriptlets/KindleFetch.sh";
        destination = "/mnt/us/documents/KindleFetch.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "kindlefetch";
    name = "KindleFetch";
    author = "justrals";
    description = "Book downloader for kTerm";
    version = [
      1
      3
      0
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    dependencies = [
      {
        id = "kterm";
        min = [
          2
          6
          0
        ];
      }
    ];
    src = fetchurl {
      url = "https://github.com/justrals/KindleFetch/releases/download/v1.3/kindlefetch.zip";
      hash = "sha256-5DNV3ZPZi96jX30axu3u8FNnPhP+cBI0lOsVgpf/6RE=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d payload
      rm -f payload/kindlefetch/bin/update.sh
      sed -i \
        -e '\|update.sh|d' \
        -e '/check_for_updates/d' \
        -e '/^UPDATE_AVAILABLE=/d' \
        -e '/if \$UPDATE_AVAILABLE; then/,/fi/d' \
        -e '/^            6)  /,/^                ;;$/d' \
        payload/kindlefetch/bin/kindlefetch.sh
      sed -i \
        -e 's/6\. Check for updates/6. Back to main menu/' \
        -e '/^            6)$/,+3c\
            6)\
                break\
                ;;' \
        -e '/^            7)$/,+2d' \
        payload/kindlefetch/bin/settings.sh
      printf '%s\n' \
        '# Name: KindleFetch' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch kindlefetch' \
        > scriptlets/KindleFetch.sh
      ${nativePackage.buildInventory}
    '';
    installScript = nativePackage.installScript;
    uninstallScript = nativePackage.uninstallScript;
    launchScript = ./launch.sh;
    scriptlet = {
      name = "KindleFetch.sh";
      path = "scriptlets/KindleFetch.sh";
      icon = null;
    };
    passthru.native = nativePackage.passthru;
  })
]
