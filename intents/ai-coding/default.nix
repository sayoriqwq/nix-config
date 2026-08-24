{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    antigravity = import ../../software/antigravity { inherit intentLib; };
    ax = import ../../software/ax { inherit intentLib; };
    claudeCode = import ../../software/claude-code { inherit intentLib; };
    codex = import ../../software/codex { inherit intentLib; };
    git = import ../../software/git { inherit intentLib; };
    herdr = import ../../software/herdr { inherit intentLib; };
    ohMyPi = import ../../software/oh-my-pi { inherit intentLib; };
    python = import ../../software/python { inherit intentLib; };
    rtk = import ../../software/rtk { inherit intentLib; };
    tmux = import ../../software/tmux { inherit intentLib; };
  };
  coreCodingEnvironment = lib.pipe intentLib.empty [
    software.herdr.codingSession
    # Herdr is the preferred session path; tmux remains only as the existing
    # compatibility dependency for tools that still require a multiplexer.
    software.tmux.terminalMultiplexer
    software.codex.codingAgent
    software.ax.webInspection
    software.rtk.outputCompression
    software.python.agentInterpreter
  ];
in
{
  coreCodingEnvironment = intentLib.realize coreCodingEnvironment;

  multiClientCodingEnvironment = intentLib.realize (
    lib.pipe coreCodingEnvironment [
      software.git.versionControl
      software.claudeCode.codingAgent
      software.antigravity.codingAgent
      software.ohMyPi.codingAgent
    ]
  );
}
