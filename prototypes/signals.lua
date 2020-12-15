local group = {
    type = 'item-subgroup',
    name = 'interface-signals',
    group = 'signals',
    order = 'zzzzzz'
}

local signal1 = {
    type = 'virtual-signal',
    name = 'interface-signal-chop-trees',
    icon = '__RoboportInterface__/graphics/icons/signals/chop-trees.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-a'
}
local signal2 = {
    type = 'virtual-signal',
    name = 'interface-signal-item-on-ground',
    icon = '__RoboportInterface__/graphics/icons/signals/item-on-ground.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-b'
}
--luacheck: ignore signal3
local signal3 = {
    type = 'virtual-signal',
    name = 'interface-signal-remove-tiles',
    icon = '__RoboportInterface__/graphics/icons/signals/remove-tiles.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-c'
}
--luacheck: ignore signal4
local signal4 = {
    type = 'virtual-signal',
    name = 'interface-signal-landfill-the-world',
    icon = '__RoboportInterface__/graphics/icons/signals/item-on-ground.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-d'
}
local signal5 = {
    type = 'virtual-signal',
    name = 'interface-signal-deconstruct-finished-miners',
    icon = '__RoboportInterface__/graphics/icons/signals/deconstruct-miners.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-e'
}
local signal6 = {
    type = 'virtual-signal',
    name = 'interface-signal-catch-fish',
    icon = '__RoboportInterface__/graphics/icons/signals/remove-fish.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-f'
}
local signal99 = {
    type = 'virtual-signal',
    name = 'interface-signal-closest-roboport',
    icon = '__RoboportInterface__/graphics/icons/signals/closest-roboport.png',
    icon_size = 32,
    subgroup = 'interface-signals',
    order = '[interface-signal]-z'
}

data:extend {group, signal1, signal2, signal5, signal6, signal99}
