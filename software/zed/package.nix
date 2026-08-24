{
  _7zz,
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  release = "1.17.0";
  releaseUrl = "https://cloud.zed.dev/releases/preview/${release}/download";
in
assert lib.assertMsg stdenvNoCC.hostPlatform.isDarwin
  "zed-preview official binary is only supported on Darwin";
stdenvNoCC.mkDerivation {
  pname = "zed-preview";
  version = release;

  src = fetchurl {
    name = "Zed-Preview-aarch64.dmg";
    url = "${releaseUrl}?asset=zed&arch=aarch64&os=macos&source=nix-config";
    hash = "sha256-xspK5Lq4yeAl10RL13j8QC91flA18oKaCmHtvcvImlg=";
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
    cp -R "Zed Preview.app" "$out/Applications/"
    ln -s "$out/Applications/Zed Preview.app/Contents/MacOS/cli" "$out/bin/zed"

    runHook postInstall
  '';

  passthru = {
    zedDistribution = "official-preview-binary";
    zedRelease = release;
  };

  meta = {
    description = "Official prebuilt Zed Preview editor";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    mainProgram = "zed";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
