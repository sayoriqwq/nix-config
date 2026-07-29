{
  # These Erlang/Elixir defaults preserve an existing macbook experiment.
  # They are not part of the workstation runtime shared with nixbox.
  xdg.configFile."mise/conf.d/20-desktop-runtimes.toml".text = ''
    [tools]
    erlang = "29.0.3"
    elixir = "1.20.2-otp-29"
  '';
}
