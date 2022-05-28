data:extend{
    {
        type = 'int-setting',
        name = 'interface-queue-rate',
        setting_type = 'runtime-global',
        default_value = 5,
        maximum_value = 60 * 60,
        minimum_value = 1,
        order = 'interface-fa[queue-rate]'
    }
}
