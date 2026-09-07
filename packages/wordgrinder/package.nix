{ mkKpackage
, mkNativePackage
, fetchurl
,
}:
let
  nativePackage = mkNativePackage {
    id = "wordgrinder";
    displayName = "WordGrinder";
    destination = "/mnt/us/wordgrinder";
    payloadPath = "payload/wordgrinder";
    scriptlets = [
      {
        source = "scriptlets/WordGrinder.sh";
        destination = "/mnt/us/documents/WordGrinder.sh";
      }
    ];
  };
in
[
  (mkKpackage {
    id = "wordgrinder";
    name = "WordGrinder";
    author = "kbarni";
    description = "Distraction-free word processor for Kindle";
    version = [
      0
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
      url = "https://github.com/kbarni/wordgrinder/releases/download/0.9.2/wordgrinder.zip";
      hash = "sha256-lWg37H2rCSHpEsIhmg5dWWwM/CAqCLy3xdKpbL+JcHM=";
    };
    buildPayload = ''
      mkdir -p payload scriptlets
      unzip -q "''${SOURCE}" -d unpacked
      mv unpacked/wordgrinder payload/wordgrinder
      sed -n 's/^# Icon: data:image\/png;base64,//p' unpacked/documents/wordgrinder.sh \
        | base64 -d > payload/wordgrinder/wordgrinder-cover.png
      printf '%s\n' \
        '# Name: WordGrinder' \
        '# Icon: /mnt/us/wordgrinder/wordgrinder-cover.png' \
        '# DontUseFBInk' \
        'exec /var/local/kmc/bin/kpm launch wordgrinder' \
        > scriptlets/WordGrinder.sh
      ${nativePackage.buildInventory}
    '';
    installScript = nativePackage.installScript;
    uninstallScript = nativePackage.uninstallScript;
    launchScript = ./launch.sh;
    scriptlet = {
      name = "WordGrinder.sh";
      path = "scriptlets/WordGrinder.sh";
      icon = "payload/wordgrinder/wordgrinder-cover.png";
      installedIcon = "/mnt/us/wordgrinder/wordgrinder-cover.png";
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
            verify = "grep -Fx -- '-e env HOME=/mnt/us sh /mnt/us/wordgrinder/start_wordgrinder.sh -k 0 -o R' /var/lib/kpm-consumer/kterm.log";
          }
        ];
        kindlepw2.launches = [
          {
            mode = "dispatch";
            args = [ ];
            boundaries = [ "kTerm terminal dispatch" ];
            actualApplicationExecution = false;
            setup = "rm -f /var/lib/kpm-consumer/kterm.log";
            verify = "grep -Fx -- '-e env HOME=/mnt/us sh /mnt/us/wordgrinder/start_wordgrinder.sh -k 0 -o R' /var/lib/kpm-consumer/kterm.log";
          }
        ];
      };
      abi.runtimeContexts = [
        {
          path = "payload/wordgrinder/wordgrinder";
          libraryPaths = [ "payload/wordgrinder/libs_hf" ];
        }
        {
          path = "payload/wordgrinder/wordgrinder_pw2";
          libraryPaths = [ "payload/wordgrinder/libs_pw2" ];
        }
      ];
    };
  })
]
