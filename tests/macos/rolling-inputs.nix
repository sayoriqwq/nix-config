{
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
}:

let
  inherit (pkgs) lib;
  packageName = package: package.pname or (lib.getName package);
  macbookHome = macbookConfiguration.config.home-manager.users.sayori;
  nixboxHome = nixboxConfiguration.config.home-manager.users.sayori;
  serverHome = serverConfiguration.config.home-manager.users.sayori;
  macbookObsidian = lib.findFirst (
    package: packageName package == "obsidian"
  ) null macbookHome.home.packages;
in
assert lib.assertMsg (macbookHome.programs.fish.generateCompletions)
  "Home Manager master must generate Fish completions on macbook without the retired 26.05 workaround";
assert lib.assertMsg nixboxHome.programs.fish.generateCompletions
  "nixbox must retain the default Home Manager completion generation behavior";
assert lib.assertMsg (
  macbookHome.programs.fzf.historyWidget.command == ""
) "Home Manager master must explicitly leave Ctrl-R to Atuin on macbook";
assert lib.assertMsg (
  nixboxHome.home.sessionVariables.FZF_CTRL_R_COMMAND == ""
) "Home Manager 26.05 must retain the legacy FZF Ctrl-R override on nixbox";
assert lib.assertMsg (
  macbookHome.home.stateVersion == "26.05"
) "Darwin rolling inputs must not change the established Home Manager stateVersion";
assert lib.assertMsg macbookHome.home.enableNixpkgsReleaseCheck
  "macbook must retain Home Manager's Nixpkgs release compatibility check";
assert lib.assertMsg nixboxHome.home.enableNixpkgsReleaseCheck
  "nixbox must retain Home Manager's Nixpkgs release compatibility check";
assert lib.assertMsg serverHome.home.enableNixpkgsReleaseCheck
  "server must retain Home Manager's Nixpkgs release compatibility check";
assert lib.assertMsg (
  macbookHome.home.version.release == macbookConfiguration.config.system.nixpkgsRelease
) "macbook Home Manager and Darwin Nixpkgs must remain on the same release line";
assert lib.assertMsg (
  nixboxHome.home.version.release == "26.05" && serverHome.home.version.release == "26.05"
) "nixbox and server must retain the Home Manager 26.05 release baseline";
assert lib.assertMsg (
  macbookConfiguration.config.system.stateVersion == 7
) "Darwin rolling inputs must not change the established nix-darwin stateVersion";
assert lib.assertMsg (
  !macbookConfiguration.config.nix.channel.enable
) "Flake-only Darwin configuration must not expose mutable Nix channels";
assert lib.assertMsg (
  macbookConfiguration.config.nix.nixPath == [ "nixpkgs=flake:nixpkgs" ]
) "Darwin NIX_PATH must retain only the pinned Flake registry mapping";
assert lib.assertMsg (macbookObsidian != null) "macbook must continue to provide Obsidian";
assert lib.assertMsg (
  (macbookObsidian.sourceRoot or null) == null
) "Darwin Obsidian must discover its nested app instead of assuming a source root";
assert lib.assertMsg (
  macbookObsidian ? setSourceRoot && lib.hasInfix "Obsidian.app" macbookObsidian.setSourceRoot
) "Darwin Obsidian must fail clearly unless it discovers Obsidian.app";
pkgs.runCommand "macos-rolling-inputs-policy"
  {
    nativeBuildInputs = [ pkgs.jq ];
  }
  ''
    set -euo pipefail

    lock_file=${source}/flake.lock

    input_ref() {
      node="$(jq -r --arg input "$1" '.nodes.root.inputs[$input]' "$lock_file")"
      jq -r --arg node "$node" '.nodes[$node].original.ref // ""' "$lock_file"
    }

    test "$(input_ref nixpkgs-darwin)" = nixpkgs-unstable
    test "$(input_ref nix-darwin)" = master
    test "$(input_ref nixpkgs)" = nixos-26.05
    test "$(input_ref home-manager)" = release-26.05
    test "$(input_ref home-manager-darwin)" = master

    jq -e '
      .nodes.root.inputs["nix-darwin"] as $node
      | .nodes[$node].inputs.nixpkgs == ["nixpkgs-darwin"]
    ' "$lock_file" >/dev/null

    jq -e '
      .nodes.root.inputs["home-manager-darwin"] as $node
      | .nodes[$node].inputs.nixpkgs == ["nixpkgs-darwin"]
    ' "$lock_file" >/dev/null

    touch "$out"
  ''
