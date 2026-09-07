{ mkKpackage, fetchurl }:

let
  hfSource = fetchurl {
    url = "https://www.mobileread.com/forums/attachment.php?attachmentid=214325&d=1741982302";
    hash = "sha256-f+lYojl0pTqoTNNQpE2npyF60C2L3JsCkhZb12yAzTk=";
  };
in

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
    src = hfSource;
    buildPayload = ''
      mkdir -p payload
      unzip -q "''${SOURCE}" -d payload
      mkdir scriptlets
      {
        printf '%s' '# Icon: data:image/png;base64,'
        base64 -w0 payload/gargoyle/gargoyle.png
        printf '\n'
        printf '%s\n' '# DontUseFBInk' 'exec /var/local/kmc/bin/kpm launch gargoyle'
      } > scriptlets/Gargoyle.sh
    '';
    scriptlet = {
      name = "Gargoyle.sh";
      icon = "payload/gargoyle/gargoyle.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall-hf.sh;
    launchScript = ./launch.sh;
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
      mkdir scriptlets
      {
        printf '%s' '# Icon: data:image/png;base64,'
        unzip -p "${hfSource}" gargoyle/gargoyle.png | base64 -w0
        printf '\n'
        printf '%s\n' '# DontUseFBInk' 'exec /var/local/kmc/bin/kpm launch gargoyle'
      } > scriptlets/Gargoyle.sh
      unzip -p "${hfSource}" gargoyle/gargoyle.png > scriptlets/gargoyle.png
    '';
    scriptlet = {
      name = "Gargoyle.sh";
      icon = "scriptlets/gargoyle.png";
    };
    installScript = ./install.sh;
    uninstallScript = ./uninstall-sf.sh;
    launchScript = ./launch.sh;
  })
]
