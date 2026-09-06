{ mkKpackage, fetchurl }:

[
  (mkKpackage {
    id = "gargoyle";
    name = "Gargoyle";
    author = "Barna, Pete330";
    description = "Text adventure interpreter";
    version = [
      0
      1
      0
    ];
    platforms = [ "kindlehf" ];
    src = fetchurl {
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=214325&d=1741982302";
      hash = "sha256-f+lYojl0pTqoTNNQpE2npyF60C2L3JsCkhZb12yAzTk=";
    };
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
    '';
    installScript = ./install.sh;
    uninstallScript = ./uninstall-hf.sh;
  })
  (mkKpackage {
    id = "gargoyle";
    name = "Gargoyle";
    author = "Barna, Pete330";
    description = "Text adventure interpreter";
    version = [
      0
      1
      0
    ];
    platforms = [ "kindlepw2" ];
    src = fetchurl {
      url = "https://www.mobileread.com/forums/attachment.php?attachmentid=168543&d=1545424119";
      hash = "sha256-co1Fv3SEwPnqTUKeiNmbIweQDVPZB5+jNqNHuh5u4ho=";
    };
    buildPayload = ''
      mkdir -p payload
      tar -xzf "''${SOURCE}" -C payload
    '';
    installScript = ./install.sh;
    uninstallScript = ./uninstall-sf.sh;
  })
]
