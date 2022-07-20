data:extend { { type = 'item-subgroup', name = 'interface-signals', group = 'signals', order = 'zzzzzz1' } }
data:extend { { type = 'item-subgroup', name = 'interface-signals-settings', group = 'signals', order = 'zzzzzz2' } }

data:extend {
    {
        type = 'virtual-signal',
        name = 'interface-signal-chop-trees',
        icon = '__RoboportInterface__/graphics/icons/signals/chop-trees.png',
        icon_size = 64,
        subgroup = 'interface-signals',
        order = '[interface-signal]-a'
    }, {
        type = 'virtual-signal',
        name = 'interface-signal-item-on-ground',
        icon = '__RoboportInterface__/graphics/icons/signals/item-on-ground.png',
        icon_size = 64,
        subgroup = 'interface-signals',
        order = '[interface-signal]-b'
    },
    {
        type = 'virtual-signal',
        name = 'interface-signal-catch-fish',
        icon = '__RoboportInterface__/graphics/icons/signals/remove-fish.png',
        icon_size = 64,
        subgroup = 'interface-signals',
        order = '[interface-signal]-c'
    },
}

data:extend {
    {
        type = 'virtual-signal',
        name = 'interface-signal-roboport-count',
        icon = '__RoboportInterface__/graphics/icons/signals/roboport-count.png',
        icon_size = 64,
        subgroup = 'interface-signals-settings',
        order = '[interface-signal]-a1'
    },
    {
        type = 'virtual-signal',
        name = 'interface-signal-roboport-channel',
        icon = '__RoboportInterface__/graphics/icons/signals/roboport.png',
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = 'interface-signals-settings',
        order = '[interface-signal]-a2'
    },
    {
        type = 'virtual-signal',
        name = 'interface-signal-bot-utilization',
        icon = '__RoboportInterface__/graphics/icons/signals/construction-robot.png',
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = 'interface-signals-settings',
        order = '[interface-signal]-b'
    },
    {
        type = 'virtual-signal',
        name = 'interface-signal-enemy-range',
        icon = '__RoboportInterface__/graphics/icons/signals/small-biter.png',
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = 'interface-signals-settings',
        order = '[interface-signal]-c'
    },

}
