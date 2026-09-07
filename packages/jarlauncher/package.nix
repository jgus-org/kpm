{ mkKpackage
, mkNativePackage
, fetchurl
,
}:

let
  makeArtifact =
    { platform
    , java
    ,
    }:
    let
      native = mkNativePackage {
        id = "jarlauncher";
        displayName = "JarLauncher";
        destination = "/mnt/us/extensions/JarLauncher";
        payloadPath = "payload/JarLauncher";
        preservedPaths = [
          "bin/config.sh"
          "jar.jar"
        ];
        scriptlets = [
          {
            source = "scriptlets/JarLauncher.sh";
            destination = "/mnt/us/documents/JarLauncher.sh";
          }
        ];
      };
    in
    mkKpackage {
      id = "jarlauncher";
      name = "JarLauncher";
      author = "ThatPotatoDev";
      description = "Run a user-provided Java archive through kTerm";
      version = [
        0
        1
        2
      ];
      platforms = [ platform ];
      dependencies = [
        {
          id = "kterm";
          min = [
            2
            6
            0
          ];
          max = [
            3
            0
            0
          ];
        }
      ];
      buildPayload = ''
        mkdir -p payload/JarLauncher/bin payload/JarLauncher/Java payload/JarLauncher/run scriptlets
        printf '%s\n' \
          'JAVA_ARGS="-Xss512k"' \
          'JAR_PATH="''${JARLAUNCHER_DIR}/jar.jar"' \
          'JAR_ARGS=""' \
          > payload/JarLauncher/bin/config.sh
        cp ${./run.sh} payload/JarLauncher/run/start.sh
        tar -xzf ${java} -C payload/JarLauncher/Java --strip-components=1
        while IFS= read -r -d ''' LINK_PATH; do
          LINK_TARGET=$(readlink -f "''${LINK_PATH}")
          MATERIALIZED_PATH="''${LINK_PATH}.materialized"
          if [ -d "''${LINK_TARGET}" ]; then
            cp -R "''${LINK_TARGET}" "''${MATERIALIZED_PATH}"
          else
            cp "''${LINK_TARGET}" "''${MATERIALIZED_PATH}"
          fi
          rm "''${LINK_PATH}"
          mv "''${MATERIALIZED_PATH}" "''${LINK_PATH}"
        done < <(find payload/JarLauncher/Java -type l -print0)
        printf '%s\n' \
          '# Name: JarLauncher' \
          '# DontUseFBInk' \
          'exec /var/local/kmc/bin/kpm launch jarlauncher' \
          > scriptlets/JarLauncher.sh
        chmod +x payload/JarLauncher/run/start.sh
        ${native.buildInventory}
      '';
      scriptlet = {
        name = "JarLauncher.sh";
        path = "scriptlets/JarLauncher.sh";
        icon = null;
      };
      passthru.native = native.passthru;
      inherit (native) installScript uninstallScript;
      launchScript = ./launch.sh;
    };
in
[
  (makeArtifact {
    platform = "kindlehf";
    java = fetchurl {
      url = "https://cdn.azul.com/zulu-embedded/bin/zulu8.76.0.17-ca-jre8.0.402-linux_aarch32hf.tar.gz";
      hash = "sha256-0z39OwIwJ2yTmpdQjixhE3ujkA6p41pj4DylFg1Dy1g=";
    };
  })
  (makeArtifact {
    platform = "kindlepw2";
    java = fetchurl {
      url = "https://cdn.azul.com/zulu-embedded/bin/zulu8.76.0.17-ca-cp2-jre8.0.402-linux_aarch32sf.tar.gz";
      hash = "sha256-NWJ8R9DB3VwhZstRgsrPkMS5/Zu7xZF2NeLznXHmfnM=";
    };
  })
]
