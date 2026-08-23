{
  _7zz ? null,
  alsa-lib ? null,
  autoPatchelfHook ? null,
  fetchurl,
  fetchzip,
  lib,
  makeWrapper ? null,
  nodejs_22 ? null,
  stdenv,
  stdenvNoCC,
}:

let
  release = "1.15.0+nightly.3083.66ed3027b8ca7fed0feeee91d1ce6346ccd4ac39";
  releaseUrl = "https://cloud.zed.dev/releases/nightly/${release}/download";
  common = {
    pname = "zed-editor";
    version = release;

    passthru = {
      zedDistribution = "official-nightly-binary";
      zedRelease = release;
    };

    meta = {
      description = "Official prebuilt Zed Nightly editor";
      homepage = "https://zed.dev";
      license = lib.licenses.gpl3Only;
      mainProgram = "zed";
      platforms = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
if stdenvNoCC.hostPlatform.isDarwin then
  stdenvNoCC.mkDerivation (
    common
    // {
      src = fetchurl {
        name = "Zed-aarch64.dmg";
        url = "${releaseUrl}?asset=zed&arch=aarch64&os=macos&source=nix-config";
        hash = "sha256-ggLH6FxGqOz0cXOLQ9gr0SoSL5zCFIBFVR9y3M/wZtU=";
      };

      nativeBuildInputs = [ _7zz ];
      dontFixup = true;
      dontStrip = true;

      unpackPhase = ''
        runHook preUnpack
        7zz x "$src" -y
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/Applications" "$out/bin"
        cp -R "Zed Nightly.app" "$out/Applications/"
        ln -s "$out/Applications/Zed Nightly.app/Contents/MacOS/cli" "$out/bin/zed"

        runHook postInstall
      '';
    }
  )
else if stdenvNoCC.hostPlatform.isLinux then
  stdenvNoCC.mkDerivation (
    common
    // {
      src = fetchzip {
        name = "zed-linux-x86_64";
        url = "${releaseUrl}?asset=zed&arch=x86_64&os=linux&source=nix-config";
        hash = "sha256-muZQctsqCFvTymkdW9K23dFur6HKzCVYOPyp8RH3e0o=";
        extension = "tar.gz";
        stripRoot = true;
      };

      nativeBuildInputs = [
        autoPatchelfHook
        makeWrapper
      ];
      buildInputs = [
        alsa-lib
        stdenv.cc.cc.lib
      ];
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out"
        cp -R "$src"/. "$out"
        chmod -R u+w "$out"
        ln -s zed "$out/bin/zeditor"

        runHook postInstall
      '';

      postFixup = ''
        wrapProgram "$out/libexec/zed-editor" \
          --suffix PATH : ${lib.makeBinPath [ nodejs_22 ]}
      '';
    }
  )
else
  throw "zed-nightly official binary is unsupported on ${stdenvNoCC.hostPlatform.system}"
