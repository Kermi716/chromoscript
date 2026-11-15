script_name('Chromo')

local sampev = require 'lib.samp.events'
local imgui = require 'mimgui'
local encoding = require 'encoding'
local json = require 'cjson.safe'
local ffi = require 'ffi'
local bit = require 'bit'
local vkeys = require 'vkeys'
local faicons = require 'fAwesome6'

ffi.cdef[[
    long URLDownloadToFileA(void* caller, const char* url, const char* file, unsigned long reserved, void* callback);
    void* ShellExecuteA(void* hwnd, const char* op, const char* file, const char* params, const char* dir, int show_cmd);
]]
local urlmon = ffi.load('urlmon')
local shell32 = ffi.load('shell32')

encoding.default = 'UTF-8'
local u8 = encoding.UTF8
local path = getWorkingDirectory() .. '\\config\\chromo.json'
local namesTempFile = getWorkingDirectory() .. '\\config\\chromo_items.tmp'
local namesReadyToParse = false
local window = imgui.new.bool(false)
local stealerWin = imgui.new.bool(false)
local calcWin = imgui.new.bool(false)
local checkState = imgui.new.bool(false)
local inventory = {[1] = {}, [13] = {}, [28] = {}}
local names = {}
local namesUpdating = false
local missingNames = {}
local browser = 0
local playerMoney = 0
local dialog = nil
local mainDialog = nil
local serverDialogOpen = false
local shopId = nil
local forceAltUntil = 0
local closeCefAt = nil
local resumeSale = false
local queue = nil
local tab = 1
local logTab = 1
local selectedPreset = 1
local scan = nil
local processQueue
local statusDone = 0
local statusFailed = false
local dirty = false
local nextSell
local nextClearSell
local nextClearBuy
local buyCatalog = {}
local buyNames = {}
local editor = {
    active = false,
    kind = 'sell',
    index = nil,
    name = '',
    page = nil,
    row = nil,
    id = imgui.new.int(0),
    amount = imgui.new.int(1),
    price = imgui.new.int(0)
}
local newPreset = imgui.new.char[64]('')
local pickerSearch = imgui.new.char[128]('')
local listSearch = imgui.new.char[128]('')
local stealerSearch = imgui.new.char[128]('')
local calcInput = imgui.new.char[256]('')
local calcHistory = {}
local calcFocusInput = false
local bindingKey = false
local shopName = imgui.new.char[64]('')
local commission = imgui.new.float(0)
local markup = imgui.new.float(20)
local autoName = imgui.new.bool(false)
local autoColor = imgui.new.bool(false)
local autoRent = imgui.new.bool(false)
local shopColorIdx = imgui.new.int(0)
local calcEnabled = imgui.new.bool(false)
local optimizer = imgui.new.bool(false)
local optimizerMode = imgui.new.int(0)
local optimizerModes = {
    'Всё сразу',
    'Только удалять все объекты',
    'Только заменять кастомные скины'
}
local showZones = imgui.new.bool(false)
local extended = imgui.new.bool(false)
local vcCourse = imgui.new.bool(false)
local vcRate = imgui.new.int(100)
local itemStealer = imgui.new.bool(true)
local lavkaOpen = false
local isMyLavka = false
local lavkaCategory = 13
local lastLavkaPacket = {[13] = 0, [28] = 0}

local shopColors = {
    {name = 'Случайный цвет', col = imgui.ImVec4(0.91, 0.93, 0.96, 1)},
    {name = '1. Кораллово-красный', col = imgui.ImVec4(0.84, 0.25, 0.25, 1)},
    {name = '2. Розовый', col = imgui.ImVec4(0.85, 0.26, 0.62, 1)},
    {name = '3. Фиолетовый', col = imgui.ImVec4(0.67, 0.26, 0.85, 1)},
    {name = '4. Индиго', col = imgui.ImVec4(0.39, 0.34, 0.84, 1)},
    {name = '5. Голубой', col = imgui.ImVec4(0.27, 0.56, 0.85, 1)},
    {name = '6. Бирюзовый', col = imgui.ImVec4(0.27, 0.78, 0.84, 1)},
    {name = '7. Мятный', col = imgui.ImVec4(0.27, 0.84, 0.58, 1)},
    {name = '8. Зеленый', col = imgui.ImVec4(0.28, 0.84, 0.31, 1)},
    {name = '9. Салатовый', col = imgui.ImVec4(0.56, 0.84, 0.27, 1)},
    {name = '10. Лаймовый', col = imgui.ImVec4(0.78, 0.84, 0.27, 1)},
    {name = '11. Желто-золотой', col = imgui.ImVec4(0.84, 0.68, 0.27, 1)},
    {name = '12. Оранжевый', col = imgui.ImVec4(0.84, 0.45, 0.27, 1)},
    {name = '13. Темно-красный', col = imgui.ImVec4(0.65, 0.16, 0.18, 1)},
    {name = '14. Темно-синий', col = imgui.ImVec4(0.18, 0.25, 0.65, 1)},
    {name = '15. Темно-зеленый', col = imgui.ImVec4(0.18, 0.60, 0.22, 1)},
    {name = '16. Белый', col = imgui.ImVec4(0.92, 0.92, 0.92, 1)}
}

local config = {
    presets = {{name = 'Основной', sell = {}, buy = {}}},
    buyCatalog = {},
    itemNames = {},
    sellable = {},
    inventory = {},
    logs = {sell = {}, buy = {}},
    shopName = '',
    commission = 0,
    markup = 20,
    autoName = false,
    autoColor = false,
    autoRent = false,
    shopColorIdx = 0,
    calcEnabled = false,
    calcHotkey = {ctrl = true, shift = false, alt = false, key = vkeys.VK_Z},
    showZones = false,
    extended = false,
    vcCourse = false,
    vcRate = 100,
    itemStealer = true,
    stealerX = nil,
    stealerY = nil,
    buyProgress = nil,
    optimizer = false,
    optimizerMode = 0,
    sellProgress = nil
}

local function iconButton(name, id, size)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.36, 0.78, 0.80, 1))
    local clicked = imgui.Button(faicons(name) .. id, size)
    imgui.PopStyleColor()
    return clicked
end

local function actionButton(icon, label, id, size, disabled, color, iconColor)
    local w = size and size.x > 0 and size.x or (label ~= '' and (imgui.CalcTextSize(label).x + 28) or 28)
    local h = size and size.y > 0 and size.y or 25
    local btnSize = imgui.ImVec2(w, h)
    local pos = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton(id, btnSize) and not disabled
    local draw = imgui.GetWindowDrawList()
    local background = color or 0xFF33291F
    if disabled then
        background = 0xFF252525
    elseif not color then
        if imgui.IsItemActive() then background = 0xFF87703D end
        if imgui.IsItemHovered() then background = 0xFF57572E end
    end
    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + btnSize.x, pos.y + btnSize.y), background, 2)
    local glyph = faicons(icon)
    local glyphSize = imgui.CalcTextSize(glyph)
    local labelSize = imgui.CalcTextSize(label)
    local gap = label ~= '' and 5 or 0
    local totalWidth = glyphSize.x + gap + labelSize.x
    local x = pos.x + (btnSize.x - totalWidth) / 2
    local y = pos.y + (btnSize.y - glyphSize.y) / 2
    draw:AddText(imgui.ImVec2(x, y), disabled and 0xFF777777 or iconColor or 0xFFCCC25C, glyph)
    draw:AddText(imgui.ImVec2(x + glyphSize.x + gap, pos.y + (btnSize.y - labelSize.y) / 2), disabled and 0xFF888888 or 0xFFF5F3E8, label)
    return clicked
end

local function actionWidth(icon, label)
    return label ~= '' and (imgui.CalcTextSize(label).x + 28) or 28
end

local function centerRow(width)
    local available = imgui.GetContentRegionAvail().x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max(0, (available - width) / 2))
end

local function cp(text)
    return u8:decode(text, 'CP1251')
end

local function utf(text)
    return u8(text or '', 'CP1251')
end

local function notify(text)
    sampAddChatMessage('{9db7d6}[Chromo] {ffffff}' .. cp(text), -1)
end

local function cleanName(name)
    return (name or ''):gsub('{%x%x%x%x%x%x}', ''):gsub('{...}', ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local russianCase = {А = 'а', Б = 'б', В = 'в', Г = 'г', Д = 'д', Е = 'е', Ё = 'е', Ж = 'ж', З = 'з', И = 'и', Й = 'й', К = 'к', Л = 'л', М = 'м', Н = 'н', О = 'о', П = 'п', Р = 'р', С = 'с', Т = 'т', У = 'у', Ф = 'ф', Х = 'х', Ц = 'ц', Ч = 'ч', Ш = 'ш', Щ = 'щ', Ъ = 'ъ', Ы = 'ы', Ь = 'ь', Э = 'э', Ю = 'ю', Я = 'я'}

local function searchText(text)
    text = cleanName(text):gsub('[\208-\209][\128-\191]', function(char)
        return russianCase[char] or char
    end)
    return text:lower():gsub('ё', 'е'):gsub('^%s+', ''):gsub('%s+$', '')
end

local function hotkeyToString(hk)
    if type(hk) ~= 'table' or not hk.key then return 'Не задано' end
    local parts = {}
    if hk.ctrl then parts[#parts + 1] = 'CTRL' end
    if hk.shift then parts[#parts + 1] = 'SHIFT' end
    if hk.alt then parts[#parts + 1] = 'ALT' end
    local kname = vkeys.id_to_name(hk.key) or ('KEY_' .. tostring(hk.key))
    parts[#parts + 1] = kname:upper()
    return table.concat(parts, ' + ')
end

local function evalCalcExpression(expr)
    if not expr then return nil end
    local s = expr:gsub('%s+', ''):gsub(',', '.')
    s = s:gsub('(%d+%.?%d*)[кkКK][кkКK][кkКK]', '(%1*1000000000)')
    s = s:gsub('(%d+%.?%d*)[кkКK][кkКK]', '(%1*1000000)')
    s = s:gsub('(%d+%.?%d*)[мmМM]', '(%1*1000000)')
    s = s:gsub('(%d+%.?%d*)[кkКK]', '(%1*1000)')
    s = s:gsub('(%d+%.?%d*)%%', '(%1*0.01)')
    if s == '' or s:find('[^%d%.%+%-%*/%(%)%^]') then return nil end
    local fn = load('return ' .. s)
    if not fn then return nil end
    setfenv(fn, {})
    local ok, res = pcall(fn)
    if ok and type(res) == 'number' and res == res and res ~= math.huge and res ~= -math.huge then
        return res
    end
    return nil
end

local function formatCalcNumber(num)
    if not num then return '0' end
    local rounded = math.floor(num * 100 + 0.5) / 100
    local intPart = math.modf(rounded)
    local fracPart = math.abs(rounded - intPart)
    local sign = rounded < 0 and '-' or ''
    local s = tostring(math.abs(intPart)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')
    if fracPart > 0.001 then
        local f = string.format('%.2f', fracPart):sub(3):gsub('0+$', '')
        if f ~= '' then s = s .. '.' .. f end
    end
    return sign .. s
end

local function myNickname()
    local ok, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok then
        return sampGetPlayerNickname(id) or ''
    end
    return ''
end

local function checkOwnerByTitle(titleText)
    local myNick = myNickname()
    if myNick == '' or not titleText or titleText == '' then return false end
    return titleText:lower():find(myNick:lower(), 1, true) ~= nil
end

local function preset()
    if not config.presets[selectedPreset] then selectedPreset = 1 end
    return config.presets[selectedPreset]
end

local function sameItem(a, b, kind)
    if kind == 'sell' then
        if tonumber(a.id) and tonumber(b.id) and tonumber(a.id) > 0 and tonumber(b.id) > 0 then
            return tonumber(a.id) == tonumber(b.id)
        end
        local na = a.name or (tonumber(a.id) and names[tonumber(a.id)])
        local nb = b.name or (tonumber(b.id) and names[tonumber(b.id)])
        return na and nb and searchText(na) == searchText(nb) or false
    end
    return a.name == b.name
end

local function groupIdenticalItems(list, kind)
    local i = 1
    while i <= #list do
        local base = list[i]
        local insertPos = i + 1
        local j = insertPos
        while j <= #list do
            if sameItem(base, list[j], kind) then
                if j ~= insertPos then
                    local moved = table.remove(list, j)
                    table.insert(list, insertPos, moved)
                end
                insertPos = insertPos + 1
            end
            j = j + 1
        end
        i = insertPos
    end
end

local function insertGrouped(list, newItem, kind)
    local lastMatch = nil
    for i, other in ipairs(list) do
        if sameItem(newItem, other, kind) then
            lastMatch = i
        end
    end
    if lastMatch then
        table.insert(list, lastMatch + 1, newItem)
    else
        table.insert(list, newItem)
    end
    groupIdenticalItems(list, kind)
end

local sortAscending = {sell = true, buy = true}

local function sortPresetList(list, kind, asc)
    table.sort(list, function(a, b)
        local pa = tonumber(a.price) or 0
        local pb = tonumber(b.price) or 0
        if pa ~= pb then
            if asc then return pa < pb else return pa > pb end
        end
        local na = kind == 'sell' and tostring(a.id or a.name or '') or tostring(a.name or '')
        local nb = kind == 'sell' and tostring(b.id or b.name or '') or tostring(b.name or '')
        return na < nb
    end)
    groupIdenticalItems(list, kind)
end

local function flushSave()
    dirty = false
    local cached = {}
    for _, kind in ipairs({1, 13, 28}) do
        cached[tostring(kind)] = {}
        for slot, item in pairs(inventory[kind]) do
            if tonumber(item.item) and item.item > 0 then
                cached[tostring(kind)][tostring(slot)] = {
                    slot = item.slot,
                    item = item.item,
                    amount = item.amount,
                    text = item.text,
                    available = item.available
                }
            end
        end
    end
    config.inventory = cached
    local ok, encoded = pcall(json.encode, config)
    if not ok or not encoded then return end
    local file = io.open(path, 'w')
    if file then
        file:write(encoded)
        file:close()
    end
end

local function save()
    dirty = true
end

local function parseItemsDatabaseTable(decoded)
    if type(decoded) ~= 'table' then return 0 end
    local list = type(decoded.data) == 'table' and decoded.data or (type(decoded.items) == 'table' and decoded.items or decoded)
    local added = 0
    for k, v in pairs(list) do
        local id, name
        if type(v) == 'table' then
            id = tonumber(v.id or v.item_id or k)
            name = cleanName(v.item_name or v.name or v.title)
        elseif type(v) == 'string' then
            id = tonumber(k)
            name = cleanName(v)
        end
        if id and name and name ~= '' and not name:upper():find('DELETED', 1, true) then
            names[id] = name
            config.itemNames[tostring(id)] = name
            added = added + 1
        end
    end
    return added
end

local function loadLocalItemsDb()
    local dbPaths = {
        getWorkingDirectory() .. '\\resource\\items_db.json',
        getWorkingDirectory() .. '\\config\\items_db.json',
        getWorkingDirectory() .. '\\items_db.json'
    }
    for _, dbPath in ipairs(dbPaths) do
        local f = io.open(dbPath, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            local parsed = json.decode(content)
            if parseItemsDatabaseTable(parsed) > 0 then
                return true
            end
        end
    end
    return false
end

local function load()
    loadLocalItemsDb()
    local file = io.open(path, 'r')
    if not file then return end
    local data = json.decode(file:read('*a'))
    file:close()
    if type(data) ~= 'table' then return end
    for id, name in pairs(data.itemNames or {}) do
        local numId = tonumber(id)
        if numId and type(name) == 'string' and name ~= '' then
            names[numId] = name
            config.itemNames[tostring(numId)] = name
        end
    end
    if type(data.presets) == 'table' and #data.presets > 0 then
        config.presets = data.presets
        for _, p in ipairs(config.presets) do
            if type(p.sell) == 'table' then groupIdenticalItems(p.sell, 'sell') end
            if type(p.buy) == 'table' then groupIdenticalItems(p.buy, 'buy') end
        end
    end
    for _, item in ipairs(data.buyCatalog or {}) do
        if item.page and item.row and item.name then
            buyCatalog[tostring(item.page) .. ':' .. tostring(item.row)] = item
            buyNames[item.name] = true
        end
    end
    if type(data.sellable) == 'table' then config.sellable = data.sellable end
    if type(data.buyProgress) == 'table' and type(data.buyProgress.items) == 'table' then config.buyProgress = data.buyProgress end
    if type(data.sellProgress) == 'table' and type(data.sellProgress.items) == 'table' then
        config.sellProgress = data.sellProgress
        resumeSale = true
    end
    if type(data.logs) == 'table' then
        config.logs.sell = type(data.logs.sell) == 'table' and data.logs.sell or {}
        config.logs.buy = type(data.logs.buy) == 'table' and data.logs.buy or {}
    end
    for _, kind in ipairs({1, 13, 28}) do
        for slot, item in pairs(data.inventory and data.inventory[tostring(kind)] or {}) do
            local index = tonumber(slot)
            if index and type(item) == 'table' and tonumber(item.item) and item.item > 0 then
                inventory[kind][index] = item
            end
        end
    end
    if type(data.calcHotkey) == 'table' and tonumber(data.calcHotkey.key) then
        config.calcHotkey = {
            ctrl = data.calcHotkey.ctrl == true,
            shift = data.calcHotkey.shift == true,
            alt = data.calcHotkey.alt == true,
            key = tonumber(data.calcHotkey.key)
        }
    end
    for _, key in ipairs({'shopName', 'commission', 'markup', 'autoName', 'autoColor', 'autoRent', 'shopColorIdx', 'calcEnabled', 'optimizer', 'optimizerMode', 'showZones', 'extended', 'vcCourse', 'vcRate', 'itemStealer', 'stealerX', 'stealerY'}) do
        if data[key] ~= nil then config[key] = data[key] end
    end
end

local function sync()
    ffi.copy(shopName, config.shopName or '')
    commission[0] = tonumber(config.commission) or 0
    markup[0] = tonumber(config.markup) or 20
    autoName[0] = config.autoName == true
    autoColor[0] = config.autoColor == true
    autoRent[0] = config.autoRent == true
    shopColorIdx[0] = math.max(0, math.min(#shopColors - 1, tonumber(config.shopColorIdx) or 0))
    calcEnabled[0] = config.calcEnabled == true
    showZones[0] = config.showZones == true
    extended[0] = config.extended == true
    vcCourse[0] = config.vcCourse == true
    vcRate[0] = tonumber(config.vcRate) or 100
    itemStealer[0] = config.itemStealer ~= false
    optimizer[0] = config.optimizer == true
    optimizerMode[0] = math.max(0, math.min(2, tonumber(config.optimizerMode) or 0))
end

local needWorldOptimize = false

local function destroySampObjectById(objId)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt16(bs, objId)
    raknetEmulRpcReceiveBitStream(47, bs)
    raknetDeleteBitStream(bs)
end

local function isCustomSkinModel(skin)
    skin = tonumber(skin)
    if not skin then return false end
    return skin < 0 or skin > 311
end

local function setPlayerSafeSkin(playerId, skinId)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt32(bs, playerId)
    raknetBitStreamWriteInt32(bs, skinId)
    raknetEmulRpcReceiveBitStream(153, bs)
    raknetDeleteBitStream(bs)
end

local function applyWorldOptimizer()
    if not config.optimizer then return end
    local remObj = (config.optimizerMode == 0 or config.optimizerMode == 1)
    local repSkin = (config.optimizerMode == 0 or config.optimizerMode == 2)

    if remObj and getCharActiveInterior(PLAYER_PED) == 0 then
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        for sampId = 0, 2048 do
            local obj = sampGetObjectHandleBySampId(sampId)
            if obj and obj ~= 0 and doesObjectExist(obj) then
                local ok, ox, oy, oz = getObjectCoordinates(obj)
                local isFloorUnderPlayer = ok and math.abs(ox - px) < 6 and math.abs(oy - py) < 6 and oz < pz and (pz - oz) < 3.5 and pz > 900
                if not isFloorUnderPlayer then
                    destroySampObjectById(sampId)
                end
            end
        end
    end

    if repSkin and getAllChars then
        for _, ped in ipairs(getAllChars()) do
            if doesCharExist(ped) and ped ~= PLAYER_PED then
                local ok, pid = sampGetPlayerIdByCharHandle(ped)
                if ok and pid and pid >= 0 then
                    local skin = getCharModel(ped)
                    if isCustomSkinModel(skin) then
                        setPlayerSafeSkin(pid, 1)
                    end
                end
            end
        end
    end
end

local function applySettings()
    config.shopName = ffi.string(shopName):sub(1, 60)
    config.commission = math.max(0, math.min(100, commission[0]))
    commission[0] = config.commission
    config.markup = math.max(0, markup[0])
    markup[0] = config.markup
    config.autoName = autoName[0]
    config.autoColor = autoColor[0]
    config.autoRent = autoRent[0]
    config.shopColorIdx = math.max(0, math.min(#shopColors - 1, shopColorIdx[0]))
    shopColorIdx[0] = config.shopColorIdx
    config.calcEnabled = calcEnabled[0]
    if not config.calcEnabled then calcWin[0] = false end
    config.showZones = showZones[0]
    config.extended = extended[0]
    config.vcCourse = vcCourse[0]
    config.vcRate = math.max(1, vcRate[0])
    vcRate[0] = config.vcRate
    config.itemStealer = itemStealer[0]
    config.optimizer = optimizer[0]
    config.optimizerMode = math.max(0, math.min(2, optimizerMode[0]))
    optimizerMode[0] = config.optimizerMode
    if config.optimizer then needWorldOptimize = true end
    stealerWin[0] = lavkaOpen and config.itemStealer and not isMyLavka
    save()
end

local function sendCef(action, data)
    local text = action
    if data then text = text .. '|' .. data end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #text)
    raknetBitStreamWriteString(bs, text)
    raknetBitStreamWriteInt32(bs, browser)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

local function evalCef(code)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, browser)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

local function closeCefInventory()
    evalCef("document.querySelector('.inventory-window__header-control-close').click()")
    if not window[0] and not calcWin[0] and not sampIsDialogActive() then
        sampToggleCursor(false)
    end
end

local function rememberItem(id, name)
    id = tonumber(id)
    if not id or not name or name == '' then return end
    name = cleanName(name)
    if names[id] == name then return end
    names[id] = name
    config.itemNames[tostring(id)] = name
    save()
end

local function updateNames()
    if namesUpdating then return end
    namesUpdating = true
    lua_thread.create(function()
        local url = 'https://items.shinoa.tech/items.php?action=fetchall&_=' .. os.time()
        local res = urlmon.URLDownloadToFileA(nil, url, namesTempFile, 0, nil)
        if res == 0 then
            namesReadyToParse = true
        else
            namesUpdating = false
        end
    end)
end

local function itemName(id, fallbackName)
    id = tonumber(id)
    if id and id > 0 then
        if not names[id] and not missingNames[id] then
            missingNames[id] = true
            updateNames()
        end
        if names[id] then return cleanName(names[id]) end
        if fallbackName and fallbackName ~= '' then return cleanName(fallbackName) end
        return 'ID ' .. tostring(id)
    end
    if fallbackName and fallbackName ~= '' then return cleanName(fallbackName) end
    return '?'
end

local function findItemIdByName(name)
    local target = searchText(name)
    if target == '' then return nil end
    local targetNoBrackets = searchText((name or ''):gsub('%s*%b()', ''))
    local fallbackId = nil
    for id, n in pairs(names) do
        local clean = searchText(n)
        if clean == target then
            return tonumber(id)
        elseif not fallbackId and targetNoBrackets ~= '' and searchText(n:gsub('%s*%b()', '')) == targetNoBrackets then
            fallbackId = tonumber(id)
        end
    end
    for _, kind in ipairs({1, 13, 28}) do
        for _, it in pairs(inventory[kind]) do
            local id = tonumber(it.item)
            if id and id > 0 then
                local clean = searchText(itemName(id, it.name))
                if clean == target or (targetNoBrackets ~= '' and clean == targetNoBrackets) then
                    return id
                end
            end
        end
    end
    return fallbackId
end

local function sortedItems(kind)
    local invType = kind == 'sell' and 1 or (kind == 'clearBuy' and 28 or 13)
    local result = {}
    for _, item in pairs(inventory[invType]) do
        if tonumber(item.item) and item.item > 0 then result[#result + 1] = item end
    end
    table.sort(result, function(a, b) return a.slot < b.slot end)
    return result
end

local function itemCount(item)
    local a = tonumber(item.amount)
    if a and a > 0 then return a end
    local t = tonumber(tostring(item.text or ''):match('(%d+)'))
    if t and t > 0 then return t end
    return 1
end

local function getInventoryStockCount(item)
    local id = tonumber(item.id)
    if (not id or id <= 0) and item.name then
        id = findItemIdByName(item.name)
    end
    if not id or id <= 0 then return 0 end
    local totalCount = 0
    for _, stocked in pairs(inventory[1]) do
        if tonumber(stocked.item) == id then
            totalCount = totalCount + itemCount(stocked)
        end
    end
    return totalCount
end

local function slotStackCount(invItem)
    if not invItem then return 1 end
    local txt = tostring(invItem.text or '')
    if txt ~= '' and txt ~= '$' then
        local num = tonumber(txt) or tonumber(txt:match('^(%d+)%s*шт')) or tonumber(txt:match('^(%d+)$'))
        if num and num > 0 and num ~= tonumber(invItem.amount) then
            return num
        end
    end
    return 1
end

local function groupedLavkaItems(invType)
    local kind = invType == 28 and 'clearBuy' or 'clearSell'
    local raw = sortedItems(kind)
    local grouped = {}
    local order = {}
    for _, invItem in ipairs(raw) do
        local id = tonumber(invItem.item)
        local price = tonumber(invItem.amount) or 0
        local count = slotStackCount(invItem)
        if id and id > 0 and price > 0 then
            local key = tostring(id) .. ':' .. tostring(price)
            if not grouped[key] then
                grouped[key] = {id = id, price = price, amount = 0}
                order[#order + 1] = grouped[key]
            end
            grouped[key].amount = grouped[key].amount + count
        end
    end
    return order
end

local function money(value)
    local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
    local sign = text:match('^%-') and '-' or ''
    text = text:gsub('%-', '')
    local formatted = text:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')
    return sign .. formatted .. ' $'
end

local function showRate()
    return config.vcCourse and sampGetCurrentServerName():find('Vice City', 1, true) ~= nil
end

local function serverMoney(value)
    return money((tonumber(value) or 0) * config.vcRate)
end

local function moneyWidth(value)
    local width = imgui.CalcTextSize(money(value)).x
    if showRate() then
        width = width + imgui.GetStyle().ItemSpacing.x + imgui.CalcTextSize(serverMoney(value)).x
    end
    return width
end

local function drawMoney(value)
    imgui.Text(money(value))
    if showRate() then
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.36, 0.78, 0.80, 1), serverMoney(value))
        if imgui.IsItemHovered() then
            imgui.SetTooltip('Это сумма в деньгах твоего сервера.\nКурс: ' .. config.vcRate)
        end
    end
end

local function activeItem(list, index, kind)
    local item = list[index]
    if not item or item.enabled == false then return false end
    local selected
    for i, other in ipairs(list) do
        if sameItem(item, other, kind) then
            if other.selected then selected = i break end
            if not selected then selected = i end
        end
    end
    return not selected or selected == index
end

local function nextActive(list, index, kind)
    while list[index] and not activeItem(list, index, kind) do index = index + 1 end
    return index
end

local function findBuy(name)
    for _, item in pairs(buyCatalog) do
        if item.name == name then return item end
    end
end

local function addStolenEntry(targetKind, id, amount, price, explicitName)
    local targetList = preset()[targetKind]
    id = tonumber(id)
    local name = explicitName and cleanName(explicitName) or (id and itemName(id) or '?')
    if targetKind == 'sell' then
        local updated = false
        for _, existing in ipairs(targetList) do
            local same = (id and tonumber(existing.id) == id) or (not id and existing.name and searchText(existing.name) == searchText(name))
            if same and tonumber(existing.price) == price then
                existing.amount = amount
                if id then existing.id = id end
                if name ~= '?' then existing.name = name end
                updated = true
                break
            end
        end
        if not updated then
            insertGrouped(targetList, {id = id, name = name, amount = amount, price = price, enabled = true}, 'sell')
        else
            groupIdenticalItems(targetList, 'sell')
        end
    else
        local found = findBuy(name)
        local updated = false
        for _, existing in ipairs(targetList) do
            if existing.name == name and tonumber(existing.price) == price then
                existing.amount = amount
                if id then existing.id = id end
                if found then existing.page, existing.row = found.page, found.row end
                updated = true
                break
            end
        end
        if not updated then
            insertGrouped(targetList, {
                id = id,
                name = name,
                amount = amount,
                price = price,
                page = found and found.page or nil,
                row = found and found.row or nil,
                enabled = true
            }, 'buy')
        else
            groupIdenticalItems(targetList, 'buy')
        end
    end
end

local function transferSingleBuyToSell(item)
    if not item then return false end
    local id = tonumber(item.id) or findItemIdByName(item.name)
    if id then item.id = id end
    local pct = tonumber(config.markup) or 20
    local newPrice = math.max(1, math.floor((tonumber(item.price) or 0) * (1 + pct / 100) + 0.5))
    local amount = tonumber(item.amount) or 1
    addStolenEntry('sell', id, amount, newPrice, item.name)
    save()
    return true, newPrice
end

local function transferAllBuyToSell()
    local list = preset().buy
    if #list == 0 then
        notify('{ff5555}Список скупки пуст')
        return
    end
    local count = 0
    local pct = tonumber(config.markup) or 20
    for index, item in ipairs(list) do
        if activeItem(list, index, 'buy') then
            local id = tonumber(item.id) or findItemIdByName(item.name)
            if id then item.id = id end
            local newPrice = math.max(1, math.floor((tonumber(item.price) or 0) * (1 + pct / 100) + 0.5))
            local amount = tonumber(item.amount) or 1
            addStolenEntry('sell', id, amount, newPrice, item.name)
            count = count + 1
        end
    end
    if count > 0 then
        save()
        local pctStr = pct % 1 == 0 and string.format('%d%%', pct) or string.format('%.1f%%', pct)
        notify(string.format('Перенесено в продажу (%s, наценка +%s): %d шт.', preset().name, pctStr, count))
    else
        notify('{ff5555}Нет включенных товаров в скупке для переноса')
    end
end

local function distributeBuyItems()
    local list = preset().buy
    if #list == 0 then
        notify('{ff5555}Список скупки пуст')
        return
    end
    local budget = tonumber(playerMoney) or 0
    if budget <= 0 then
        budget = getPlayerMoney(PLAYER_HANDLE) or 0
    end
    if budget <= 0 then
        notify('{ff5555}Недостаточно денег на балансе для распределения')
        return
    end

    local activeIndices = {}
    for index, item in ipairs(list) do
        if activeItem(list, index, 'buy') and (tonumber(item.price) or 0) > 0 then
            activeIndices[#activeIndices + 1] = index
        end
    end

    if #activeIndices == 0 then
        notify('{ff5555}Нет включенных товаров для распределения')
        return
    end

    local fitting = {}
    local remBudget = budget

    for _, idx in ipairs(activeIndices) do
        local item = list[idx]
        local p = tonumber(item.price) or 0
        if remBudget >= p then
            fitting[#fitting + 1] = idx
            remBudget = remBudget - p
        else
            item.enabled = false
            notify('{ff5555}Не удалось установить количество из-за нехватки денег: {ffffff}' .. tostring(item.name))
        end
    end

    if #fitting == 0 then
        save()
        return
    end

    local counts = {}
    for _, idx in ipairs(fitting) do
        counts[idx] = 1
    end

    local share = math.floor(remBudget / #fitting)
    if share > 0 then
        for _, idx in ipairs(fitting) do
            local p = tonumber(list[idx].price) or 1
            local extra = math.floor(share / p)
            if extra > 0 then
                counts[idx] = counts[idx] + extra
                remBudget = remBudget - extra * p
            end
        end
    end

    while true do
        local boughtAny = false
        for _, idx in ipairs(fitting) do
            local p = tonumber(list[idx].price) or 1
            if remBudget >= p then
                counts[idx] = counts[idx] + 1
                remBudget = remBudget - p
                boughtAny = true
            end
        end
        if not boughtAny then break end
    end

    for _, idx in ipairs(fitting) do
        list[idx].amount = math.max(1, counts[idx])
    end

    save()
    notify('Количество товаров распределено под ваш баланс (' .. money(budget - remBudget) .. ')')
end

local function saveSellProgress()
    if not queue or queue.kind ~= 'sell' then return end
    local items = {}
    for index, item in ipairs(preset().sell) do
        local left = queue.remaining[index] or 0
        if activeItem(preset().sell, index, 'sell') and left > 0 then
            items[#items + 1] = {index = index, name = itemName(item.id, item.name), left = left}
        end
    end
    config.sellProgress = #items > 0 and {preset = selectedPreset, items = items} or nil
    save()
end

local function nextSellIndex(index)
    local list = preset().sell
    index = nextActive(list, index, 'sell')
    while list[index] and (queue.remaining[index] or 0) <= 0 do
        index = nextActive(list, index + 1, 'sell')
    end
    return index
end

local function saveBuyProgress()
    if not queue or queue.kind ~= 'buy' then return end
    local items = {}
    for index, item in ipairs(preset().buy) do
        local left = queue.remaining[index] or 0
        if activeItem(preset().buy, index, 'buy') and left > 0 then
            items[#items + 1] = {index = index, name = item.name, left = left}
        end
    end
    config.buyProgress = #items > 0 and {preset = selectedPreset, items = items} or nil
    save()
end

local function updateBuyProgress(message)
    if not config.buyProgress then return end
    local text = searchText(message)
    local amount = tonumber(message:match('(%d+)%s*шт')) or tonumber(message:match('(%d+)%s*x')) or 1
    local items = {}
    for _, entry in ipairs(config.buyProgress.items) do
        local name = searchText(entry.name)
        if name ~= '' and text:find(name, 1, true) then
            entry.left = math.max(0, (tonumber(entry.left) or 0) - amount)
        end
        if entry.left > 0 then items[#items + 1] = entry end
    end
    config.buyProgress.items = items
    if #items == 0 then config.buyProgress = nil end
    save()
end

local function updateSellProgress(message)
    if not config.sellProgress then return end
    local text = searchText(message)
    local amount = tonumber(message:match('(%d+)%s*шт')) or tonumber(message:match('(%d+)%s*x')) or 1
    local items = {}
    for _, entry in ipairs(config.sellProgress.items) do
        local name = searchText(entry.name)
        if name ~= '' and text:find(name, 1, true) then
            entry.left = math.max(0, (tonumber(entry.left) or 0) - amount)
        end
        if entry.left > 0 then items[#items + 1] = entry end
    end
    config.sellProgress.items = items
    if #items == 0 then
        config.sellProgress = nil
        resumeSale = false
    end
    save()
end

local function nextBuy(index)
    local list = preset().buy
    index = nextActive(list, index, 'buy')
    while list[index] and (queue.remaining[index] or 0) <= 0 do
        index = nextActive(list, index + 1, 'buy')
    end
    return index
end

local function total(list, kind)
    local sum = 0
    for index, item in ipairs(list) do
        if activeItem(list, index, kind) then sum = sum + (item.price or 0) * (item.amount or 1) end
    end
    return sum
end

local function isMain(text)
    local clean = cleanName(utf(text or ''))
    return clean:find('Управление продажей', 1, true) or clean:find('Добавить товар на покупку', 1, true) or clean:find('Выставить товар на продажу', 1, true)
end

local function mainDialogText()
    local text = mainDialog.text .. cp('\n{9db7d6}Открыть Chromo')
    if config.extended then
        text = text .. cp('\n{9db7d6}Пресет: {ffffff}' .. preset().name .. '\n{9db7d6}Выставить на продажу\n{9db7d6}Выставить скупку')
    end
    return text
end

local function isBuyList(text, title)
    return (title or ''):find(cp('Страница'), 1, true) and (text or ''):find(cp('Следующая страница'), 1, true)
end

local function isSearchInput(text, title)
    return (title or ''):find(cp('Поиск товара'), 1, true) and (text or ''):find(cp('Введите наименование товара'), 1, true)
end

local function isSearchResults(text, title, style)
    return (title or ''):find(cp('Поиск товара'), 1, true) and style == 2
end

local function isSinglePriceDialog(text)
    local clean = cleanName(utf(text or ''))
    return clean:find('Введите цену за товар', 1, true) ~= nil
end

local function isAmountPriceDialog(text)
    local clean = cleanName(utf(text or ''))
    return clean:find('Введите количество и цену', 1, true) ~= nil
end

local function inMarketArea(x, y)
    return x > 1090 and x < 1180 and y > -1550 and y < -1429
end

local function drawRing3D(draw, cx, cy, cz, radius, color)
    local points = 48
    local step = (math.pi * 2) / points
    local prevX, prevY
    for i = 0, points do
        local angle = i * step
        local wx = cx + math.cos(angle) * radius
        local wy = cy + math.sin(angle) * radius
        local _, sx, sy, sz = convert3DCoordsToScreenEx(wx, wy, cz)
        if sz and sz > 1 then
            if prevX and prevY then
                draw:AddLine(imgui.ImVec2(prevX, prevY), imgui.ImVec2(sx, sy), color, 1.8)
            end
            prevX, prevY = sx, sy
        else
            prevX, prevY = nil, nil
        end
    end
end

local function nearShop()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    for id = 0, 2048 do
        if sampIs3dTextDefined(id) then
            local text, _, x, y, z = sampGet3dTextInfoById(id)
            if getDistanceBetweenCoords3d(x, y, z, px, py, pz) <= 3.5 then
                local clean = (text or ''):gsub('{%x%x%x%x%x%x}', '')
                if clean:find(cp('Управлени'), 1, true) or clean:find(cp('управлени'), 1, true) or clean:find(cp('товарами'), 1, true) or clean:find(cp('прилавк'), 1, true) or clean:find(cp('Лавка'), 1, true) or clean:find(cp('лавка'), 1, true) or clean:find('Alt', 1, true) or clean:find('ALT', 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function pressAlt()
    forceAltUntil = os.clock() + 0.35
    lua_thread.create(function()
        setGameKeyState(21, 255)
        if sampForceOnfootSync then sampForceOnfootSync() end
        wait(100)
        setGameKeyState(21, 0)
        if sampForceOnfootSync then sampForceOnfootSync() end
    end)
end

function sampev.onSendPlayerSync(data)
    if os.clock() < forceAltUntil then
        data.keysData = bit.bor(data.keysData or 0, 1024)
        data.leftRightKeys = 0
        data.upDownKeys = 0
    end
end

local function activeDialog()
    if sampIsDialogActive() then
        local id = sampGetCurrentDialogId()
        local text = sampGetDialogText()
        local title = sampGetDialogCaption()
        if dialog and dialog.id == id then
            return dialog
        end
        if mainDialog and mainDialog.id == id then
            return mainDialog
        end
        return {id = id, title = title, text = text, style = 2}
    end
    if (queue or scan) and serverDialogOpen and dialog then
        return dialog
    end
    return nil
end

local function sendResponse(id, button, row, text)
    serverDialogOpen = false
    sampSendDialogResponse(id, button or 1, row or 0, text or '')
end

local function answer(id, row, text)
    sendResponse(id, 1, row, text)
end

local function searchQuery(name, shortFallback)
    local s = cp(cleanName(name))
    if not shortFallback then
        local noBrackets = s:gsub('%s*%b()%s*', ' '):gsub('^%s+', ''):gsub('%s+$', '')
        local best = ''
        for part in noBrackets:gmatch('[%a%d\192-\255\168\184][%a%d\192-\255\168\184%s%-]*') do
            part = part:gsub('^%s+', ''):gsub('%s+$', '')
            if #part > #best then best = part end
        end
        if #best >= 3 then
            return best:sub(1, 20):gsub('%s+$', '')
        end
    end
    local first = s:match('([%a\192-\255\168\184]+)')
    if first and #first >= 3 then
        return first:sub(1, 12)
    end
    local chunk = s:sub(1, 12):gsub('%s+$', '')
    if #chunk >= 3 then
        return chunk
    end
    return nil
end

local function catalogKey(page, row)
    return tostring(page) .. ':' .. tostring(row)
end

local function parseBuyPage(text, title)
    local page, pages = title:match('(%d+)%s*/%s*(%d+)')
    page, pages = tonumber(page), tonumber(pages)
    local result = {}
    local row = 0
    for line in text:gmatch('[^\r\n]+') do
        if row > 0 then
            local name = line:match('^([^\t]+)')
            if name and name ~= '' and not line:find('<<<', 1, true) and not line:find('>>>', 1, true) and not line:find(cp('Избранное'), 1, true) then
                name = cleanName(utf(name))
                if not name:upper():find('DELETED', 1, true) then
                    local key = catalogKey(page, row - 1)
                    result[#result + 1] = {name = name, page = page, row = row - 1, key = key}
                    buyCatalog[key] = result[#result]
                    buyNames[name] = true
                end
            end
        end
        row = row + 1
    end
    return result, page, pages
end

local function copySingleLavkaItem(invType, entry)
    local targetKind = invType == 28 and 'buy' or 'sell'
    addStolenEntry(targetKind, entry.id, entry.amount, entry.price)
    save()
    local modeText = targetKind == 'sell' and 'продажу' or 'скупку'
    notify(string.format('Скопировано в %s (%s): %s x%d за %s', modeText, preset().name, itemName(entry.id), entry.amount, money(entry.price)))
end

local function copyAllLavkaItems(invType)
    local items = groupedLavkaItems(invType)
    if #items == 0 then
        notify('{ff5555}В этой вкладке лавки нет товаров')
        return
    end
    local targetKind = invType == 28 and 'buy' or 'sell'
    for _, entry in ipairs(items) do
        addStolenEntry(targetKind, entry.id, entry.amount, entry.price)
    end
    save()
    local modeText = targetKind == 'sell' and 'продажу' or 'скупку'
    notify(string.format('Скопировано позиций в %s (%s): %d шт.', modeText, preset().name, #items))
end

local function saveCatalog()
    config.buyCatalog = {}
    for _, item in pairs(buyCatalog) do
        config.buyCatalog[#config.buyCatalog + 1] = {name = item.name, page = item.page, row = item.row}
    end
    save()
end

local function stopWork(message, failed)
    local scanning = scan ~= nil
    if scanning or queue or failed then
        statusFailed = failed == true
        statusDone = os.clock() + 1.4
    end
    if queue and queue.kind == 'buy' and queue.finished then
        config.buyProgress = nil
        save()
    end
    if queue and queue.kind == 'sell' then resumeSale = not queue.finished end
    local wasCefWork = queue and (queue.kind == 'sell' or queue.kind == 'clearSell' or queue.kind == 'clearBuy')
    queue = nil
    scan = nil
    if dialog and serverDialogOpen and (isSearchInput(dialog.text, dialog.title) or isSearchResults(dialog.text, dialog.title, dialog.style) or isBuyList(dialog.text, dialog.title) or isSinglePriceDialog(dialog.text) or isAmountPriceDialog(dialog.text)) then
        sendResponse(dialog.id, 0, 0, '')
    end
    if sampIsDialogActive() then
        sampCloseCurrentDialogWithButton(0)
    end
    if wasCefWork then
        closeCefAt = os.clock() + 0.1
    end
    if scanning and not failed then saveCatalog() end
    if message then
        message = message:gsub('^%[Ошибка%]%s*', ''):gsub('^%[Информация%]%s*', ''):gsub('^Ошибка:%s*', '')
        notify((failed and '{ff5555}Ошибка: {ffffff}' or '') .. message)
    end
end

local function mainChoice(choice)
    local current = activeDialog()
    if current then
        if isMain(current.text) then
            answer(current.id, choice)
            return true
        end
        if isBuyList(current.text, current.title) or isSearchInput(current.text, current.title) or isSearchResults(current.text, current.title, current.style) or isSinglePriceDialog(current.text) or isAmountPriceDialog(current.text) then
            sendResponse(current.id, 0, 0, '')
            return 'back'
        end
    end
    if nearShop() then
        pressAlt()
        return 'alt'
    end
    return false
end

local function watchStep(expectedStage, message, customTimeout)
    if not queue then return end
    queue.stepToken = (queue.stepToken or 0) + 1
    queue.stepDeadline = os.clock() + (customTimeout or 2.5)
    queue.stepStage = expectedStage
    queue.stepError = message or 'Нет ответа от лавки'
end

local function skipSellItem(reason)
    if not queue or queue.kind ~= 'sell' then return end
    if reason then
        reason = reason:gsub('^%[Ошибка%]%s*', ''):gsub('^Ошибка:%s*', '')
        notify('Пропуск: ' .. reason)
    end
    queue.remaining[queue.index] = 0
    saveSellProgress()
    queue.left = nil
    queue.placedForItem = nil
    queue.actualAmount = nil
    queue.slotAmount = nil
    queue.retries = nil
    queue.actionRetries = nil
    queue.stage = 'next'
    queue.stepStage = nil
    queue.index = nextSellIndex(queue.index + 1)
    nextSell()
end

local function advanceBuy()
    queue.actualAmount = nil
    queue.fallback = false
    queue.triedShort = false
    queue.query = nil
    if queue.index then
        queue.remaining[queue.index] = 0
        saveBuyProgress()
    end
    queue.index = nextBuy(queue.index + 1)
    if queue.index > #preset().buy then
        queue.finished = true
        if (queue.count or 0) == 0 then
            stopWork('Ни один товар не был выставлен на скупку', true)
        else
            stopWork('Скупка настроена')
        end
        return
    end
    queue.stage = 'waitMain'
    watchStep('waitMain', 'Потеряно окно лавки при выставлении скупки', 2.5)
end

local function requestBuyItem(allowAlt)
    if not queue or queue.kind ~= 'buy' then return end
    local item = preset().buy[queue.index]
    if not item then
        queue.finished = true
        if (queue.count or 0) == 0 then
            stopWork('Ни один товар не был выставлен на скупку', true)
        else
            stopWork('Скупка настроена')
        end
        return
    end
    local found = findBuy(item.name)
    if found then item.page, item.row = found.page, found.row end
    local q = not queue.fallback and searchQuery(item.name) or nil
    local current = activeDialog()

    if q then
        queue.query = q
        if current and isSearchInput(current.text, current.title) then
            queue.stage = 'searchResult'
            answer(current.id, 0, q)
            watchStep('searchResult', 'Товар не найден через поиск: ' .. item.name)
        elseif current and isSearchResults(current.text, current.title, current.style) then
            queue.stage = 'searchInput'
            sendResponse(current.id, 0, 0, '')
            watchStep('searchInput', 'Лавка не открыла поиск товаров')
        elseif current and isBuyList(current.text, current.title) then
            queue.stage = 'waitMain'
            sendResponse(current.id, 0, 0, '')
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
        elseif current and isMain(current.text) then
            queue.stage = 'searchInput'
            answer(current.id, 2)
            watchStep('searchInput', 'Лавка не открыла поиск товаров')
        elseif allowAlt then
            local res = mainChoice(2)
            if res == true then
                queue.stage = 'searchInput'
                watchStep('searchInput', 'Лавка не открыла поиск товаров')
            elseif res == 'back' or res == 'alt' then
                queue.stage = 'waitMain'
                watchStep('waitMain', 'Не удалось открыть меню лавки')
            else
                stopWork('Подойдите впритык к лавке', true)
            end
        else
            queue.stage = 'waitMain'
            watchStep('waitMain', 'Потеряно окно лавки при выставлении скупки', 2.5)
        end
    elseif item.page and item.row then
        queue.stage = 'catalog'
        if current and isBuyList(current.text, current.title) then
            processQueue(current.id, current.title, current.text, current.style)
        elseif current and (isSearchInput(current.text, current.title) or isSearchResults(current.text, current.title, current.style)) then
            queue.stage = 'waitMain'
            sendResponse(current.id, 0, 0, '')
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
        elseif current and isMain(current.text) then
            answer(current.id, 1)
            watchStep('catalog', 'Лавка не открыла каталог скупки')
        elseif allowAlt then
            local res = mainChoice(1)
            if res == true then
                watchStep('catalog', 'Лавка не открыла каталог скупки')
            elseif res == 'back' or res == 'alt' then
                queue.stage = 'waitMain'
                watchStep('waitMain', 'Не удалось открыть меню лавки')
            else
                stopWork('Подойдите впритык к лавке', true)
            end
        else
            queue.stage = 'waitMain'
            watchStep('waitMain', 'Потеряно окно лавки при выставлении скупки', 2.5)
        end
    else
        notify('Пропуск (нет в каталоге): ' .. tostring(item.name))
        advanceBuy()
        if queue then
            local cur = activeDialog()
            if cur and isMain(cur.text) then
                requestBuyItem(false)
            end
        end
    end
end

local function startSell(resume)
    local list = preset().sell
    if #list == 0 then stopWork('Список продажи пуст', true) return end
    local res = mainChoice(0)
    if not res then stopWork('Подойдите впритык к лавке', true) return end
    queue = {kind = 'sell', stage = (res == 'back' or res == 'alt') and 'menu' or 'waitInv', count = 0, usedSlots = {}, taken = {}, remaining = {}}
    if resume and config.sellProgress and config.sellProgress.preset == selectedPreset then
        local byName = {}
        for _, entry in ipairs(config.sellProgress.items) do
            if entry.name then byName[entry.name] = tonumber(entry.left) or 0 end
        end
        for index, item in ipairs(list) do
            local n = itemName(item.id, item.name)
            if byName[n] ~= nil then
                queue.remaining[index] = byName[n]
            end
        end
    else
        for index, item in ipairs(list) do
            queue.remaining[index] = tonumber(item.amount) or 1
        end
        saveSellProgress()
    end
    queue.index = nextSellIndex(1)
    if not list[queue.index] then stopWork('Нет товаров для продолжения', true) return end
    if res == true then
        watchStep('waitInv', 'Не удалось открыть инвентарь лавки', 0.4)
    else
        watchStep('menu', 'Не удалось открыть меню лавки')
    end
end

local function startBuy(resume)
    local list = preset().buy
    if #list == 0 then stopWork('Список скупки пуст', true) return end
    queue = {kind = 'buy', stage = 'menu', count = 0, remaining = {}}
    if resume and config.buyProgress and config.buyProgress.preset == selectedPreset then
        local byName = {}
        for _, entry in ipairs(config.buyProgress.items) do
            if entry.name then byName[entry.name] = tonumber(entry.left) or 0 end
        end
        for index, item in ipairs(list) do
            if byName[item.name] ~= nil then
                queue.remaining[index] = byName[item.name]
            end
        end
    else
        for index, item in ipairs(list) do
            queue.remaining[index] = tonumber(item.amount) or 1
        end
        saveBuyProgress()
    end
    queue.index = nextBuy(1)
    if not list[queue.index] then stopWork('Нет товаров для продолжения', true) return end
    notify('{FA8072}Не открывайте никаких диалогов до полного завершения выставления товаров на скупку.')
    requestBuyItem(true)
end

local function startScan()
    local current = activeDialog()
    if current and isBuyList(current.text, current.title) then
        scan = {seen = {}, count = 0}
        notify('Сканирование скупки запущено')
        processQueue(current.id, current.title, current.text, current.style)
    else
        local res = mainChoice(1)
        if res then
            scan = {seen = {}, count = 0, deadline = os.clock() + 3.5}
            notify('Сканирование скупки запущено')
        else
            stopWork('Подойдите впритык к лавке', true)
        end
    end
end

local function clearSell()
    local res = mainChoice(0)
    if not res and #sortedItems('clearSell') == 0 then
        stopWork('Подойдите впритык к лавке', true)
        return
    end
    if not res then
        queue = {kind = 'clearSell', index = 1, stage = 'items', count = 0, failedSlots = {}}
        nextClearSell()
        return
    end
    queue = {kind = 'clearSell', index = 1, stage = (res == 'back' or res == 'alt') and 'menu' or 'waitInv', count = 0, failedSlots = {}}
    if res == true then
        watchStep('waitInv', 'Не удалось открыть продажу лавки', 0.35)
    else
        watchStep('menu', 'Не удалось открыть меню лавки')
    end
end

local function clearBuy()
    local res = mainChoice(3)
    if not res and #sortedItems('clearBuy') == 0 then
        stopWork('Подойдите впритык к лавке', true)
        return
    end
    if not res then
        queue = {kind = 'clearBuy', index = 1, stage = 'items', count = 0, failedSlots = {}}
        nextClearBuy()
        return
    end
    queue = {kind = 'clearBuy', index = 1, stage = (res == 'back' or res == 'alt') and 'menu' or 'waitInv', count = 0, failedSlots = {}}
    if res == true then
        watchStep('waitInv', 'Не удалось открыть скупку лавки', 0.35)
    else
        watchStep('menu', 'Не удалось открыть меню лавки')
    end
end

nextSell = function()
    if not queue or queue.kind ~= 'sell' then return end
    local list = preset().sell
    queue.index = nextSellIndex(queue.index)
    local wanted = list[queue.index]
    if not wanted then
        queue.finished = true
        if (queue.count or 0) == 0 then
            stopWork('Ни один товар из списка не удалось выставить', true)
        else
            stopWork('Продажа завершена')
        end
        return
    end
    if not tonumber(wanted.id) and wanted.name then
        wanted.id = findItemIdByName(wanted.name)
    end
    queue.usedSlots = queue.usedSlots or {}
    queue.taken = queue.taken or {}
    local found
    local foundAvail = 0
    for _, item in ipairs(sortedItems('sell')) do
        if tonumber(wanted.id) and tonumber(item.item) == tonumber(wanted.id) and not queue.usedSlots[item.slot] then
            local rem = itemCount(item) - (queue.taken[item.slot] or 0)
            if rem > 0 then
                found = item
                foundAvail = rem
                break
            end
        end
    end
    if not found then
        if (queue.placedForItem or 0) > 0 then
            queue.placedForItem = nil
            queue.left = nil
            queue.index = queue.index + 1
            return nextSell()
        end
        notify('Нет в инвентаре: ' .. itemName(wanted.id, wanted.name))
        queue.index = queue.index + 1
        return nextSell()
    end
    if not queue.left then
        queue.left = queue.remaining[queue.index] or tonumber(wanted.amount) or 1
        queue.placedForItem = 0
    end
    queue.stage = 'itemInfo'
    queue.actualAmount = math.min(queue.left, foundAvail)
    queue.slotAmount = foundAvail
    queue.slot = found.slot
    queue.itemType = 1
    queue.retries = 0
    queue.actionRetries = 0
    sendCef('rightClickOnBlock', json.encode({type = 1, slot = found.slot}))
    watchStep('itemInfo', 'Не удалось выбрать предмет', 0.6)
end

nextClearSell = function()
    if not queue or queue.kind ~= 'clearSell' then return end
    queue.failedSlots = queue.failedSlots or {}
    local items = sortedItems('clearSell')
    local targetItem = nil
    for _, it in ipairs(items) do
        if not queue.failedSlots[it.slot] then
            targetItem = it
            break
        end
    end
    if not targetItem then
        if (queue.count or 0) == 0 then
            stopWork('В лавке нет товаров на продаже', true)
        else
            stopWork('Товары сняты с продажи')
        end
        return
    end
    queue.stage = 'clearItemInfo'
    queue.slot = targetItem.slot
    queue.itemType = 13
    queue.retries = 0
    queue.actionRetries = 0
    sendCef('rightClickOnBlock', json.encode({type = 13, slot = targetItem.slot}))
    watchStep('clearItemInfo', 'Не удалось снять товар', 0.6)
end

nextClearBuy = function()
    if not queue or queue.kind ~= 'clearBuy' then return end
    queue.failedSlots = queue.failedSlots or {}
    local items = sortedItems('clearBuy')
    local targetItem = nil
    for _, it in ipairs(items) do
        if not queue.failedSlots[it.slot] then
            targetItem = it
            break
        end
    end
    if not targetItem then
        if (queue.count or 0) == 0 then
            stopWork('В лавке нет товаров на скупке', true)
        else
            stopWork('Товары сняты со скупки')
        end
        return
    end
    queue.stage = 'clearItemInfo'
    queue.slot = targetItem.slot
    queue.itemType = 28
    queue.retries = 0
    queue.actionRetries = 0
    sendCef('rightClickOnBlock', json.encode({type = 28, slot = targetItem.slot}))
    watchStep('clearItemInfo', 'Не удалось снять товар со скупки', 0.6)
end

processQueue = function(id, title, text, style)
    if scan and isBuyList(text, title) then
        scan.deadline = nil
        local items, page, pages = parseBuyPage(text, title)
        if not page or not pages then stopWork('Не удалось прочитать страницу лавки', true) return true end
        scan.page = page
        scan.count = (scan.count or 0) + #items
        if not scan.startPage then
            scan.startPage = page
            scan.direction = page > 1 and -1 or 1
        end
        if page == 1 then scan.direction = 1 end
        scan.seen[page] = true
        if page % 10 == 0 then saveCatalog() end
        if page >= pages or #items == 0 then
            if scan.count == 0 then
                stopWork('Список товаров пуст, не удалось просканировать', true)
            else
                sendResponse(id, 0, 0, '')
                stopWork('Список скупки обновлён')
            end
            return true
        end
        local rows = 0
        for _ in text:gmatch('[^\r\n]+') do rows = rows + 1 end
        local row = scan.direction == 1 and rows - 2 or rows - 3
        sendResponse(id, 1, row, '')
        return true
    end
    if not queue then return false end
    if (queue.kind == 'clearSell' or queue.kind == 'clearBuy') and (title:find(cp('Снятие'), 1, true) or title:find(cp('Прекратить'), 1, true) or text:find(cp('снять'), 1, true) or text:find(cp('прекратить покупку'), 1, true) or queue.stage == 'clearConfirm') and not isMain(text) then
        answer(id, 0)
        if queue.slot and queue.itemType and inventory[queue.itemType] then
            inventory[queue.itemType][queue.slot] = nil
        end
        queue.count = (queue.count or 0) + 1
        queue.stage = 'wait'
        queue.stepStage = nil
        if queue.kind == 'clearSell' then nextClearSell() else nextClearBuy() end
        return true
    end
    if queue.kind == 'buy' and isSearchInput(text, title) then
        if queue.fallback or queue.stage == 'waitMain' then
            sendResponse(id, 0, 0, '')
            queue.stage = 'waitMain'
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
            return true
        end
        local item = preset().buy[queue.index]
        if not item then stopWork('Скупка настроена') return true end
        local q = queue.query or searchQuery(item.name)
        if not q then
            sendResponse(id, 0, 0, '')
            queue.fallback = true
            queue.stage = 'waitMain'
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
            return true
        end
        if queue.retryCooldown then
            queue.retryCooldown = false
            queue.stage = 'searchResult'
            watchStep('searchResult', 'Товар не найден через поиск: ' .. item.name, 2.5)
            lua_thread.create(function()
                wait(50)
                if queue and queue.kind == 'buy' and queue.stage == 'searchResult' then
                    sendResponse(id, 1, 0, q)
                    watchStep('searchResult', 'Товар не найден через поиск: ' .. item.name)
                end
            end)
            return true
        end
        queue.stage = 'searchResult'
        watchStep('searchResult', 'Товар не найден через поиск: ' .. item.name)
        sendResponse(id, 1, 0, q)
        return true
    end
    if queue.kind == 'buy' and isSearchResults(text, title, style) then
        if queue.stage == 'waitMain' then
            sendResponse(id, 0, 0, '')
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
            return true
        end
        local item = preset().buy[queue.index]
        if not item then stopWork('Скупка настроена') return true end
        local target = searchText(item.name)
        local targetNoBrackets = searchText(item.name:gsub('%s*%b()', ''))
        local matchRow = nil
        local fallbackRow = nil
        local row = 0
        for line in text:gmatch('[^\r\n]+') do
            local cleanLine = cleanName(utf(line))
            local extracted = cleanLine:match('^%s*%d+%.%s*(.+)$') or cleanLine:match('^%s*([^\t]+)')
            if extracted then
                extracted = extracted:match('^([^\t]+)') or extracted
                local extClean = searchText(extracted)
                local extNoBrackets = searchText(extracted:gsub('%s*%b()', ''))
                if extClean == target or (targetNoBrackets ~= '' and extNoBrackets == targetNoBrackets) then
                    matchRow = row
                    break
                elseif not fallbackRow and (extClean:find(target, 1, true) or (targetNoBrackets ~= '' and extClean:find(targetNoBrackets, 1, true))) then
                    fallbackRow = row
                end
            end
            row = row + 1
        end
        local chosen = matchRow or fallbackRow
        if chosen then
            queue.stage = 'buyInput'
            answer(id, chosen)
            watchStep('buyInput', 'Не удалось открыть ввод цены для товара')
        else
            sendResponse(id, 0, 0, '')
            local found = findBuy(item.name)
            if found then item.page, item.row = found.page, found.row end
            if item.page and item.row and not queue.fallback then
                queue.fallback = true
                queue.stage = 'waitMain'
                watchStep('waitMain', 'Не удалось вернуться в меню лавки')
            else
                notify('Не найден в поиске: ' .. item.name)
                advanceBuy()
            end
        end
        return true
    end
    if (queue.kind == 'sell' or queue.kind == 'buy') and isSinglePriceDialog(text) then
        local kind = queue.kind == 'sell' and 'sell' or 'buy'
        local item = preset()[kind][queue.index]
        if not item then
            sendResponse(id, 0, 0, '')
            stopWork(kind == 'sell' and 'Продажа завершена' or 'Скупка настроена')
            return true
        end
        answer(id, 0, tostring(item.price))
        if kind == 'sell' then
            local placed = 1
            if queue.slot then
                queue.taken = queue.taken or {}
                queue.taken[queue.slot] = (queue.taken[queue.slot] or 0) + placed
                local slotItem = inventory[1][queue.slot]
                local totalInSlot = slotItem and itemCount(slotItem) or placed
                if queue.taken[queue.slot] >= totalInSlot then
                    queue.usedSlots = queue.usedSlots or {}
                    queue.usedSlots[queue.slot] = true
                end
            end
            queue.count = (queue.count or 0) + 1
            queue.placedForItem = (queue.placedForItem or 0) + placed
            queue.actualAmount = nil
            queue.slotAmount = nil
            queue.retries = nil
            queue.actionRetries = nil
            if (queue.left or 1) > placed then
                queue.left = queue.left - placed
            else
                queue.left = nil
                queue.placedForItem = nil
                queue.index = nextSellIndex(queue.index + 1)
            end
            queue.stage = 'next'
            queue.stepStage = nil
            nextSell()
        else
            queue.count = (queue.count or 0) + 1
            advanceBuy()
        end
        return true
    end
    if (queue.kind == 'buy' or queue.kind == 'sell') and isAmountPriceDialog(text) then
        local kind = queue.kind == 'sell' and 'sell' or 'buy'
        local item = preset()[kind][queue.index]
        if not item then
            sendResponse(id, 0, 0, '')
            stopWork(kind == 'sell' and 'Продажа завершена' or 'Скупка настроена')
            return true
        end
        local amountToPlace = kind == 'sell' and (queue.actualAmount or item.amount) or (queue.remaining[queue.index] or item.amount)
        answer(id, 0, tostring(amountToPlace) .. ',' .. tostring(item.price))
        if kind == 'sell' then
            if queue.slot then
                queue.taken = queue.taken or {}
                queue.taken[queue.slot] = (queue.taken[queue.slot] or 0) + amountToPlace
                local slotItem = inventory[1][queue.slot]
                local totalInSlot = slotItem and itemCount(slotItem) or amountToPlace
                if queue.taken[queue.slot] >= totalInSlot then
                    queue.usedSlots = queue.usedSlots or {}
                    queue.usedSlots[queue.slot] = true
                end
            end
            queue.count = (queue.count or 0) + 1
            queue.placedForItem = (queue.placedForItem or 0) + amountToPlace
            queue.actualAmount = nil
            queue.slotAmount = nil
            queue.retries = nil
            queue.actionRetries = nil
            if (queue.left or 0) > amountToPlace then
                queue.left = queue.left - amountToPlace
            else
                queue.left = nil
                queue.placedForItem = nil
                queue.index = nextSellIndex(queue.index + 1)
            end
            queue.stage = 'next'
            queue.stepStage = nil
            nextSell()
        else
            queue.count = (queue.count or 0) + 1
            advanceBuy()
        end
        return true
    end
    if queue.kind == 'buy' and isBuyList(text, title) then
        if queue.stage == 'waitMain' then
            sendResponse(id, 0, 0, '')
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
            return true
        end
        local item = preset().buy[queue.index]
        if not item then stopWork('Скупка настроена') return true end
        local page = tonumber(title:match('(%d+)')) or 1
        queue.page = item.page
        queue.stage = 'buyInput'
        if page == item.page then
            answer(id, item.row)
            watchStep('buyInput', 'Не удалось открыть ввод цены для товара')
        else
            local rows = 0
            for _ in text:gmatch('[^\r\n]+') do rows = rows + 1 end
            answer(id, page < item.page and rows - 2 or rows - 3)
            watchStep('buyInput', 'Не удалось переключить страницу каталога')
        end
        return true
    end
    return false
end

function sampev.onCreateObject(objectId, data)
    if config.optimizer and (config.optimizerMode == 0 or config.optimizerMode == 1) then
        if getCharActiveInterior(PLAYER_PED) == 0 then
            if data and data.position and data.position.z > 900 then
                return
            end
            return false
        end
    end
end

function sampev.onSetPlayerAttachedObject(playerId, index, create, object)
    if config.optimizer and (config.optimizerMode == 0 or config.optimizerMode == 1) then
        local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if create and playerId ~= myId then
            return false
        end
    end
end

function sampev.onPlayerStreamIn(playerId, team, model, position, rotation, color, fightingStyle)
    if config.optimizer and (config.optimizerMode == 0 or config.optimizerMode == 2) then
        if isCustomSkinModel(model) then
            return {playerId, team, 1, position, rotation, color, fightingStyle}
        end
    end
end

function sampev.onSetPlayerSkin(playerId, skinId)
    if config.optimizer and (config.optimizerMode == 0 or config.optimizerMode == 2) then
        local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if playerId ~= myId and isCustomSkinModel(skinId) then
            return {playerId, 1}
        end
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    forceAltUntil = 0
    serverDialogOpen = true
    dialog = {id = id, style = style, title = title, text = text}
    local num = cleanName(utf(title)):match('№%s*(%d+)')
    if num then shopId = num end
    if isMain(text) then
        isMyLavka = true
        stealerWin[0] = false
        local clean = text:gsub('\r\n$', ''):gsub('\n$', '')
        local rows = 0
        for _ in clean:gmatch('[^\r\n]+') do rows = rows + 1 end
        local chromoRow = style == 2 and rows or (rows - 1)
        dialog.chromoRow = chromoRow
        mainDialog = {id = id, style = style, title = title, text = clean, chromoRow = chromoRow}
        if config.extended then
            dialog.presetRow = chromoRow + 1
            dialog.sellRow = chromoRow + 2
            dialog.buyRow = chromoRow + 3
            mainDialog.presetRow = dialog.presetRow
            mainDialog.sellRow = dialog.sellRow
            mainDialog.buyRow = dialog.buyRow
        end
    end
    if processQueue(id, title, text, style) then return false end
    if isMain(text) then
        local handled = false
        if queue and queue.kind == 'sell' and queue.stage == 'menu' then
            answer(id, 0)
            queue.stage = 'waitInv'
            watchStep('waitInv', 'Не удалось открыть инвентарь лавки', 0.4)
            handled = true
        elseif queue and queue.kind == 'buy' and (queue.stage == 'menu' or queue.stage == 'waitMain') then
            handled = true
            queue.stepStage = nil
            requestBuyItem(false)
        elseif queue and queue.kind == 'clearSell' then
            if (queue.count or 0) > 0 then
                stopWork('Товары сняты с продажи')
            elseif queue.stage == 'menu' then
                answer(id, 0)
                queue.stage = 'waitInv'
                watchStep('waitInv', 'Не удалось открыть продажу лавки', 0.35)
                handled = true
            end
        elseif queue and queue.kind == 'clearBuy' then
            if (queue.count or 0) > 0 then
                stopWork('Товары сняты со скупки')
            elseif queue.stage == 'menu' then
                answer(id, 3)
                queue.stage = 'waitInv'
                watchStep('waitInv', 'Не удалось открыть скупку лавки', 0.35)
                handled = true
            end
        elseif scan then
            answer(id, 1)
            handled = true
        end
        if handled then return false end

        text = mainDialogText()
        return {id, style, title, button1, button2, text}
    end
    if config.autoName and text:find(cp('Введите название вашей лавки'), 1, true) then
        local name = config.shopName ~= '' and config.shopName or 'chromo'
        answer(id, 0, cp(name):sub(1, 60))
        return false
    end
    if config.autoColor and title:find(cp('Выберите цвет'), 1, true) then
        local count = 0
        for _ in text:gmatch('[^\r\n]+') do count = count + 1 end
        local maxRow = math.max(0, count - 1)
        local chosenRow
        if (tonumber(config.shopColorIdx) or 0) > 0 then
            chosenRow = math.min(maxRow, tonumber(config.shopColorIdx) - 1)
        else
            chosenRow = math.random(0, maxRow)
        end
        answer(id, chosenRow)
        return false
    end
    if config.autoRent and (id == 3010 or text:find(cp('Стоимость аренды лавки'), 1, true)) then
        answer(id, 0, '')
        return false
    end
end

function sampev.onSendDialogResponse(id, button, list, input)
    local target = (dialog and dialog.id == id) and dialog or ((mainDialog and mainDialog.id == id) and mainDialog or nil)
    if target then
        if button == 0 then
            serverDialogOpen = false
            dialog = nil
            mainDialog = nil
            if queue or scan then
                queue = nil
                scan = nil
            end
            sampToggleCursor(false)
            return
        end
        if target.presetRow and button == 1 and list == target.presetRow then
            selectedPreset = selectedPreset % #config.presets + 1
            lua_thread.create(function()
                wait(50)
                if mainDialog then
                    sampShowDialog(mainDialog.id, mainDialog.title, mainDialogText(), cp('Выбрать'), cp('Закрыть'), mainDialog.style)
                end
            end)
            return false
        end
        if target.sellRow and button == 1 and list == target.sellRow then
            startSell()
            return false
        end
        if target.buyRow and button == 1 and list == target.buyRow then
            startBuy()
            return false
        end
        if target.chromoRow and button == 1 and list == target.chromoRow then
            window[0] = true
            lua_thread.create(function()
                wait(50)
                if mainDialog then
                    sampShowDialog(mainDialog.id, mainDialog.title, mainDialogText(), cp('Выбрать'), cp('Закрыть'), mainDialog.style)
                end
            end)
            return false
        end
    end
end

function sampev.onServerMessage(color, text)
    local message = utf(cleanName(text))
    if message:find('Поиск доступен раз в 1 сек', 1, true) then
        if queue and queue.kind == 'buy' then
            queue.retryCooldown = true
            watchStep(queue.stage, 'Ожидание поиска', 2.5)
        end
        return false
    end
    if (queue or scan) and (
        message:find('Вы не у лавки', 1, true) or
        message:find('у вас нет лавки', 1, true) or
        message:find('слишком далеко от вашей лавки', 1, true)
    ) then
        serverDialogOpen = false
        dialog = nil
        mainDialog = nil
        if sampIsDialogActive() then sampCloseCurrentDialogWithButton(0) end
        stopWork(message, true)
        return
    end
    if queue and queue.kind == 'buy' and (message:find('Вы уже скупаете выбранный предмет', 1, true) or message:find('уже скупаете', 1, true)) then
        local item = preset().buy[queue.index]
        notify('Уже скупается: ' .. (item and item.name or 'товар'))
        advanceBuy()
        if queue and dialog and (isSearchResults(dialog.text, dialog.title, dialog.style) or isSearchInput(dialog.text, dialog.title) or isBuyList(dialog.text, dialog.title)) then
            sendResponse(dialog.id, 0, 0, '')
        end
        return
    end
    if queue and (queue.kind == 'clearBuy' or queue.kind == 'clearSell') and (message:find('У вас нет выставленного товара', 1, true) or message:find('нет товаров', 1, true)) then
        if (queue.count or 0) > 0 then
            stopWork(queue.kind == 'clearSell' and 'Товары сняты с продажи' or 'Товары сняты со скупки')
        else
            stopWork(message, true)
        end
        return
    end
    if queue and queue.kind == 'buy' and queue.stage == 'searchResult' and (message:find('Предметов не найдено', 1, true) or message:find('не найден', 1, true) or message:find('Ничего не найдено', 1, true)) then
        local item = preset().buy[queue.index]
        local shortQ = item and searchQuery(item.name, true)
        if item and shortQ and queue.query ~= shortQ and not queue.triedShort then
            queue.triedShort = true
            queue.query = shortQ
            queue.retryCooldown = true
            if dialog and isSearchInput(dialog.text, dialog.title) then
                processQueue(dialog.id, dialog.title, dialog.text, dialog.style)
            end
            return
        end
        queue.triedShort = false
        local found = item and findBuy(item.name)
        if found then item.page, item.row = found.page, found.row end
        if item and item.page and item.row and not queue.fallback then
            queue.fallback = true
            queue.stage = 'waitMain'
            if dialog and isSearchInput(dialog.text, dialog.title) then
                sendResponse(dialog.id, 0, 0, '')
            end
            watchStep('waitMain', 'Не удалось вернуться в меню лавки')
        else
            notify('Не найден в лавке: ' .. (item and item.name or 'товар'))
            advanceBuy()
            if queue and dialog and isSearchInput(dialog.text, dialog.title) then
                sendResponse(dialog.id, 0, 0, '')
            end
        end
        return
    end
    if queue and (
        message:find('Вы не можете выставить стоимость товара', 1, true) or
        message:find('стоимость товара выше', 1, true) or
        message:find('стоимость товара ниже', 1, true) or
        message:find('Некорректная цена', 1, true) or
        message:find('Нельзя выставить', 1, true) or
        message:find('не можете выставить', 1, true)
    ) then
        if queue.kind == 'sell' then
            skipSellItem(message)
        elseif queue.kind == 'buy' then
            notify('Пропуск: ' .. message:gsub('^%[Ошибка%]%s*', ''))
            advanceBuy()
            if queue and dialog and (isSearchResults(dialog.text, dialog.title, dialog.style) or isSearchInput(dialog.text, dialog.title) or isBuyList(dialog.text, dialog.title)) then
                sendResponse(dialog.id, 0, 0, '')
            end
        end
        return
    end
    if (queue or scan) and (
        message:find('недостаточно денег', 1, true) or
        message:find('лимит стоимости', 1, true) or
        message:find('нет свободных слотов', 1, true)
    ) then
        stopWork(message, true)
        return
    end
    if queue and (queue.kind == 'clearBuy' or queue.kind == 'clearSell') and queue.stage == 'clearConfirm' and (message:find('сняли', 1, true) or message:find('прекратили', 1, true) or message:find('убрали', 1, true)) then
        if queue.slot and queue.itemType and inventory[queue.itemType] then
            inventory[queue.itemType][queue.slot] = nil
        end
        queue.count = (queue.count or 0) + 1
        queue.stage = 'wait'
        queue.stepStage = nil
        if queue.kind == 'clearSell' then nextClearSell() else nextClearBuy() end
        return
    end
    local kind
    if message:find('купил у вас', 1, true) and message:find('вы получили', 1, true) then kind = 'sell'
    elseif message:find('Вы купили', 1, true) and message:find('у игрока', 1, true) then kind = 'buy' end
    if kind then
        if kind == 'buy' then updateBuyProgress(message) end
        if kind == 'sell' then
            updateSellProgress(message)
            message = message:gsub('%s*%(комиссия.*$', '')
        end
        local entries = config.logs[kind]
        entries[#entries + 1] = {time = os.time(), text = message}
        if #entries > 500 then table.remove(entries, 1) end
        save()
    end
end

local function inventoryEvent(text)
    local first = text:find('[%[{]')
    local last = text:match('^.*()[%]}]')
    if not first or not last then return end
    local ok, packets = pcall(json.decode, text:sub(first, last))
    if not ok or type(packets) ~= 'table' then return end
    for _, packet in ipairs(packets) do
        local data = packet.data
        if data and packet.action == 1 and data.name then
            local title = utf(tostring(data.name))
            if title:find('Торговая лавка', 1, true) or title:find('лавка', 1, true) then
                isMyLavka = checkOwnerByTitle(title)
                if isMyLavka then
                    stealerWin[0] = false
                elseif lavkaOpen and config.itemStealer and not queue then
                    stealerWin[0] = true
                end
            end
        end
        if data and packet.action == 3 and data.item and data.item.id then
            if data.item.name then rememberItem(data.item.id, data.item.name) end
            local slot = tonumber(data.slot)
            local invType = tonumber(data.type)
            local realAmt = tonumber(data.item.amount) or tonumber(data.amount)
            if invType and slot and inventory[invType] and inventory[invType][slot] and realAmt and realAmt > 0 then
                inventory[invType][slot].amount = realAmt
            end
            local bits = tonumber(data.bits) or 0
            local canAct = bit.band(bits, 131072) ~= 0
            if invType == 1 then
                config.sellable[tostring(data.item.id)] = canAct
                save()
            end
            if queue and (queue.stage == 'itemInfo' or queue.stage == 'clearItemInfo') and slot == tonumber(queue.slot) and invType == tonumber(queue.itemType) then
                if not canAct and queue.stage == 'itemInfo' then
                    if queue.slot then
                        queue.usedSlots = queue.usedSlots or {}
                        queue.usedSlots[queue.slot] = true
                    end
                    skipSellItem('Предмет нельзя выставить: ' .. itemName(data.item.id))
                    return
                end
                if queue.stage == 'itemInfo' and inventory[1][slot] then
                    local avail = itemCount(inventory[1][slot]) - (queue.taken and queue.taken[slot] or 0)
                    if avail > 0 then
                        queue.slotAmount = avail
                        queue.actualAmount = math.min(queue.left or avail, avail)
                    end
                end
                local stage = queue.stage
                local actionBit = canAct and 131072 or (bits > 0 and bits or 131072)
                queue.lastActionBit = actionBit
                sendCef('clickOnButton', json.encode({type = queue.itemType, slot = queue.slot, action = actionBit}))
                queue.stage = stage == 'itemInfo' and 'price' or 'clearConfirm'
                watchStep(queue.stage, stage == 'itemInfo' and 'Сервер не открыл окно ввода цены' or 'Сервер не подтвердил снятие товара', 0.8)
            end
        end
        if data and (packet.action == 0 or packet.action == 2) and (data.type == 1 or data.type == 13 or data.type == 28) then
            local now = os.clock()
            if packet.action == 0 and (data.type == 13 or data.type == 28) then
                local firstItem = data.items and data.items[1]
                if (firstItem and tonumber(firstItem.slot) == 0) or not lastLavkaPacket[data.type] or (now - lastLavkaPacket[data.type] > 1.2) then
                    inventory[data.type] = {}
                end
                lastLavkaPacket[data.type] = now
            end
            local inv = inventory[data.type]
            for _, item in ipairs(data.items or {}) do
                local slot = tonumber(item.slot)
                if slot then
                    if not item.item or tonumber(item.item) == 0 then
                        inv[slot] = nil
                    else
                        local old = inv[slot] or {}
                        if old.item and tonumber(old.item) ~= tonumber(item.item) then
                            old = {}
                        end
                        for key, value in pairs(item) do
                            if key == 'amount' then
                                if tonumber(value) and tonumber(value) > 0 then old.amount = tonumber(value) end
                            elseif key == 'text' then
                                if tostring(value) ~= '' then old.text = value end
                            else
                                old[key] = value
                            end
                        end
                        inv[slot] = old
                        if item.name then rememberItem(item.item, item.name) end
                    end
                end
            end
            save()
            if queue and (queue.kind == 'clearSell' or queue.kind == 'clearBuy') and queue.stage == 'clearConfirm' and data.type == queue.itemType and queue.slot and not inv[queue.slot] then
                queue.count = (queue.count or 0) + 1
                queue.stage = 'wait'
                queue.stepStage = nil
                if queue.kind == 'clearSell' then nextClearSell() else nextClearBuy() end
            elseif queue and queue.stage == 'waitInv' then
                if queue.kind == 'sell' and data.type == 1 then
                    queue.stepStage = nil
                    nextSell()
                elseif queue.kind == 'clearSell' and data.type == 13 and #sortedItems('clearSell') > 0 then
                    queue.stepStage = nil
                    nextClearSell()
                elseif queue.kind == 'clearBuy' and data.type == 28 and #sortedItems('clearBuy') > 0 then
                    queue.stepStage = nil
                    nextClearBuy()
                end
            end
        end
    end
end

function onSendPacket(id, bs)
    if id ~= 220 and id ~= -36 then return end
    if raknetBitStreamGetNumberOfBytesUsed(bs) < 5 then return end
    raknetBitStreamResetReadPointer(bs)
    raknetBitStreamReadInt8(bs)
    local subId = raknetBitStreamReadInt8(bs)
    if subId ~= 18 then
        raknetBitStreamResetReadPointer(bs)
        return
    end
    local len = raknetBitStreamReadInt16(bs)
    if len <= 0 or len > 32768 then
        raknetBitStreamResetReadPointer(bs)
        return
    end
    local ok, text = pcall(raknetBitStreamReadString, bs, len)
    raknetBitStreamResetReadPointer(bs)
    if not ok or type(text) ~= 'string' then return end

    if text:find('updateCategory', 1, true) then
        local cat = tonumber(text:match('"category"%s*:%s*(%d+)'))
        if cat == 0 then lavkaCategory = 13
        elseif cat == 1 then lavkaCategory = 28 end
    elseif text:find('inventoryClose', 1, true) then
        lavkaOpen = false
        isMyLavka = false
        stealerWin[0] = false
    elseif text:find('onActiveViewChanged', 1, true) and text:find('null', 1, true) then
        lavkaOpen = false
        isMyLavka = false
        stealerWin[0] = false
    end
end

function onReceivePacket(id, bs)
    if id ~= 220 and id ~= -36 then return end
    if raknetBitStreamGetNumberOfBytesUsed(bs) < 9 then return end
    raknetBitStreamResetReadPointer(bs)
    raknetBitStreamReadInt8(bs)
    if raknetBitStreamReadInt8(bs) ~= 17 then
        raknetBitStreamResetReadPointer(bs)
        return
    end
    browser = raknetBitStreamReadInt32(bs)
    local size = raknetBitStreamReadInt16(bs)
    local encoded = raknetBitStreamReadInt8(bs)
    if size <= 0 or size > 65535 then
        raknetBitStreamResetReadPointer(bs)
        return
    end
    local ok, text = pcall(function()
        return encoded ~= 0 and raknetBitStreamDecodeString(bs, size + encoded) or raknetBitStreamReadString(bs, size)
    end)
    raknetBitStreamResetReadPointer(bs)
    if not ok or type(text) ~= 'string' then return end
    if text:find('event.inventory.playerInventory', 1, true) then inventoryEvent(text) end
    if text:find('event.inventory.setLavkaVisible', 1, true) then
        local state = text:find('true', 1, true) ~= nil
        lavkaOpen = state
        if state then
            if next(inventory[13]) ~= nil then lavkaCategory = 13
            elseif next(inventory[28]) ~= nil then lavkaCategory = 28
            else lavkaCategory = 13 end
            if config.itemStealer and not queue and not isMyLavka then
                stealerWin[0] = true
            end
        else
            isMyLavka = false
            inventory[13] = {}
            inventory[28] = {}
            stealerWin[0] = false
        end
    elseif text:find('event.setActiveView', 1, true) and text:find('null', 1, true) then
        lavkaOpen = false
        isMyLavka = false
        stealerWin[0] = false
    end
    if text:find('event.player.updateMoney', 1, true) then
        playerMoney = tonumber(text:match('%[(%d+)%]')) or playerMoney
    end
end

local function editItem(kind, index, source)
    local item = index and preset()[kind][index]
    editor.active = true
    editor.kind = kind
    editor.index = index
    editor.source = source
    editor.id[0] = item and tonumber(item.id) or source and tonumber(source.item) or 0
    editor.amount[0] = item and item.amount or 1
    editor.price[0] = item and item.price or 0
    editor.name = item and (item.name or itemName(item.id)) or source and itemName(source.item) or ''
    editor.page = item and item.page
    editor.row = item and item.row
end

local function saveEditor()
    if editor.price[0] <= 0 or editor.amount[0] <= 0 then return end
    local list = preset()[editor.kind]
    local previous = editor.index and list[editor.index]
    local item = {amount = editor.amount[0], price = editor.price[0], enabled = not previous or previous.enabled ~= false, selected = previous and previous.selected}
    if editor.kind == 'sell' then
        item.id = editor.id[0] > 0 and editor.id[0] or (previous and previous.id) or findItemIdByName(editor.name)
        item.name = editor.name ~= '' and editor.name or (previous and previous.name) or (item.id and itemName(item.id)) or nil
        if not editor.index then
            local available = 0
            for _, stocked in ipairs(sortedItems('sell')) do
                if tonumber(stocked.item) == tonumber(item.id) then available = available + itemCount(stocked) end
            end
            if available == 0 then notify('Предмет закончился в инвентаре') return end
            if item.amount > available then notify('У вас только ' .. available .. ' шт.') return end
        end
    else
        local found = findBuy(editor.name)
        item.name = editor.name
        item.id = (previous and previous.id) or findItemIdByName(editor.name)
        if found then item.page, item.row = found.page, found.row end
    end
    if editor.index then
        list[editor.index] = item
        groupIdenticalItems(list, editor.kind)
    else
        insertGrouped(list, item, editor.kind)
    end
    save()
    editor.active = false
end

local function listItems(kind)
    local list = preset()[kind]
    local filter = searchText(ffi.string(listSearch))
    local duplicates = {}
    for index, item in ipairs(list) do
        for other = 1, index - 1 do
            if sameItem(item, list[other], kind) then duplicates[index] = true duplicates[other] = true break end
        end
    end
    for index, item in ipairs(list) do
        local name = kind == 'sell' and itemName(item.id, item.name) or item.name or '?'
        if filter == '' or searchText(name):find(filter, 1, true) then
            imgui.PushIDInt(index)
            checkState[0] = item.enabled ~= false
            if imgui.Checkbox('##enabled', checkState) then item.enabled = checkState[0] save() end
            imgui.SameLine()
            if kind == 'sell' then
                local have = getInventoryStockCount(item)
                local wantedAmt = tonumber(item.amount) or 1
                if have < wantedAmt then
                    imgui.TextColored(imgui.ImVec4(1.0, 0.33, 0.33, 1.0), faicons('triangle_exclamation'))
                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                        if have > 0 then
                            imgui.Text(string.format('У вас найдено всего %d шт. данного предмета.', have))
                            imgui.Text(string.format('Если вы не поправите, скрипт выставит максимально возможное число (%d шт.).', have))
                        else
                            imgui.Text('У вас найдено всего 0 шт. данного предмета в инвентаре.')
                            imgui.Text('Если предмет не появится в инвентаре, скрипт пропустит его при выставлении.')
                        end
                        imgui.EndTooltip()
                    end
                    imgui.SameLine()
                end
            end
            if duplicates[index] then
                local selectedIndex
                for i, other in ipairs(list) do
                    if sameItem(item, other, kind) then
                        if other.selected then selectedIndex = i break end
                        if not selectedIndex then selectedIndex = i end
                    end
                end
                if imgui.RadioButtonBool('##selected', selectedIndex == index) then
                    for _, other in ipairs(list) do if sameItem(item, other, kind) then other.selected = false end end
                    item.selected = true
                    save()
                end
                imgui.SameLine()
            end
            imgui.Text(string.format('%s  x%d', name, item.amount or 1))
            imgui.SameLine()
            drawMoney(item.price)
            imgui.SameLine()
            if kind == 'buy' then
                if iconButton('arrow_left', '##toSell', imgui.ImVec2(25, 23)) then
                    local ok, newPrice = transferSingleBuyToSell(item)
                    if ok then
                        local pct = tonumber(config.markup) or 20
                        local pctStr = pct % 1 == 0 and string.format('%d%%', pct) or string.format('%.1f%%', pct)
                        notify(string.format('Перенесено в продажу (+%s): %s x%d за %s', pctStr, name, item.amount or 1, money(newPrice)))
                    end
                end
                if imgui.IsItemHovered() then
                    local pct = tonumber(config.markup) or 20
                    local pctStr = pct % 1 == 0 and string.format('%d%%', pct) or string.format('%.1f%%', pct)
                    imgui.SetTooltip('Перенести этот товар в продажу с наценкой +' .. pctStr)
                end
                imgui.SameLine()
            end
            if iconButton('arrow_up', '##up', imgui.ImVec2(25, 23)) and index > 1 then list[index - 1], list[index] = list[index], list[index - 1] save() end
            imgui.SameLine()
            if iconButton('arrow_down', '##down', imgui.ImVec2(25, 23)) and index < #list then list[index + 1], list[index] = list[index], list[index + 1] save() end
            imgui.SameLine()
            if iconButton('pen', '##edit', imgui.ImVec2(25, 23)) then editItem(kind, index) end
            imgui.SameLine()
            if iconButton('xmark', '##delete', imgui.ImVec2(25, 23)) then table.remove(list, index) save() imgui.PopID() break end
            imgui.PopID()
        end
    end
end

local function picker()
    imgui.SetNextWindowSize(imgui.ImVec2(390, 360), imgui.Cond.Always)
    if imgui.BeginPopup('Добавить##chromo') then
        imgui.SetNextItemWidth(-1)
        imgui.InputTextWithHint('##pickerSearch', faicons('magnifying_glass') .. '  Поиск по названию', pickerSearch, 128)
        imgui.Separator()
        imgui.BeginChild('##pickerItems', imgui.ImVec2(0, 0), false)
        local query = searchText(ffi.string(pickerSearch))
        if tab == 1 then
            local count = 0
            for _, item in ipairs(sortedItems('sell')) do
                if config.sellable[tostring(item.item)] ~= false and (query == '' or searchText(itemName(item.item)):find(query, 1, true)) then
                    count = count + 1
                    imgui.PushIDInt(item.slot)
                    local cnt = itemCount(item)
                    local detail = item.text and tostring(item.text) or ''
                    if detail == '' or detail == tostring(cnt) then detail = '' else detail = '    ' .. detail end
                    if imgui.Selectable(string.format('%s    x%d%s', itemName(item.item), cnt, detail)) then
                        editItem('sell', nil, item)
                    end
                    imgui.PopID()
                end
            end
            if count == 0 then imgui.TextDisabled('Нет доступных предметов') end
        else
            local keys = {}
            for key in pairs(buyCatalog) do keys[#keys + 1] = key end
            table.sort(keys, function(a, b) return buyCatalog[a].name < buyCatalog[b].name end)
            for _, key in ipairs(keys) do
                local item = buyCatalog[key]
                if not item.name:upper():find('DELETED', 1, true) and (query == '' or searchText(item.name):find(query, 1, true)) then
                    if imgui.Selectable(item.name .. '##' .. key) then
                        editor.active = true
                        editor.kind = 'buy'
                        editor.index = nil
                        editor.name = item.name
                        editor.page = item.page
                        editor.row = item.row
                        editor.amount[0] = 1
                        editor.price[0] = 0
                    end
                end
            end
            if #keys == 0 then imgui.TextDisabled('Сначала обновите список') end
        end
        imgui.EndChild()
        imgui.EndPopup()
    end
end

local function drawEditor()
    if not editor.active then return end
    imgui.OpenPopup('Товар##chromo')
    if imgui.BeginPopupModal('Товар##chromo', nil, imgui.WindowFlags.AlwaysAutoResize) then
        imgui.Text(editor.name ~= '' and editor.name or itemName(editor.id[0]))
        imgui.SetNextItemWidth(180)
        imgui.InputInt('Количество', editor.amount)
        imgui.SetNextItemWidth(180)
        imgui.InputInt(editor.kind == 'sell' and 'Цена за шт.' or 'Цена скупки', editor.price)
        if imgui.Button('Сохранить', imgui.ImVec2(90, 0)) then saveEditor() end
        imgui.SameLine()
        if imgui.Button('Отмена', imgui.ImVec2(90, 0)) then editor.active = false end
        imgui.EndPopup()
    end
end

local function drawSettingsTab()
    imgui.Spacing()
    imgui.SetNextItemWidth(220)
    imgui.InputTextWithHint('##newpreset', 'Новый пресет', newPreset, 64)
    imgui.SameLine()
    if iconButton('plus', '##addPreset') and ffi.string(newPreset) ~= '' then
        config.presets[#config.presets + 1] = {name = ffi.string(newPreset), sell = {}, buy = {}}
        selectedPreset = #config.presets
        ffi.copy(newPreset, '')
        save()
    end
    imgui.SetNextItemWidth(120)
    if imgui.InputFloat('Комиссия продажи (%)', commission, 1, 5, '%.1f') then applySettings() end
    imgui.SetNextItemWidth(120)
    if imgui.InputFloat('Наценка (%)', markup, 1, 5, '%.1f') then applySettings() end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Процент наценки при переносе товаров из скупки в продажу.')
    end
    if imgui.Checkbox('Автопринятие аренды лавки', autoRent) then applySettings() end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Автоматически нажимает "Принять" в окне стоимости аренды лавки.')
    end
    if imgui.Checkbox('Автоматически устанавливать название', autoName) then applySettings() end
    if autoName[0] then
        imgui.SameLine()
        imgui.PushItemWidth(150)
        if imgui.InputTextWithHint('##shopName', 'Название лавки', shopName, 64) then applySettings() end
        imgui.PopItemWidth()
    end
    if imgui.Checkbox('Автоматический цвет лавки', autoColor) then applySettings() end
    if autoColor[0] then
        imgui.SameLine()
        local currentColorEntry = shopColors[shopColorIdx[0] + 1] or shopColors[1]
        imgui.SetNextItemWidth(210)
        imgui.PushStyleColor(imgui.Col.Text, currentColorEntry.col)
        if imgui.BeginCombo('##shopColorCombo', currentColorEntry.name) then
            for i, entry in ipairs(shopColors) do
                imgui.PushStyleColor(imgui.Col.Text, entry.col)
                if imgui.Selectable(entry.name .. '##col_' .. i, shopColorIdx[0] == (i - 1)) then
                    shopColorIdx[0] = i - 1
                    applySettings()
                end
                imgui.PopStyleColor()
            end
            imgui.EndCombo()
        end
        imgui.PopStyleColor()
    end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Автоматически выбирает указанный или случайный цвет названия лавки.')
    end
    if imgui.Checkbox('Калькулятор', calcEnabled) then applySettings() end
    if calcEnabled[0] then
        imgui.SameLine()
        local bindLabel = bindingKey and 'Нажмите клавиши...' or hotkeyToString(config.calcHotkey)
        if imgui.Button(bindLabel .. '##calcBindBtn', imgui.ImVec2(190, 24)) then
            bindingKey = true
        end
        if imgui.IsItemHovered() then
            imgui.SetTooltip('Нажмите для смены комбинации клавиш открытия калькулятора.')
        end
    end
    if imgui.Checkbox('Оптимайзер', optimizer) then applySettings() end
    if optimizer[0] then
        imgui.SameLine()
        imgui.SetNextItemWidth(245)
        local currentOptMode = optimizerModes[optimizerMode[0] + 1] or optimizerModes[1]
        if imgui.BeginCombo('##optimizerModeCombo', currentOptMode) then
            for i, modeName in ipairs(optimizerModes) do
                if imgui.Selectable(modeName .. '##opt_' .. i, optimizerMode[0] == (i - 1)) then
                    optimizerMode[0] = i - 1
                    applySettings()
                end
            end
            imgui.EndCombo()
        end
    end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text('Повышает FPS в людных местах:')
        imgui.Text('Удаляет серверные объекты')
        imgui.Text('Заменяет кастомные лаунчерские скины игроков')
        imgui.EndTooltip()
    end
    if imgui.Checkbox('Показывать зоны установки лавок', showZones) then applySettings() end
    if imgui.Checkbox('VC Курс', vcCourse) then applySettings() end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Показывает рядом сумму в деньгах твоего сервера.\nРаботает только на Vice City.')
    end
    if vcCourse[0] then
        imgui.SameLine()
        imgui.PushItemWidth(120)
        if imgui.InputInt('##vcRate', vcRate) then applySettings() end
        imgui.PopItemWidth()
    end
    if imgui.Checkbox('Расширенный Chromo', extended) then applySettings() end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text('Добавляет в диалог лавки выбор пресета')
        imgui.Text('и кнопки запуска продажи и скупки.')
        imgui.EndTooltip()
    end
    if imgui.Checkbox('Стиллер товаров', itemStealer) then applySettings() end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Открывает окно копирования всех или отдельных товаров\nв твой конфиг при просмотре чужих лавок.')
    end
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    if actionButton('paper_plane', 'Перейти в телеграм', '##tgLinkBtn', imgui.ImVec2(imgui.GetContentRegionAvail().x, 28), false) then
        imgui.SetClipboardText('https://t.me/chromo2')
        shell32.ShellExecuteA(nil, 'open', 'https://t.me/chromo2', nil, nil, 1)
    end

    if actionButton('globe', 'Профиль автора BlastHack', '##bhLinkBtn', imgui.ImVec2(imgui.GetContentRegionAvail().x, 28), false) then
        imgui.SetClipboardText('https://www.blast.hk/members/496666/')
        shell32.ShellExecuteA(nil, 'open', 'https://www.blast.hk/members/496666/', nil, nil, 1)
    end

    imgui.Spacing()
    local authorLabel = 'Автор скрипта: '
    local authorName = 'Kermi'
    local totalW = imgui.CalcTextSize(authorLabel).x + imgui.CalcTextSize(authorName).x
    centerRow(totalW)
    imgui.TextDisabled(authorLabel)
    imgui.SameLine(0, 0)
    imgui.TextColored(imgui.ImVec4(0.36, 0.78, 0.80, 1), authorName)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local font = imgui.ImFontConfig()
    font.MergeMode = true
    font.PixelSnapH = true
    local ranges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('regular'), 13, font, ranges)
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(6, 4)
    style.ItemSpacing = imgui.ImVec2(6, 5)
    style.ItemInnerSpacing = imgui.ImVec2(5, 4)
    style.WindowRounding = 3
    style.ChildRounding = 2
    style.FrameRounding = 2
    style.PopupRounding = 2
    style.ScrollbarRounding = 2
    style.GrabRounding = 2
    style.TabRounding = 2
    style.WindowBorderSize = 1
    style.FrameBorderSize = 0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ScrollbarSize = 12
    local colors = style.Colors
    local palette = {
        Text = {0.91, 0.93, 0.96, 1}, TextDisabled = {0.46, 0.50, 0.55, 1},
        WindowBg = {0.055, 0.065, 0.080, 0.98}, ChildBg = {0.070, 0.082, 0.100, 0.72}, PopupBg = {0.065, 0.076, 0.094, 0.99},
        Border = {0.20, 0.25, 0.31, 0.65}, BorderShadow = {0, 0, 0, 0},
        FrameBg = {0.10, 0.12, 0.15, 1}, FrameBgHovered = {0.14, 0.18, 0.22, 1}, FrameBgActive = {0.16, 0.22, 0.27, 1},
        TitleBg = {0.045, 0.055, 0.070, 1}, TitleBgActive = {0.045, 0.055, 0.070, 1}, TitleBgCollapsed = {0.045, 0.055, 0.070, 1},
        MenuBarBg = {0.07, 0.08, 0.10, 1}, ScrollbarBg = {0.05, 0.06, 0.075, 0.7},
        ScrollbarGrab = {0.22, 0.27, 0.32, 1}, ScrollbarGrabHovered = {0.28, 0.35, 0.41, 1}, ScrollbarGrabActive = {0.31, 0.55, 0.62, 1},
        CheckMark = {0.30, 0.76, 0.79, 1}, SliderGrab = {0.27, 0.61, 0.66, 1}, SliderGrabActive = {0.35, 0.82, 0.84, 1},
        Button = {0.12, 0.16, 0.20, 1}, ButtonHovered = {0.17, 0.28, 0.34, 1}, ButtonActive = {0.20, 0.48, 0.53, 1},
        Header = {0.12, 0.17, 0.21, 1}, HeaderHovered = {0.17, 0.29, 0.35, 1}, HeaderActive = {0.20, 0.47, 0.52, 1},
        Separator = {0.20, 0.25, 0.31, 0.65}, SeparatorHovered = {0.24, 0.55, 0.60, 1}, SeparatorActive = {0.30, 0.72, 0.76, 1},
        ResizeGrip = {0.20, 0.48, 0.53, 0.3}, ResizeGripHovered = {0.25, 0.63, 0.67, 0.7}, ResizeGripActive = {0.32, 0.77, 0.80, 1},
        Tab = {0.10, 0.13, 0.17, 1}, TabHovered = {0.17, 0.29, 0.35, 1}, TabActive = {0.17, 0.35, 0.40, 1},
        TabUnfocused = {0.08, 0.10, 0.13, 1}, TabUnfocusedActive = {0.12, 0.20, 0.24, 1},
        PlotLines = {0.30, 0.72, 0.76, 1}, PlotLinesHovered = {0.38, 0.85, 0.87, 1}, PlotHistogram = {0.30, 0.72, 0.76, 1}, PlotHistogramHovered = {0.38, 0.85, 0.87, 1},
        TableHeaderBg = {0.10, 0.14, 0.18, 1}, TableBorderStrong = {0.20, 0.25, 0.31, 1}, TableBorderLight = {0.15, 0.19, 0.24, 1},
        TableRowBg = {0, 0, 0, 0}, TableRowBgAlt = {1, 1, 1, 0.025}, TextSelectedBg = {0.24, 0.60, 0.65, 0.35},
        DragDropTarget = {0.35, 0.82, 0.84, 1}, NavHighlight = {0.30, 0.72, 0.76, 1}, NavWindowingHighlight = {1, 1, 1, 0.7},
        NavWindowingDimBg = {0.05, 0.06, 0.08, 0.6}, ModalWindowDimBg = {0.02, 0.025, 0.035, 0.72}
    }
    for name, color in pairs(palette) do
        pcall(function() colors[imgui.Col[name]] = imgui.ImVec4(color[1], color[2], color[3], color[4]) end)
    end
end)

local stealerPosApplied = false

local stealerFrame = imgui.OnFrame(function()
    return stealerWin[0] and config.itemStealer and lavkaOpen and not isMyLavka and not queue
end, function(self)
    self.HideCursor = false
    local display = imgui.GetIO().DisplaySize

    local hasSell = next(inventory[13]) ~= nil
    local hasBuy = next(inventory[28]) ~= nil
    if lavkaCategory == 13 and not hasSell and hasBuy then lavkaCategory = 28
    elseif lavkaCategory == 28 and not hasBuy and hasSell then lavkaCategory = 13 end

    local items = groupedLavkaItems(lavkaCategory)
    local query = searchText(ffi.string(stealerSearch))
    local maxW = 360
    for _, entry in ipairs(items) do
        local name = itemName(entry.id)
        if query == '' or searchText(name):find(query, 1, true) then
            local label = string.format('%s  x%d', name, entry.amount)
            local rowW = 24 + imgui.CalcTextSize(label).x + moneyWidth(entry.price) + 64
            if rowW > maxW then maxW = rowW end
        end
    end
    local winW = math.min(maxW, 680)

    if not stealerPosApplied then
        local startX = tonumber(config.stealerX) or (display.x - winW - 15)
        local startY = tonumber(config.stealerY) or (display.y / 2 - 215)
        startX = math.max(0, math.min(display.x - winW, startX))
        startY = math.max(0, math.min(display.y - 430, startY))
        imgui.SetNextWindowPos(imgui.ImVec2(startX, startY), imgui.Cond.Always)
        stealerPosApplied = true
    end

    imgui.SetNextWindowSize(imgui.ImVec2(winW, 430), imgui.Cond.Always)
    imgui.Begin('Стиллер товаров##chromoStealer', stealerWin, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)

    local pos = imgui.GetWindowPos()
    local curX, curY = math.floor(pos.x), math.floor(pos.y)
    if config.stealerX ~= curX or config.stealerY ~= curY then
        config.stealerX = curX
        config.stealerY = curY
        save()
    end

    local p = preset()
    local iconW = imgui.CalcTextSize(faicons('circle_question')).x + imgui.GetStyle().ItemSpacing.x
    imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x - iconW)
    if imgui.BeginCombo('##stealerPreset', p.name) then
        for i, item in ipairs(config.presets) do
            if imgui.Selectable(item.name .. '##' .. i, i == selectedPreset) then selectedPreset = i end
        end
        imgui.EndCombo()
    end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text('Это ваш текущий пресет, вы можете быстро переключаться между ними.')
        imgui.Text('Создать новый пресет можно в настройках.')
        imgui.EndTooltip()
    end

    local halfW = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
    local sellColor = lavkaCategory == 13 and 0xFF57572E or 0xFF22262A
    local buyColor = lavkaCategory == 28 and 0xFF57572E or 0xFF22262A
    if actionButton('tags', 'Продажа лавки', '##stTabSell', imgui.ImVec2(halfW, 26), not hasSell, sellColor) then
        lavkaCategory = 13
        sendCef('updateCategory', '{"category":0}')
    end
    imgui.SameLine()
    if actionButton('cart_shopping', 'Скупка лавки', '##stTabBuy', imgui.ImVec2(halfW, 26), not hasBuy, buyColor) then
        lavkaCategory = 28
        sendCef('updateCategory', '{"category":1}')
    end

    local copyLabel = lavkaCategory == 13 and ('Копировать всё в продажу (' .. #items .. ')') or ('Копировать всё в скупку (' .. #items .. ')')
    if actionButton('copy', copyLabel, '##copyAllLavka', imgui.ImVec2(imgui.GetContentRegionAvail().x, 27), #items == 0) then
        copyAllLavkaItems(lavkaCategory)
    end

    imgui.SetNextItemWidth(-1)
    imgui.InputTextWithHint('##stealerSearch', faicons('magnifying_glass') .. '  Поиск товара в лавке', stealerSearch, 128)
    imgui.Separator()

    imgui.BeginChild('##stealerList', imgui.ImVec2(0, 0), true)
    local shown = 0
    for idx, entry in ipairs(items) do
        local name = itemName(entry.id)
        if query == '' or searchText(name):find(query, 1, true) then
            shown = shown + 1
            imgui.PushIDInt(idx)
            if iconButton('plus', '##copyOne', imgui.ImVec2(24, 22)) then
                copySingleLavkaItem(lavkaCategory, entry)
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(lavkaCategory == 13 and 'Скопировать в твою продажу' or 'Скопировать в твою скупку')
            end
            imgui.SameLine()
            imgui.Text(string.format('%s  x%d', name, entry.amount))
            imgui.SameLine()
            drawMoney(entry.price)
            imgui.PopID()
        end
    end
    if shown == 0 then
        imgui.TextDisabled(#items == 0 and 'В этой вкладке нет товаров' or 'Ничего не найдено')
    end
    imgui.EndChild()

    imgui.End()
end)

local calcFrame = imgui.OnFrame(function()
    return calcWin[0] and config.calcEnabled
end, function(self)
    self.HideCursor = false
    local display = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(display.x / 2, display.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(290, 275), imgui.Cond.Always)
    imgui.Begin(faicons('calculator') .. '  Калькулятор##chromoCalc', calcWin, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    local expr = ffi.string(calcInput)
    local liveRes = evalCalcExpression(expr)

    if calcFocusInput then
        imgui.SetKeyboardFocusHere()
        calcFocusInput = false
    end
    imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x - 32)
    local entered = imgui.InputTextWithHint('##calcExpr', 'Пример', calcInput, 256, imgui.InputTextFlags.EnterReturnsTrue)
    imgui.SameLine()
    if iconButton('trash', '##calcClear', imgui.ImVec2(26, 24)) then
        ffi.copy(calcInput, '')
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Очистить поле') end

    local resDisplay = liveRes and ('= ' .. formatCalcNumber(liveRes)) or (expr == '' and '= 0' or '= ...')
    imgui.TextColored(liveRes and imgui.ImVec4(0.36, 0.78, 0.80, 1) or imgui.ImVec4(0.5, 0.54, 0.58, 1), resDisplay)
    if liveRes then
        imgui.SameLine(imgui.GetWindowWidth() - 36)
        if iconButton('copy', '##calcCopyRes', imgui.ImVec2(26, 22)) then
            local rawStr = tostring(math.floor(liveRes + 0.5))
            imgui.SetClipboardText(rawStr)
            notify('Скопировано')
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Скопировать результат') end
    end

    local function appendCalc(str)
        local cur = ffi.string(calcInput)
        ffi.copy(calcInput, (cur .. str):sub(1, 250))
    end

    local function commitCalc()
        if liveRes then
            local formatted = formatCalcNumber(liveRes)
            calcHistory[#calcHistory + 1] = {expr = expr, res = formatted, raw = tostring(math.floor(liveRes + 0.5))}
            if #calcHistory > 25 then table.remove(calcHistory, 1) end
            ffi.copy(calcInput, tostring(math.floor(liveRes * 100 + 0.5) / 100))
        end
    end

    if entered then commitCalc() end

    imgui.Separator()
    local btnW = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * 3) / 4
    local btnH = 29
    local rows = {
        {'C', '(', ')', '/'},
        {'7', '8', '9', '*'},
        {'4', '5', '6', '-'},
        {'1', '2', '3', '+'},
        {'0', '000', '.', '='}
    }
    for rIdx, row in ipairs(rows) do
        for cIdx, key in ipairs(row) do
            if cIdx > 1 then imgui.SameLine() end
            local isEq = key == '='
            local isClear = key == 'C'
            if isEq then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.48, 0.53, 1))
            elseif isClear then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.18, 0.20, 1))
            end
            if imgui.Button(key .. '##calcBtn_' .. rIdx .. '_' .. cIdx, imgui.ImVec2(btnW, btnH)) then
                if isClear then
                    ffi.copy(calcInput, '')
                elseif isEq then
                    commitCalc()
                else
                    appendCalc(key)
                end
            end
            if isEq or isClear then imgui.PopStyleColor() end
        end
    end

    if #calcHistory > 0 then
        imgui.Separator()
        imgui.BeginChild('##calcHist', imgui.ImVec2(0, 0), false)
        for i = #calcHistory, 1, -1 do
            local h = calcHistory[i]
            if imgui.Selectable(string.format('%s = %s##hist_%d', h.expr, h.res, i)) then
                imgui.SetClipboardText(h.raw)
                notify('Скопировано: ' .. h.res)
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Нажмите, чтобы скопировать ' .. h.res) end
        end
        imgui.EndChild()
    end

    imgui.End()
end)

imgui.OnFrame(function() return window[0] end, function()
    local display = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(display.x / 2, display.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(650, 570), imgui.Cond.FirstUseEver)
    imgui.Begin('Chromo | t.me/chromo2', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
    local p = preset()
    centerRow(270)
    imgui.SetNextItemWidth(240)
    if imgui.BeginCombo('##presets', p.name) then
        for i, item in ipairs(config.presets) do
            if imgui.Selectable(item.name .. '##' .. i, i == selectedPreset) then selectedPreset = i end
        end
        imgui.EndCombo()
    end
    imgui.SameLine()
    if iconButton('trash', '##deletePreset') and #config.presets > 1 then table.remove(config.presets, selectedPreset) selectedPreset = 1 save() end
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text('Это ваш текущий пресет, вы можете быстро переключаться между ними.')
        imgui.Text('Создать новый пресет можно в настройках.')
        imgui.EndTooltip()
    end
    local width = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * 3) / 4
    if actionButton('tags', 'Продажа', '##saleTab', imgui.ImVec2(width, 28)) then tab = 1 end
    imgui.SameLine()
    if actionButton('cart_shopping', 'Скупка', '##buyTab', imgui.ImVec2(width, 28)) then tab = 2 end
    imgui.SameLine()
    if actionButton('gear', 'Настройки', '##settingsTab', imgui.ImVec2(width, 28)) then tab = 3 end
    imgui.SameLine()
    if actionButton('clock_rotate_left', 'Журнал', '##logsTab', imgui.ImVec2(width, 28)) then tab = 4 end
    tab = (tab >= 1 and tab <= 4) and tab or 1
    if tab <= 2 then
        local canResume = (tab == 1 and resumeSale and config.sellProgress ~= nil or tab == 2 and config.buyProgress ~= nil) and not queue
        local kind = tab == 1 and 'sell' or 'buy'
        local list = tab == 1 and p.sell or p.buy
        local sum = total(list, kind)
        local commRate = (tab == 1 and config.commission > 0) and (config.commission / 100) or 0
        local feeSum = math.floor(sum * commRate + 0.5)
        local netOperation = tab == 1 and (sum - feeSum) or sum
        imgui.Spacing()
        local balanceText = 'Баланс: '
        local operationText = tab == 1 and 'Выручка: ' or 'Расход: '
        local result = playerMoney + (tab == 1 and netOperation or -netOperation)
        local hasFeeHint = tab == 1 and config.commission > 0
        local financeWidth = imgui.CalcTextSize(balanceText).x + moneyWidth(playerMoney) + imgui.CalcTextSize(operationText).x + moneyWidth(netOperation) + moneyWidth(result) + imgui.CalcTextSize(faicons('arrow_right')).x + 34
        if hasFeeHint then
            financeWidth = financeWidth + imgui.CalcTextSize(faicons('circle_question')).x + 6
        end
        centerRow(financeWidth)
        imgui.Text(balanceText)
        imgui.SameLine()
        drawMoney(playerMoney)
        imgui.SameLine()
        imgui.TextDisabled('|')
        imgui.SameLine()
        imgui.Text(operationText)
        imgui.SameLine()
        drawMoney(netOperation)
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.36, 0.78, 0.80, 1), faicons('arrow_right'))
        imgui.SameLine()
        drawMoney(result)
        if hasFeeHint then
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.48, 0.52, 0.56, 1), faicons('circle_question'))
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                local pct = config.commission % 1 == 0 and string.format('%d%%', config.commission) or string.format('%.1f%%', config.commission)
                imgui.Text('Комиссия продажи: ' .. pct .. ' (-' .. money(feeSum) .. ')')
                imgui.Text('Без комиссии: ' .. money(sum))
                imgui.EndTooltip()
            end
        end
        imgui.Spacing()
        local spacing = imgui.GetStyle().ItemSpacing.x
        local runLabel = queue and 'Остановить' or tab == 1 and 'Выставить' or 'Скупка'
        local scanLabel = scan and 'Отмена' or 'Сканировать'
        local addLabel = tab == 1 and 'Добавить на продажу' or 'Добавить'
        local canAdd = tab == 1 and #sortedItems('sell') > 0 or tab == 2 and next(buyCatalog) ~= nil
        local buttonWidth = actionWidth('plus', addLabel) + actionWidth(queue and 'stop' or 'play', runLabel) + actionWidth('eraser', 'Снять всё') + spacing * 2
        if tab == 2 then
            buttonWidth = buttonWidth + 28 + actionWidth(scan and 'xmark' or 'rotate', scanLabel) + actionWidth('scale_balanced', 'Распределить') + spacing * 3
        end
        if canResume then buttonWidth = buttonWidth + 28 + spacing end
        centerRow(buttonWidth)
        if tab == 2 then
            if actionButton('arrow_left', '', '##transferAllToSell', imgui.ImVec2(28, 25), #p.buy == 0) then
                transferAllBuyToSell()
            end
            if imgui.IsItemHovered() then
                local pct = tonumber(config.markup) or 20
                local pctStr = pct % 1 == 0 and string.format('%d%%', pct) or string.format('%.1f%%', pct)
                imgui.SetTooltip('Скопировать все активные товары из скупки в продажу\nс наценкой +' .. pctStr .. '%.')
            end
            imgui.SameLine()
        end
        if actionButton('plus', addLabel, '##addItem', nil, not canAdd) then ffi.copy(pickerSearch, '') imgui.OpenPopup('Добавить##chromo') end
        imgui.SameLine()
        if tab == 2 then
            if actionButton(scan and 'xmark' or 'rotate', scanLabel, '##scanBuy') then
                if scan then stopWork('Сканирование остановлено') else startScan() end
            end
            imgui.SameLine()
        end
        if actionButton(queue and 'stop' or 'play', runLabel, '##runWork') then if queue then stopWork('Остановлено') elseif tab == 1 then startSell() else startBuy() end end
        imgui.SameLine()
        if actionButton('eraser', 'Снять всё', '##clearWork') then if tab == 1 then clearSell() else clearBuy() end end
        if tab == 2 then
            imgui.SameLine()
            if actionButton('scale_balanced', 'Распределить', '##distributeBuy', nil, #p.buy == 0) then
                distributeBuyItems()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip('Умно распределяет количество товаров под сумму твоих денег,\nчтобы баланса хватило на скупку всех активных позиций.')
            end
        end
        if canResume then
            imgui.SameLine()
            if actionButton('rotate_right', '', '##resumeWork', imgui.ImVec2(28, 25), false, 0xFFC06A3D, 0xFFFFFFFF) then
                local progress = tab == 1 and config.sellProgress or config.buyProgress
                local index = tonumber(progress.preset) or 1
                selectedPreset = config.presets[index] and index or 1
                if tab == 1 then startSell(true) else startBuy(true) end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                if tab == 1 and config.sellProgress then
                    imgui.Text('Продолжить продажу:')
                    for _, entry in ipairs(config.sellProgress.items) do
                        imgui.Text(string.format('%s: %d шт.', entry.name, entry.left))
                    end
                end
                if tab == 2 and config.buyProgress then
                    imgui.Text('Продолжить скупку:')
                    for _, entry in ipairs(config.buyProgress.items) do
                        imgui.Text(string.format('%s: %d шт.', entry.name, entry.left))
                    end
                end
                imgui.EndTooltip()
            end
        end
        imgui.Separator()
        local isAsc = sortAscending[kind] ~= false
        local sortIcon = isAsc and 'arrow_up_short_wide' or 'arrow_down_wide_short'
        local sortBtnW = imgui.CalcTextSize(faicons(sortIcon)).x + imgui.GetStyle().FramePadding.x * 2 + imgui.GetStyle().ItemSpacing.x
        local trashW = imgui.CalcTextSize(faicons('trash')).x + imgui.GetStyle().FramePadding.x * 2 + imgui.GetStyle().ItemSpacing.x
        imgui.SetNextItemWidth(imgui.GetContentRegionAvail().x - sortBtnW - trashW)
        imgui.InputTextWithHint('##listSearch', faicons('magnifying_glass') .. '  Поиск по добавленным товарам', listSearch, 128)
        imgui.SameLine()
        if iconButton(sortIcon, '##sortPresetList') and #list > 1 then
            sortPresetList(list, kind, isAsc)
            sortAscending[kind] = not isAsc
            save()
        end
        if imgui.IsItemHovered() then
            imgui.SetTooltip(isAsc and 'Сортировать по цене: сначала дешевые' or 'Сортировать по цене: сначала дорогие')
        end
        imgui.SameLine()
        if iconButton('trash', '##clearPresetList') and #list > 0 then
            if tab == 1 then
                p.sell = {}
                if config.sellProgress and config.sellProgress.preset == selectedPreset then
                    config.sellProgress = nil
                    resumeSale = false
                end
                notify('Список продажи в пресете "' .. p.name .. '" очищен')
            else
                p.buy = {}
                if config.buyProgress and config.buyProgress.preset == selectedPreset then
                    config.buyProgress = nil
                end
                notify('Список скупки в пресете "' .. p.name .. '" очищен')
            end
            save()
        end
        if imgui.IsItemHovered() then
            imgui.SetTooltip(tab == 1 and 'Очистить весь список продажи' or 'Очистить весь список скупки')
        end
        imgui.BeginChild('##items', imgui.ImVec2(0, 0), true)
        listItems(kind)
        imgui.EndChild()
        picker()
    elseif tab == 3 then
        drawSettingsTab()
    else
        local logWidth = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
        if actionButton('tags', 'Продажи', '##sellLogs', imgui.ImVec2(logWidth, 26)) then logTab = 1 end
        imgui.SameLine()
        if actionButton('cart_shopping', 'Покупки', '##buyLogs', imgui.ImVec2(logWidth, 26)) then logTab = 2 end
        imgui.Separator()
        local entries = config.logs[logTab == 1 and 'sell' or 'buy']
        local days = {}
        local dates = {}
        local allTime = 0
        for index = #entries, 1, -1 do
            local entry = entries[index]
            local date = os.date('%d.%m.%Y', entry.time)
            if not days[date] then
                days[date] = {sum = 0, entries = {}}
                dates[#dates + 1] = date
            end
            local amount = tonumber(entry.text:match(':CASH:(%d+)')) or 0
            days[date].sum = days[date].sum + amount
            allTime = allTime + amount
            days[date].entries[#days[date].entries + 1] = entry
        end
        local totalText = logTab == 1 and 'Заработано за всё время: ' or 'Потрачено за всё время: '
        centerRow(imgui.CalcTextSize(totalText).x + moneyWidth(allTime) + imgui.GetStyle().ItemSpacing.x)
        imgui.Text(totalText)
        imgui.SameLine()
        drawMoney(allTime)
        imgui.Separator()
        imgui.BeginChild('##logEntries', imgui.ImVec2(0, 0), false)
        for _, date in ipairs(dates) do
            local group = days[date]
            if imgui.CollapsingHeader(date .. '  |  ' .. money(group.sum) .. '##' .. date) then
                for _, entry in ipairs(group.entries) do
                    imgui.Text(os.date('%H:%M:%S', entry.time))
                    imgui.SameLine()
                    imgui.TextWrapped((entry.text:gsub(':CASH:', '$')))
                end
            end
        end
        if #entries == 0 then imgui.TextDisabled('Записей пока нет') end
        imgui.EndChild()
    end
    drawEditor()
    imgui.End()
end)

local overlayFrame = imgui.OnFrame(function()
    return config.showZones or scan ~= nil or queue ~= nil or os.clock() < statusDone
end, function(self)
    self.HideCursor = not window[0] and not (calcWin[0] and config.calcEnabled) and not (stealerWin[0] and config.itemStealer and lavkaOpen and not isMyLavka)

    if config.showZones then
        local bg = imgui.GetBackgroundDrawList()
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        for id = 0, 2048 do
            if sampIs3dTextDefined(id) then
                local text, _, tx, ty, tz = sampGet3dTextInfoById(id)
                local dist3d = getDistanceBetweenCoords3d(tx, ty, tz, px, py, pz)
                if dist3d <= 55 and not inMarketArea(tx, ty) then
                    local clean = (text or ''):gsub('{%x%x%x%x%x%x}', '')
                    local radius, zShift
                    if clean:find(cp('Управления товарами'), 1, true) then
                        radius, zShift = 5, 1.3
                    elseif clean:find(cp('Тип'), 1, true) or clean:find(cp('Номер дома'), 1, true) then
                        radius, zShift = 25, 2.3
                    end
                    if radius and dist3d <= radius + 28 then
                        local flatDist = math.sqrt((tx - px) ^ 2 + (ty - py) ^ 2)
                        local ringColor = flatDist <= radius and 0xCC4444FF or 0xAAEDE6D8
                        drawRing3D(bg, tx, ty, tz - zShift, radius, ringColor)
                    end
                end
            end
        end
    end

    if scan ~= nil or queue ~= nil or os.clock() < statusDone then
        local display = imgui.GetIO().DisplaySize
        local done = not scan and not queue
        local remaining = statusDone - os.clock()
        local alpha = done and math.min(1, math.max(0, remaining / 0.25)) or 1
        imgui.SetNextWindowPos(imgui.ImVec2(display.x / 2, display.y - 42), imgui.Cond.Always, imgui.ImVec2(0.5, 1))
        imgui.SetNextWindowBgAlpha(alpha)
        local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoInputs + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoBringToFrontOnFocus
        imgui.Begin('##chromoStatus', nil, flags)
        imgui.Dummy(imgui.ImVec2(34, 34))
        local center = imgui.GetItemRectMin()
        center = imgui.ImVec2(center.x + 17, center.y + 17)
        local draw = imgui.GetWindowDrawList()
        if done then
            local progress = math.min(1, (1.4 - remaining) / 0.3)
            if statusFailed then
                local p1 = math.min(1, progress * 2)
                draw:AddLine(imgui.ImVec2(center.x - 7, center.y - 7), imgui.ImVec2(center.x - 7 + 14 * p1, center.y - 7 + 14 * p1), 0xFF5555FF, 2.5)
                if progress > 0.5 then
                    local p2 = (progress - 0.5) * 2
                    draw:AddLine(imgui.ImVec2(center.x + 7, center.y - 7), imgui.ImVec2(center.x + 7 - 14 * p2, center.y - 7 + 14 * p2), 0xFF5555FF, 2.5)
                end
            else
                local first = imgui.ImVec2(center.x - 8, center.y)
                local middle = imgui.ImVec2(center.x - 2, center.y + 6)
                local last = imgui.ImVec2(center.x + 9, center.y - 7)
                local p1 = math.min(1, progress * 2)
                local currentMiddle = imgui.ImVec2(first.x + (middle.x - first.x) * p1, first.y + (middle.y - first.y) * p1)
                draw:PathClear()
                draw:PathLineTo(first)
                draw:PathLineTo(currentMiddle)
                if progress > 0.5 then
                    local p2 = (progress - 0.5) * 2
                    draw:PathLineTo(imgui.ImVec2(middle.x + (last.x - middle.x) * p2, middle.y + (last.y - middle.y) * p2))
                end
                draw:PathStroke(0xFFCCC25C, false, 2.5)
            end
        else
            draw:AddCircle(center, 13, 0xFF57572E, 32, 2)
            local rotation = os.clock() * 5
            for i = 0, 17 do
                local a = rotation + i * math.pi / 32
                local b = rotation + (i + 1) * math.pi / 32
                draw:AddLine(imgui.ImVec2(center.x + math.cos(a) * 13, center.y + math.sin(a) * 13), imgui.ImVec2(center.x + math.cos(b) * 13, center.y + math.sin(b) * 13), 0xFFCCC25C, 2.2)
            end
        end
        imgui.End()
    end
end)
overlayFrame.HideCursor = true

local ignoredModifierKeys = {
    [vkeys.VK_CONTROL] = true, [vkeys.VK_LCONTROL] = true, [vkeys.VK_RCONTROL] = true,
    [vkeys.VK_SHIFT] = true, [vkeys.VK_LSHIFT] = true, [vkeys.VK_RSHIFT] = true,
    [vkeys.VK_MENU] = true, [vkeys.VK_LMENU] = true, [vkeys.VK_RMENU] = true,
    [vkeys.VK_LBUTTON] = true, [vkeys.VK_RBUTTON] = true, [vkeys.VK_MBUTTON] = true
}

addEventHandler('onWindowMessage', function(msg, wparam, lparam)
    if msg == 0x0100 then -- WM_KEYDOWN
        if bindingKey then
            if wparam == vkeys.VK_ESCAPE then
                bindingKey = false
                consumeWindowMessage(true, true)
                return
            end
            if not ignoredModifierKeys[wparam] then
                config.calcHotkey = {
                    ctrl = isKeyDown(vkeys.VK_CONTROL),
                    shift = isKeyDown(vkeys.VK_SHIFT),
                    alt = isKeyDown(vkeys.VK_MENU),
                    key = wparam
                }
                bindingKey = false
                save()
                consumeWindowMessage(true, true)
                return
            end
        elseif config.calcEnabled and not sampIsChatInputActive() then
            local hk = config.calcHotkey
            if hk and hk.key == wparam and (bit.band(lparam, 0x40000000) == 0) then
                local ctrlOk = (hk.ctrl == true) == isKeyDown(vkeys.VK_CONTROL)
                local shiftOk = (hk.shift == true) == isKeyDown(vkeys.VK_SHIFT)
                local altOk = (hk.alt == true) == isKeyDown(vkeys.VK_MENU)
                if ctrlOk and shiftOk and altOk then
                    calcWin[0] = not calcWin[0]
                    if calcWin[0] then
                        calcFocusInput = true
                    elseif not window[0] and not sampIsDialogActive() and not lavkaOpen then
                        sampToggleCursor(false)
                    end
                    consumeWindowMessage(true, true)
                end
            end
        end
    end
end)

function main()
    while not isSampAvailable() do wait(100) end
    math.randomseed(os.time())
    load()
    sync()
    notify('Скрипт загружен! Активация: {9db7d6}/chromo {ffffff}| Telegram: {38b6ff}t.me/chromo2')
    if not next(names) then updateNames() end
    sampRegisterChatCommand('chromo', function()
        window[0] = not window[0]
        if not window[0] and not calcWin[0] and not sampIsDialogActive() and not lavkaOpen then
            sampToggleCursor(false)
        end
    end)
    local lastOptCheck = os.clock()
    local lastSave = os.clock()
    while true do
        wait(50)
        local now = os.clock()
        if config.optimizer and (needWorldOptimize or now - lastOptCheck >= 1.5) then
            needWorldOptimize = false
            lastOptCheck = now
            applyWorldOptimizer()
        end
        if namesReadyToParse then
            namesReadyToParse = false
            local file = io.open(namesTempFile, 'r')
            if file then
                local content = file:read('*a')
                file:close()
                local items = json.decode(content)
                if parseItemsDatabaseTable(items) > 0 then
                    save()
                end
            end
            pcall(os.remove, namesTempFile)
            namesUpdating = false
        end
        if closeCefAt and now >= closeCefAt then
            closeCefAt = nil
            closeCefInventory()
        end
        if queue and queue.stepStage and queue.stage == queue.stepStage and queue.stepDeadline and now > queue.stepDeadline then
            if queue.stage == 'waitInv' then
                queue.stepStage = nil
                if queue.kind == 'sell' then nextSell()
                elseif queue.kind == 'clearSell' then nextClearSell()
                elseif queue.kind == 'clearBuy' then nextClearBuy() end
            elseif (queue.stage == 'itemInfo' or queue.stage == 'clearItemInfo') and (queue.retries or 0) < 5 and queue.slot and queue.itemType then
                queue.retries = (queue.retries or 0) + 1
                sendCef('rightClickOnBlock', json.encode({type = queue.itemType, slot = queue.slot}))
                watchStep(queue.stage, queue.stepError, 0.55)
            elseif (queue.stage == 'price' or queue.stage == 'clearConfirm') and (queue.actionRetries or 0) < 4 and queue.slot and queue.itemType then
                queue.actionRetries = (queue.actionRetries or 0) + 1
                queue.stage = queue.stage == 'price' and 'itemInfo' or 'clearItemInfo'
                sendCef('rightClickOnBlock', json.encode({type = queue.itemType, slot = queue.slot}))
                watchStep(queue.stage, queue.stepError, 0.55)
            elseif queue.kind == 'sell' and (queue.stage == 'itemInfo' or queue.stage == 'price') then
                if queue.slot then
                    queue.usedSlots = queue.usedSlots or {}
                    queue.usedSlots[queue.slot] = true
                end
                skipSellItem('Нет ответа от сервера по предмету')
            elseif (queue.kind == 'clearSell' or queue.kind == 'clearBuy') and (queue.stage == 'clearItemInfo' or queue.stage == 'clearConfirm') then
                if queue.slot then
                    queue.failedSlots = queue.failedSlots or {}
                    queue.failedSlots[queue.slot] = true
                end
                queue.stage = 'wait'
                queue.stepStage = nil
                if queue.kind == 'clearSell' then nextClearSell() else nextClearBuy() end
            else
                stopWork(queue.stepError, true)
            end
        end
        if scan and scan.deadline and now > scan.deadline and (scan.count or 0) == 0 then
            stopWork('Подойдите впритык к лавке', true)
        end
        if dirty and now - lastSave >= 1.5 then
            flushSave()
            lastSave = now
        end
    end
end

function onScriptTerminate(script)
    if script == thisScript() then flushSave() end
end