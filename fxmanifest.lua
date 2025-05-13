fx_version 'cerulean'
game 'gta5'

author 'DaemonAlex'
description 'Ocean Delivery - Boat Cargo Delivery Job'
version '1.1.0'

shared_scripts {
    'config.lua',
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql'
}

optional_dependencies {
    'ox_target',  -- Enhanced interaction
    'qs-banking', -- Banking option 1
    'renewed-banking' -- Banking option 2
}

lua54 'yes' -- Enable Lua 5.4 features
