{
  pkgs,
  zshrc,
}:

pkgs.runCommand "macbook-zsh-zoxide-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    initPattern='zoxide init zsh --cmd cd'
    wrapperPattern='function __sayori_cd()'

    if ! grep -Fq "$initPattern" ${zshrc}; then
      echo "missing zoxide Zsh initialization" >&2
      exit 1
    fi

    if ! grep -Fq "$wrapperPattern" ${zshrc}; then
      echo "missing Sayori Zsh cd wrapper" >&2
      exit 1
    fi

    if ! grep -Fq '__zoxide_z' ${zshrc}; then
      echo "missing zoxide-backed cd dependency" >&2
      exit 1
    fi

    initCount="$(grep -Fc "$initPattern" ${zshrc})"
    if [ "$initCount" -ne 1 ]; then
      echo "expected exactly one zoxide Zsh initialization, found $initCount" >&2
      exit 1
    fi

    initLine="$(grep -Fnm1 "$initPattern" ${zshrc} | cut -d: -f1)"
    wrapperLine="$(grep -Fnm1 "$wrapperPattern" ${zshrc} | cut -d: -f1)"
    if [ "$initLine" -ge "$wrapperLine" ]; then
      echo "zoxide must initialize before the Sayori cd wrapper" >&2
      exit 1
    fi

    touch "$out"
  ''
