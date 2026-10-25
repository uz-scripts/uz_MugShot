NUI = NUI or {}
NUI.visible = false

-- NUI curtain, not DoScreenFadeOut: the engine fade would make the screenshot black.
-- opts.spinner = true for debugging.
function NUI.ShowCurtain(opts)
    if NUI.visible then return end
    NUI.visible = true
    local spinner = opts and opts.spinner == true
    SendNUIMessage({ action = 'show', spinner = spinner })
end

function NUI.HideCurtain()
    if not NUI.visible then return end
    NUI.visible = false
    SendNUIMessage({ action = 'hide' })
end

local converts, nextConvert = {}, 0

RegisterNUICallback('converted', function(data, cb)
    local p = converts[data.id]
    if p then
        converts[data.id] = nil
        p:resolve(data.uri or '')
    end
    cb('ok')
end)

-- Draws src (data URI or nui-img URL) on a canvas, scaled to size x size if
-- given, and returns a PNG data URI. '' on failure or timeout.
function NUI.ToDataUri(src, size)
    nextConvert = nextConvert + 1
    local id = nextConvert
    local p = promise.new()
    converts[id] = p
    SendNUIMessage({ action = 'convert', id = id, src = src, size = size })
    SetTimeout(5000, function()
        if converts[id] then
            converts[id] = nil
            p:resolve('')
        end
    end)
    return Citizen.Await(p)
end
