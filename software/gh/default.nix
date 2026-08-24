{ intentLib }:

{
  githubCli = intentLib.addModules {
    homeModules = [ ./capabilities/github-cli/home.nix ];
  };

  gitCredentialHelper = intentLib.addModules {
    homeModules = [ ./capabilities/github-cli/git-credential-helper.nix ];
  };
}
