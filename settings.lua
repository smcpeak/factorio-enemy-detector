-- EnemyDetector settings.lua
-- Configuration settings.


data:extend({
  -- Time between checks for nearby enemies.
  {
    type = "int-setting",
    name = "enemy-detector-enemy-check-period-ticks",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 1,
    maximum_value = 3600,
  },

  -- Diagnostic log verbosity level.  See 'diagnostic_verbosity' in
  -- control.lua.
  {
    type = "int-setting",
    name = "enemy-detector-diagnostic-verbosity",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 0,
    maximum_value = 5,
  },
});


-- EOF
