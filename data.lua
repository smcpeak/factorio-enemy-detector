-- EnemyDetector data.lua
-- Define new entities, etc.


-- Recipe to create a detector.
local detector_recipe = {
  type = "recipe",
  name = "enemy-detector-recipe",
  enabled = true,       -- TODO: Hide this behind research.

  -- For now, same ingredients as a constant combinator.
  ingredients = {
    {
      amount = 5,
      name = "copper-cable",
      type = "item",
    },
    {
      amount = 2,
      name = "electronic-circuit",
      type = "item",
    },
  },

  results = {
    {
      amount = 1,
      name = "enemy-detector-item",
      type = "item",
    },
  },
};


-- Inventory item corresponding to the detector.
local detector_item = table.deepcopy(data.raw.item["constant-combinator"]);
detector_item.name         = "enemy-detector-item";
detector_item.place_result = "enemy-detector-entity";
detector_item.order        = "c[combinators]-d[enemy-detector]";
detector_item.icon         = "__EnemyDetector__/graphics/icons/enemy-detector.png";


-- World entity for the detector.
local detector_entity = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"]);
detector_entity.name           = "enemy-detector-entity";
detector_entity.minable.result = "enemy-detector-item";
detector_entity.icon           = detector_item.icon;

for direction_name, direction in pairs(detector_entity.sprites) do
  -- The first layer is the main image.  The four directions all have
  -- different (x,y) offsets, but share the same image.  The offsets are
  -- the same as in the original.
  direction.layers[1].filename = "__EnemyDetector__/graphics/entity/combinator/enemy-detector.png";

  -- The second layer is the shadow, which I retain as the one from the
  -- base constant-combinator.
end;


-- Update Factorio data.
data:extend{
  detector_recipe,
  detector_item,
  detector_entity,
};


-- EOF
