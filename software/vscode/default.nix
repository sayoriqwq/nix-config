{ intentLib }:

{
  editorCompatibility = intentLib.addModules {
    homeModules = [ ./capabilities/editor-compatibility/home.nix ];
  };

  shellQuickCommand = intentLib.addModules {
    homeModules = [ ./capabilities/editor-compatibility/shell.nix ];
  };
}
