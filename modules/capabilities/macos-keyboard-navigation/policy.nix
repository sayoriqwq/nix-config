let
  raycastHyperWithoutShift = {
    enabled = true;
    includeShiftKey = false;
    keyCode = 57;
  };

  symbolicHotkey27 = {
    enabled = true;
    value = {
      type = "standard";
      parameters = [
        32
        49
        1835008
      ];
    };
  };

  symbolicHotkey27Legacy = {
    enabled = true;
    value = {
      type = "standard";
      parameters = [
        32
        49
        1966080
      ];
    };
  };
in
{
  version = 1;

  raycast = {
    ownership = "ui-owned-human-gate";
    raycastGlobalHotkey = "Command-49";
    raycast_hyperKey_state = raycastHyperWithoutShift;
  };

  symbolicHotkeys = {
    ownership = "managed-leaves";
    domain = "com.apple.symbolichotkeys";

    hotkey27 = {
      desired = symbolicHotkey27;
      acceptedBaselines = [
        symbolicHotkey27
        symbolicHotkey27Legacy
      ];
    };

    requiredDisable = [
      32
      33
      64
      65
      79
      81
      118
      119
    ];

    disableIfPresent = [
      120
      121
      122
      123
      124
      125
      126
      127
    ];
  };
}
