Cache = Cache or {}
Cache.maxBytes = math.floor(Config.CacheMaxMB * 1024 * 1024)
Cache.bytes = 0
Cache.store = {}
Cache.order = {}
Cache.versions = {}

local function removeFromOrder(key)
    for i, k in ipairs(Cache.order) do
        if k == key then
            table.remove(Cache.order, i)
            return
        end
    end
end

local function drop(key)
    local entry = Cache.store[key]
    if not entry then return end
    Cache.bytes = Cache.bytes - #entry.data
    Cache.store[key] = nil
end

-- bumped on every write so a slow read can detect a newer photo
function Cache.Version(key)
    return Cache.versions[key] or 0
end

function Cache.Get(key)
    local entry = Cache.store[key]
    if not entry then return nil end
    entry.lastAccess = os.time()
    removeFromOrder(key)
    Cache.order[#Cache.order + 1] = key
    return entry
end

function Cache.Set(key, data)
    Cache.versions[key] = Cache.Version(key) + 1

    if Cache.store[key] then
        drop(key)
        removeFromOrder(key)
    end
    if #data > Cache.maxBytes then return end

    while Cache.bytes + #data > Cache.maxBytes and #Cache.order > 0 do
        drop(table.remove(Cache.order, 1))
    end

    Cache.store[key] = { data = data, lastAccess = os.time() }
    Cache.bytes = Cache.bytes + #data
    Cache.order[#Cache.order + 1] = key
end

function Cache.Invalidate(key)
    Cache.versions[key] = Cache.Version(key) + 1
    if not Cache.store[key] then return end
    drop(key)
    removeFromOrder(key)
end
