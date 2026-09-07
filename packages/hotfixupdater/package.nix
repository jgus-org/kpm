{ mkKpackage
, mkNativePackage
, fetchurl
, pkgs
,
}:

let
  license = fetchurl {
    url = "https://raw.githubusercontent.com/KindleTweaks/HotfixUpdater/d1048489ac1d8a214b8da82d878e17b0efd59c46/LICENSE";
    hash = "sha256-E0mkthSEkrRPYp5k7tZ2YS4jT+moOeTzsnfBSCyISfE=";
  };
  kindleToolLicense = fetchurl {
    url = "https://raw.githubusercontent.com/KindleModding/KindleTool/4d559f6c5b3ebf7dd2d5cfb26c7fd9a601234eda/LICENSE";
    hash = "sha256-jOtLnuWt7d5Hsx6XXB2QxzrSe2sWWh3NgMfFRetluQM=";
  };
  source = fetchurl {
    url = "https://github.com/KindleTweaks/HotfixUpdater/releases/download/v1.0.2/HotfixUpdater.zip";
    hash = "sha256-lkNniFoGKjVq7nXtT5arrCIWuU94yQrIa2D8BK43ZRc=";
  };
  native = mkNativePackage {
    id = "hotfixupdater";
    displayName = "HotfixUpdater";
    destination = "/mnt/us/documents/HotfixUpdater";
    payloadPath = "payload/HotfixUpdater";
    scriptlets = [
      {
        source = "scriptlets/HotfixUpdater.sh";
        destination = "/mnt/us/documents/HotfixUpdater.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "hotfixupdater";
    name = "HotfixUpdater";
    author = "KindleTweaks";
    description = "Update an installed Universal Hotfix";
    version = [
      1
      0
      2
    ];
    platforms = [
      "kindlehf"
      "kindlepw2"
    ];
    src = source;
    buildPayload = ''
      unzip -q "''${SOURCE}" -d unpacked
      mkdir -p payload/HotfixUpdater scriptlets
      cp unpacked/HotfixUpdater/KTHF unpacked/HotfixUpdater/KTPW2 payload/HotfixUpdater/
      cp unpacked/HotfixUpdater.sh payload/HotfixUpdater/updater.sh
      patch -p1 < ${./updater.patch}
      sed -i '/^[[:space:]]*if \[ -z \"\$DOWNLOAD_URL\" \]; then/i\    case "$DOWNLOAD_URL" in https://github.com/KindleModding/Hotfix/releases/download/*/Update_hotfix_universal.bin) ;; *) alert "HotfixUpdater - Attention" "Unexpected update download URL!"; exit 1 ;; esac' payload/HotfixUpdater/updater.sh
      cp ${license} payload/HotfixUpdater/LICENSE
      cp ${kindleToolLicense} payload/HotfixUpdater/LICENSE-KindleTool
      {
        sed -n '1,5p' unpacked/HotfixUpdater.sh
        printf '%s\n' 'exec /var/local/kmc/bin/kpm launch hotfixupdater'
      } > scriptlets/HotfixUpdater.sh
      sed -n 's/^# Icon: data:image\/png;base64,//p' unpacked/HotfixUpdater.sh | base64 -d > payload/HotfixUpdater/icon.png
      chmod +x payload/HotfixUpdater/KTHF payload/HotfixUpdater/KTPW2 payload/HotfixUpdater/updater.sh
      ${native.buildInventory}
    '';
    scriptlet = {
      name = "HotfixUpdater.sh";
      path = "scriptlets/HotfixUpdater.sh";
      icon = "payload/HotfixUpdater/icon.png";
    };
    passthru = {
      native = native.passthru;
      tests.recovery = pkgs.runCommand "hotfixupdater-recovery-check"
        {
          nativeBuildInputs = [ pkgs.unzip ];
          SOURCE = source;
        } ''
        unzip -q "''${SOURCE}" -d unpacked
        mkdir -p payload/HotfixUpdater
        cp unpacked/HotfixUpdater.sh payload/HotfixUpdater/updater.sh
        patch -p1 < ${./updater.patch}
        sh ${./check-recovery.sh} payload/HotfixUpdater/updater.sh
        touch "''${out}"
      '';
    };
    inherit (native) installScript uninstallScript;
    launchScript = ./launch.sh;
  })
]
