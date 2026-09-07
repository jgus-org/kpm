{ mkKpackage, fetchurl }:

[
  (mkKpackage {
    id = "larkplayer";
    name = "LARKPlayer";
    author = "Barna";
    description = "Libre audiobook reader for Kindle";
    version = [
      2
      8
      1
    ];
    platforms = [ "kindlehf" "kindlepw2" ];
    src = fetchurl {
      url = "https://github.com/kbarni/LARKPlayer/releases/download/2.8.1/lark.zip";
      hash = "sha256-wtBErmAlz+RGkr/TQsQRMKzv1DvMbFUZ+nYIQzJe9zI=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
      sed -i '/^cd \/mnt\/us\/LARK$/,$d' payload/documents/lark.sh
      printf '%s\n' 'exec /var/local/kmc/bin/kpm launch larkplayer' >> payload/documents/lark.sh
    '';
    scriptlet = {
      name = "lark.sh";
      path = "payload/documents/lark.sh";
      icon = null;
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall.sh;
    launchScript = ./launch.sh;
  })
]
