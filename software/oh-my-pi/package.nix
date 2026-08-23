{
  fetchurl,
  lib,
  makeWrapper,
  stdenvNoCC,
  writeText,
}:

let
  managedConfig = writeText "oh-my-pi-nix-managed.yml" ''
    startup:
      checkUpdate: false
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "oh-my-pi";
  version = "17.2.4";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-darwin-arm64";
    hash = "sha256-850lbGsuzn8uuFwk/Ef/vjmheW6m7qJgWtVk/OQsQI4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/omp"
    install -Dm444 "${managedConfig}" "$out/share/oh-my-pi/nix-managed.yml"
    wrapProgram "$out/bin/omp" \
      --suffix PI_CONFIG_FILES : "$out/share/oh-my-pi/nix-managed.yml"

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal";
    homepage = "https://omp.sh";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
