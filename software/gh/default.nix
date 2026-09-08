{
  githubCli.homeModules = [ ./capabilities/github-cli/home.nix ];

  gitCredentialHelper.homeModules = [ ./capabilities/github-cli/git-credential-helper.nix ];
}
