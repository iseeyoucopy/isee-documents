fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

lua54 'yes'
author '@iseeyoucopy'

shared_scripts {
    'config.lua',
	'shared/locale.lua',
	'languages/*.lua',
}

client_scripts {
	'/client/main.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/versioncheck.lua',
	'server/main.lua',
}

dependency {
	'vorp_core',
	'bcc-utils',
	'feather-menu',
}

version '0.0.1'
