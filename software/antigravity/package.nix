{
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "antigravity-cli";
  version = "1.1.27";

  src = fetchurl {
    url = "https://github.com/google-antigravity/antigravity-cli/releases/download/${finalAttrs.version}/agy_cli_mac_arm64.tar.gz";
    hash = "sha256-6QHlyP0gq0whwB3zBgMAeShtCObTcs21NdXMx6P1ZfQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    tar -xzf "$src"
    install -Dm755 antigravity "$out/bin/agy"
    wrapProgram "$out/bin/agy" \
      --set AGY_CLI_DISABLE_AUTO_UPDATE true

    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity CLI";
    homepage = "https://github.com/google-antigravity/antigravity-cli";
    license = lib.licenses.unfree;
    mainProgram = "agy";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
