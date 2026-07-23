{
  # The running Homebrew PostgreSQL 16 service and its data are intentionally
  # unchanged. Its future stateful migration has a separate backup gate.
  home.sessionPath = [ "/opt/homebrew/opt/postgresql@16/bin" ];
}
