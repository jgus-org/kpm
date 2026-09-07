{ mkKpackage
, mkNativePackage
, fetchurl
,
}:
let
  nativePackage = mkNativePackage {
    id = "textadept";
    displayName = "Textadept";
    destination = "/mnt/us/textadept";
    payloadPath = "payload/textadept";
    scriptlets = [
      {
        source = "scriptlets/Textadept.sh";
        destination = "/mnt/us/documents/Textadept.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "textadept";
    name = "Textadept";
    author = "kbarni";
    description = "Programmable text editor for Kindle";
    version = [
      12
      9
      2
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
      url = "https://github.com/kbarni/textadept-kindle/releases/download/12.9.2/textadept.zip";
      hash = "sha256-RPoV1AfrFfOV9Kv3VW6T9P7WGek7cfwtFSxZTR/ZAfU=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d unpacked
      mv unpacked/textadept payload/textadept
      sed -n 's/^# Icon: data:image\/png;base64,//p' unpacked/documents/textadept.sh \
        | base64 -d > payload/textadept/textadept-cover.png
      printf '%s\n' \
        '# Name: Textadept' \
        '# Icon: /mnt/us/textadept/textadept-cover.png' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch textadept' \
        > scriptlets/Textadept.sh
      ${nativePackage.buildInventory}
    '';
    installScript = nativePackage.installScript;
    uninstallScript = nativePackage.uninstallScript;
    launchScript = ./launch.sh;
    scriptlet = {
      name = "Textadept.sh";
      path = "scriptlets/Textadept.sh";
      icon = "payload/textadept/textadept-cover.png";
      installedIcon = "/mnt/us/textadept/textadept-cover.png";
    };
    passthru = {
      native = nativePackage.passthru;
      consumer.cases = {
        kindlehf.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [ "kTerm terminal dispatch" ];
            actualApplicationExecution = false;
            setup = "rm -f /var/lib/kpm-consumer/kterm.log";
            verify = "grep -Fx -- '-e env HOME=/mnt/us sh /mnt/us/textadept/run.sh textadept-curses -k 0 -o R' /var/lib/kpm-consumer/kterm.log";
          }
        ];
        kindlepw2.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [ "kTerm terminal dispatch" ];
            actualApplicationExecution = false;
            setup = "rm -f /var/lib/kpm-consumer/kterm.log";
            verify = "grep -Fx -- '-e env HOME=/mnt/us sh /mnt/us/textadept/run.sh textadept-curses -k 0 -o R' /var/lib/kpm-consumer/kterm.log";
          }
        ];
      };
      abi.runtimeContexts = [
        {
          path = "payload/textadept/textadept-curses";
          libraryPaths = [ "payload/textadept/libs_hf" ];
        }
        {
          path = "payload/textadept/textadept-gtk";
          libraryPaths = [ "payload/textadept/libs_hf" ];
        }
        {
          path = "payload/textadept/textadept-curses-pw2";
          libraryPaths = [ "payload/textadept/libs_pw2" ];
        }
        {
          path = "payload/textadept/textadept-gtk-pw2";
          libraryPaths = [ "payload/textadept/libs_pw2" ];
        }
      ];
    };
  })
]
