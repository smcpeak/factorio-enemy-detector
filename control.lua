-- EnemyDetector control.lua
-- Code that runs as the game is played.

require "lua_util"         -- remove_element_from_array, compare_numbers


-- --------------------------- Configuration ---------------------------
-- The variable values in this section are overwritten by configuration
-- settings during initialization and after re-reading updated
-- configuration values, but for ease of reference, the values here are
-- the same as the defaults in `settings.lua`.

-- How much to log, from among:
--   0: Nothing.
--   1: Only things that indicate a serious problem.  These suggest a
--      bug in this mod, but are recoverable.
--   2: Relatively infrequent things possibly of interest to the user.
--   3: More verbose user-level events.
--   4: Individual algorithm steps only of interest to a developer.
--   5: Even more algorithm details.
local diagnostic_verbosity = 1;

-- Time between checks for nearby enemies.
local enemy_check_period_ticks = 60;


-- ------------------------------- Data --------------------------------

-- Map from unit ID of each tracked detector to its associated record.
--
-- Each record has:
--
--   detector: The detector entity.
--
--   radar: The associated radar entity, if any.
--
-- This is populated on the first scan once the mod starts running by
-- scanning the entire map.  It is not saved to the Factorio save-game
-- file.
--
local all_detector_records = nil;


-- ----------------------------- Functions -----------------------------
-- Log 'str' if we are at verbosity 'v' or higher.
local function diag(v, str)
  if (v <= diagnostic_verbosity) then
    log(str);
  end;
end;


-- Return the position of `e` as a string.
local function ent_pos_str(e)
  return "(" .. e.position.x .. ", " .. e.position.y .. ")";
end;


-- Return -1/0/+1 depending on the relative positions of `e1` and `e2`.
local function compare_entity_positions(e1, e2)
  -- First, Northernmost (negative Y) comes first.
  local res = compare_numbers(e1.position.y, e2.position.y);
  if (res ~= 0) then
    return res;
  end;

  -- Then, Westernmost (negative X).
  res = compare_numbers(e1.position.x, e2.position.x);
  if (res ~= 0) then
    return res;
  end;

  -- In case different entities somehow have the same position, resolve
  -- ties using the unit numbers.
  return compare_numbers(e1.unit_number, e2.unit_number);
end;


-- Return the radar entity to use for `detector`, or nil if none is
-- suitable.  Ignore `excluded_radar` if it is not nil.
local function find_associated_radar(detector, excluded_radar)
  -- Look for an adjacent radar.
  local p = detector.position;
  local radius = 1;
  local candidates = detector.surface.find_entities_filtered{
    area = {
      { p.x - radius, p.y - radius },
      { p.x + radius, p.y + radius },
    },
    type = "radar",
    force = detector.force,
  };

  -- Remove `excluded_radar` from the candidates.
  remove_element_from_array(candidates, excluded_radar);

  diag(4, "find_associated_radar: For detector " .. detector.unit_number ..
          " at " .. ent_pos_str(detector) ..
          ", found " .. #candidates .. " candidate radars.");

  -- For determinism, choose by comparing positions.
  table.sort(candidates, function (c1, c2)
    return compare_entity_positions(c1, c2) < 0;
  end);
  if (#candidates > 0) then
    local radar = candidates[1];
    diag(4, "Selected radar " .. radar.unit_number ..
            " at " .. ent_pos_str(radar) .. ".");
    return radar;
  else
    return nil;
  end;
end;


-- Add a detector to those we track.
local function add_detector(detector)
  all_detector_records[detector.unit_number] = {
    detector = detector,
    radar = find_associated_radar(detector, nil),
  };
end;


-- Remove the record associated with `detector`.
local function remove_detector(detector)
  all_detector_records[detector.unit_number] = nil;
end;


-- Recompute the radar that is to be associated with `detector`.
local function refresh_associated_radar(detector, excluded_radar)
  record = all_detector_records[detector.unit_number];
  if (record ~= nil) then
    record.radar = find_associated_radar(detector, excluded_radar);

  else
    diag(4, "refresh_associated_radar: no existing record for unit " ..
            detector.unit_number);
    add_detector(detector);

  end;
end;


-- If `radar` is near some detectors, recalculate their associated
-- radars.
local function refresh_nearby_detectors(radar, excluded_radar)
  local p = radar.position;
  local radius = 5;          -- Extra tolerance for large modded radars.
  local nearby_detectors = radar.surface.find_entities_filtered{
    area = {
      { p.x - radius, p.y - radius },
      { p.x + radius, p.y + radius },
    },
    name = "enemy-detector-entity",
    force = radar.force,
  };

  for _, detector in pairs(nearby_detectors) do
    refresh_associated_radar(detector, excluded_radar);
  end;
end;


-- If necessary, initialize the set of detectors.
local function initialize_detectors_if_needed()
  if (all_detector_records == nil) then
    diag(4, "initialize_detectors_if_needed: scanning all surfaces");

    all_detector_records = {};

    for surface_id, surface in pairs(game.surfaces) do
      diag(4, "scanning surface: " .. surface_id);
      local detectors = surface.find_entities_filtered{
        name = "enemy-detector-entity",
      };
      for _, detector in pairs(detectors) do
        diag(4, "detector " .. detector.unit_number ..
                " at " .. ent_pos_str(detector));
        add_detector(detector);
      end;
    end;
  end;
end;


-- Scan for enemies near the detector of `record`.
local function scan_one_detector(record)
  local detector = record.detector;
  diag(4, "processing detector " .. detector.unit_number ..
          " at " .. ent_pos_str(detector));

  -- Get the combinator signal definitions so we can adjust them.
  local control_behavior = detector.get_control_behavior();
  if (not control_behavior.enabled) then
    diag(4, "Combinator is disabled, skipping scan.");
    return;
  end;

  -- We will operate exclusively on the first section of the signal
  -- definitions.
  local logistic_section = control_behavior.get_section(1);
  if (logistic_section == nil) then
    -- The user can delete all sections in the combinator.
    diag(4, "Missing section 1, will skip.");
    return;
  end;

  if (record.radar ~= nil) then
    if (not record.radar.valid) then
      diag(4, "non-nil radar is invalid, checking for another");
      record.radar = find_associated_radar(detector, nil);
    end;
  end;

  if (record.radar == nil) then
    diag(4, "no associated radar");
    return;
  end;

  local radar = record.radar;
  if (radar.status ~= defines.entity_status.working) then
    diag(4, "radar is not working, skipping");
    return;
  end;

  diag(4, "scanning based on radar " .. radar.unit_number ..
          " at " .. ent_pos_str(radar));

  -- Scan radius, in chunks, depending on quality.  For a normal
  -- radar, this is 3.  It means the radar scans the chunk it is in,
  -- plus this many more chunks in each direction (i.e., a 7x7
  -- square for a radius of 3).
  local chunk_radius =
    radar.prototype.get_max_distance_of_nearby_sector_revealed(radar.quality);

  -- Compute the coordinates of the upper-left corner of the center
  -- chunk.
  local ccx = math.floor(radar.position.x / 32) * 32;
  local ccy = math.floor(radar.position.y / 32) * 32;

  -- Scan the same area that the radar (continously) scans.
  local enemies = radar.surface.find_units{
    area = {
      { ccx - 32 * chunk_radius    , ccy - 32 * chunk_radius     },
      { ccx + 32 * (chunk_radius+1), ccy + 32 * (chunk_radius+1) },
    },
    force = radar.force,
    condition = "enemy",
  };
  local num_enemies = #enemies;
  diag(4, "Found " .. num_enemies .. " enemies nearby.");

  -- In order to ensure there are no conflicts, clear all slots
  -- after slot 1.
  for i=2, logistic_section.filters_count do
    logistic_section.clear_slot(i);
  end;

  -- Set signal "E" to output the number of enemies.
  logistic_section.set_slot(1, {
    value = {
      comparator = "=",
      quality = "normal",
      type = "virtual",
      name = "signal-E",
    },
    min = num_enemies,
  });

end;


-- Scan near all detectors.
local function scan_all_detectors()
  diag(4, "scanning at all detectors");

  initialize_detectors_if_needed();

  -- Iterate over the records, scanning from each, and also removing
  -- any that refer to invalid entities.  (The event handlers should
  -- ensure that invalid entities are removed earlier, but this is a
  -- defensive measure, and would handle the case of a mod removing an
  -- entity without notifying event listeners.)
  for unit_number, record in pairs(all_detector_records) do
    if (record.detector.valid) then
      scan_one_detector(record);

    else
      diag(4, "removing invalid entity for unit " .. unit_number);
      all_detector_records[unit_number] = nil;

    end;
  end;
end;


-- ----------------------------- Settings ------------------------------
-- Re-read the configuration settings.
--
-- Below, this is done once on startup, then afterward in response to
-- the on_runtime_mod_setting_changed event.
local function read_configuration_settings()
  -- Note: Because the diagnostic verbosity is changed here, it is
  -- possible to see unpaired "begin" or "end" in the log.
  diag(4, "read_configuration_settings begin");

  -- Clear any existing tick handler.
  script.on_nth_tick(nil);

  diagnostic_verbosity =     settings.global["enemy-detector-diagnostic-verbosity"].value;
  enemy_check_period_ticks = settings.global["enemy-detector-enemy-check-period-ticks"].value;

  -- Re-establish the tick handler with the new period.
  script.on_nth_tick(enemy_check_period_ticks, function(e)
    scan_all_detectors();
  end);

  diag(4, "read_configuration_settings end");
end;


-- -------------------------- Event Handlers ---------------------------
local function handle_entity_created(event)
  local e = event.entity;
  diag(4, "entity " .. e.name .. " created at " .. ent_pos_str(e));
  if (e.name == "enemy-detector-entity") then
    add_detector(e);
  elseif (e.type == "radar") then
    refresh_nearby_detectors(e, nil);
  end;
end;


local function handle_entity_destroyed(event)
  local e = event.entity;
  diag(4, "entity " .. e.name .. " destroyed at " .. ent_pos_str(e));
  if (e.name == "enemy-detector-entity") then
    remove_detector(e);
  elseif (e.type == "radar") then
    refresh_nearby_detectors(e, e);
  end;
end;


local event_filter = {
  {
    filter = "type",
    type = "constant-combinator",
  },
  {
    filter = "type",
    type = "radar",
    mode = "or",
  },
};

script.on_event(
  defines.events.on_built_entity,
  handle_entity_created,
  event_filter);

script.on_event(
  defines.events.on_robot_built_entity,
  handle_entity_created,
  event_filter);

script.on_event(
  defines.events.on_player_mined_entity,
  handle_entity_destroyed,
  event_filter);

script.on_event(
  defines.events.on_robot_mined_entity,
  handle_entity_destroyed,
  event_filter);

script.on_event(
  defines.events.on_entity_died,
  handle_entity_destroyed,
  event_filter);


script.on_event(defines.events.on_runtime_mod_setting_changed,
  read_configuration_settings);


-- -------------------------- Initialization ---------------------------
read_configuration_settings();


-- EOF
