fx_version 'cerulean'
game 'gta5'

author 'DaemonAlex'
description 'Ocean Delivery - Advanced Boat Cargo Delivery Job with Fleet Ownership, Encounters & Phone Integration'
version '3.0.0'

shared_scripts {
    'config.lua',
    '@ox_lib/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua',
    'phone.lua'
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql'
}

optional_dependencies {
    'ox_target',        -- Enhanced interaction
    'qs-banking',       -- Banking option 1
    'renewed-banking',  -- Banking option 2
    'lb-phone',         -- Phone integration
    'qs-smartphone',    -- Phone integration
    'npwd'              -- Phone integration
}

lua54 'yes'
