data:extend{
    {
        type = 'int-setting',
        name = 'interface-queue-rate',
        setting_type = 'runtime-global',
        default_value = 5,
        maximum_value = 60 * 60,
        minimum_value = 1,
        order = 'interface-fa[queue-rate]'
    }, {
        type = 'int-setting',
        name = 'interface-free-bots-per',
        setting_type = 'runtime-global',
        default_value = 50,
        maximum_value = 100,
        minimum_value = 1,
        order = 'interface-fb[free-bots-per]'
    }
}
