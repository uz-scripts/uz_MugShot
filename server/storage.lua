Storage = Storage or {}

local MAX_CID_LENGTH = 64

local function safeSegment(s)
    return (s:gsub('[^%w_%-]', ''))
end

-- Canonical cid for paths and cache keys ("ABC1" and "ABC1!" map to one file).
function Storage.NormalizeCid(citizenid)
    if type(citizenid) ~= 'string' or #citizenid > MAX_CID_LENGTH then return nil end
    local cid = safeSegment(citizenid)
    if cid == '' then return nil end
    return cid
end

function Storage.PathFor(citizenid, variant)
    return ('shots/%s/%s.png'):format(safeSegment(citizenid), safeSegment(variant))
end

function Storage.FingerprintPathFor(citizenid, variant)
    return ('shots/%s/%s.fp'):format(safeSegment(citizenid), safeSegment(variant))
end
