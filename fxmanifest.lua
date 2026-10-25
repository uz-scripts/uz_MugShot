fx_version 'cerulean'
game 'gta5'

name 'uz_MugShot'
author 'UZ'
description 'Automatic transparent player mugshots for FiveM'
version '1.0.1'
repository 'https://github.com/uz-scripts/uz_MugShot'

-- Drop-in replacement: exports['MugShotBase64']:GetMugShotBase64(...) keeps working
provide 'MugShotBase64'

lua54 'yes'

dependencies {
    'screenshot-basic',
    'yarn',
}

shared_scripts {
    'config.lua',
    'bridge/init.lua',
    'bridge/api.lua',
    'bridge/qbox.lua',
    'bridge/qbcore.lua',
    'bridge/esx.lua',
}

client_scripts {
    'client/studio.lua',
    'client/nui.lua',
    'client/capture.lua',
    'client/main.lua',
    'client/api.lua',
    'client/compat.lua',
}

server_scripts {
    'server/version.lua',
    'server/processor.js',
    'server/cache.lua',
    'server/storage.lua',
    'server/limits.lua',
    'server/api.lua',
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
}

server_exports {
    'GetPhotoDataURI',
    'ForceRecapture',
    'HasPhoto',
    'CaptureAndReturn',
    'TriggerInitialCapture',
}

client_exports {
    'GetPhotoDataURI',
    'GetPhotoByCitizenId',
    'GetMugShotBase64',
}
