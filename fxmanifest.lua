fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Cargo Delivery Job'
version '1.0.0'

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
    'ox_target',
    'oxmysql'
}
