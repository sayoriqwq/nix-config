{ lib }:

let
  compose = import ../lib.nix { inherit lib; };
  software = {
    antigravity = import ../../software/antigravity;
    ax = import ../../software/ax;
    claudeCode = import ../../software/claude-code;
    codex = import ../../software/codex;
    git = import ../../software/git;
    herdr = import ../../software/herdr;
    ohMyPi = import ../../software/oh-my-pi;
    python = import ../../software/python;
    rtk = import ../../software/rtk;
    tmux = import ../../software/tmux;
  };
  coreCodingEnvironment = compose [
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
  inherit coreCodingEnvironment;

  multiClientCodingEnvironment = compose [
    coreCodingEnvironment
    software.git.versionControl
    software.claudeCode.codingAgent
    software.antigravity.codingAgent
    software.ohMyPi.codingAgent
  ];
}
