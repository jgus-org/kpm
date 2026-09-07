{ mkKpackage
, mkNativePackage
, fetchurl
,
}:
let
  nativePackage = mkNativePackage {
    id = "kinamp";
    displayName = "KinAMP";
    destination = "/mnt/us/KinAMP";
    payloadPath = "payload/KinAMP";
    preservedPaths = [
      ".kinamp.conf"
      ".kinamp_radio.txt"
      ".kinamp_playlist.m3u"
      "allStations.json"
      "kinamp.log"
    ];
    scriptlets = [
      {
        source = "scriptlets/kinamp.sh";
        destination = "/mnt/us/documents/kinamp.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "kinamp";
    name = "KinAMP";
    author = "kbarni";
    description = "Music player for Kindle";
    version = [
      3
      0
      0
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = fetchurl {
      url = "https://github.com/kbarni/KinAMP/releases/download/3.0.0/kinamp.zip";
      hash = "sha256-d2CIQEUfg+rUNaRAUZg47pQRZqJYSgfrKgvgo7pqH60=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d unpacked
      mv unpacked/KinAMP payload/KinAMP
      mv unpacked/koreader/plugins/kinamp.koplugin payload/KinAMP/koreader-plugin
      cp payload/KinAMP/koreader-plugin/icons/kinamp_icon.png payload/KinAMP/kinamp_icon.png
      printf '%s\n' \
        '# Name: KinAMP' \
        '# Icon: /mnt/us/KinAMP/kinamp_icon.png' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch kinamp' \
        > scriptlets/kinamp.sh
      ${nativePackage.buildInventory}
    '';
    installScript = nativePackage.installScript;
    uninstallScript = nativePackage.uninstallScript;
    launchScript = ./launch.sh;
    scriptlet = {
      name = "kinamp.sh";
      path = "scriptlets/kinamp.sh";
      icon = "payload/KinAMP/kinamp_icon.png";
      installedIcon = "/mnt/us/KinAMP/kinamp_icon.png";
    };
    passthru.native = nativePackage.passthru;
  })
]
