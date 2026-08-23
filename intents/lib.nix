{
  empty = {
    darwinModules = [ ];
    nixosModules = [ ];
    homeModules = [ ];
  };

  addModules =
    {
      darwinModules ? [ ],
      nixosModules ? [ ],
      homeModules ? [ ],
    }:
    state: {
      darwinModules = state.darwinModules ++ darwinModules;
      nixosModules = state.nixosModules ++ nixosModules;
      homeModules = state.homeModules ++ homeModules;
    };

  realize = state: {
    inherit (state) darwinModules nixosModules homeModules;
  };
}
