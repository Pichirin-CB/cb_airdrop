fx_version 'cerulean'
game 'gta5'

name 'cb_airdrop'
author 'Pichirin_CB'
description 'Apocalyptic airdrop system with direct physical crate ox_target interaction.'
version '3.0.0'
license ''
documentation 'https://docs.pichirincb.com/#/'
discord 'https://discord.gg/hsx6AvBg5s'

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'es_extended'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'
