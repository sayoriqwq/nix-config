{ intentLib }:

{
  contentViewer = intentLib.addModules {
    homeModules = [ ./capabilities/content-viewer/home.nix ];
  };
}
