script_author('fokich')
script_name('autocottonv3.2')


--                  888                                    888    888                     
--                  888                                    888    888                     
--                  888                                    888    888                     
-- 8888b.  888  888 888888 .d88b.          .d8888b .d88b.  888888 888888 .d88b.  88888b.  
--    "88b 888  888 888   d88""88b        d88P"   d88""88b 888    888   d88""88b 888 "88b 
--.d888888 888  888 888   888  888 888888 888     888  888 888    888   888  888 888  888 
--888  888 Y88b 888 Y88b. Y88..88P        Y88b.   Y88..88P Y88b.  Y88b. Y88..88P 888  888 
--"Y888888  "Y88888  "Y888 "Y88P"          "Y8888P "Y88P"   "Y888  "Y888 "Y88P"  888  888 



--libs
local imgui = require('mimgui')
require('lib.moonloader')
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
require ("lib.moonloader")
local sampev = require ("lib.samp.events")
local effil = require ('effil') 
local ffi = require('ffi')
local inicfg = require('inicfg')


--settings
local mode = false
local sprint = false
local autojump = false
local isLien = false
local stats = false
local isRandom = false

--dSettings
local stopWithDialog = false
local stopWithSetPlayerPos = false
local stopWithChatMessage = false
local quitgame = false

--other
local updateid
local totalct = 0
local founded = false
local font = renderCreateFont("Century Gothic", 12, 5)
local fontonscreen = renderCreateFont("Century Gothic", 18, 5)
local resx, resy = getScreenResolution()

--tables
local array = {}

--imgui booleans
local WinState = imgui.new.bool()
local WinTg = imgui.new.bool()
local WinStats = imgui.new.bool()
local WinSet = imgui.new.bool()
local tknField = imgui.new.char[256]()
local uIdField = imgui.new.char[256]()
local SliderInt = imgui.new.int(1)

--inicfg


local mainIni = inicfg.load({
    main = {
     token = '',
    userId = ''
    }
}, 'autocottonv3.ini')

if not doesFileExist('moonloader/config/autocottonv3.ini') then
	inicfg.save(mainIni,'autocottonv3.ini')
end



function threadHandle(runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do
        r = t:get(0)
        wait(0)
    end
    local status = t:status()
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then resolve(result) else reject(result) end
    elseif err then
        reject(err)
    elseif status == 'canceled' then
        reject(status)
    end
    t:cancel(0)
end

function requestRunner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

function async_http_request(url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

function encodeUrl(str)
    str = str:gsub(' ', '%+')
    str = str:gsub('\n', '%%0A')
    return u8:encode(str, 'CP1251')
end

function sendTelegramNotification(msg) 
    msg = msg:gsub('{......}', '') 
    msg = encodeUrl(msg) 
    async_http_request('https://api.telegram.org/bot' .. mainIni.main.token .. '/sendMessage?chat_id=' .. mainIni.main.userId .. '&reply_markup={"keyboard": [["Mode", "Stats"]], "resize_keyboard": true}&text='..msg,'', function(result) end) 
end

function get_telegram_updates() 
    while not updateid do wait(1) end 
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..mainIni.main.token..'/getUpdates?chat_id='..mainIni.main.userId..'&offset=-1'
        threadHandle(runner, url, args, processing_telegram_messages, reject)
        wait(0)
    end
end



function processing_telegram_messages(result) -- функция проверОчки того что отправил чел
    if result then
        -- тута мы проверяем все ли верно
        local proc_table = decodeJson(result)
        if proc_table.ok then
            if #proc_table.result > 0 then
                local res_table = proc_table.result[1]
                if res_table then
                    if res_table.update_id ~= updateid then
                        updateid = res_table.update_id
                        local message_from_user = res_table.message.text
                        if message_from_user then
                            -- и тут если чел отправил текст мы сверяем
                            local text = u8:decode(message_from_user) .. ' ' --добавляем в конец пробел дабы не произошли тех. шоколадки с командами(типо чтоб !q не считалось как !qq)
                            if text:match('^/start') then
                                sendTelegramNotification('Приветствую! Тут ты можешь управлять своим ботом с помощю кнопок снизу. \ndeveloped by fokich')
                            elseif text:match('^Mode') then
                                mode = not mode
                                sendTelegramNotification(mode and 'Бот включен' or 'Бот выключен')
                            elseif text:match('^Stats') then
                                local isl = isLien and 'льна: ' or 'хлопка: '
                                sendTelegramNotification('Количество собранного '.. isl .. totalct .. '\nОсталось: ' .. SliderInt[0] - totalct)
                            else -- если же не найдется ни одна из команд выше, выведем сообщение
                                sendTelegramNotification('Неизвестная команда!')
                            end
                        end
                    end
                end
            end
        end
    end
end

function getLastUpdate() -- тут мы получаем последний ID сообщения, если же у вас в коде будет настройка токена и chat_id, вызовите эту функцию для того чтоб получить последнее сообщение
    async_http_request('https://api.telegram.org/bot'..mainIni.main.token..'/getUpdates?chat_id='..mainIni.main.userId..'&offset=-1','',function(result)
        if result then
            local proc_table = decodeJson(result)
            if proc_table.ok then
                if #proc_table.result > 0 then
                    local res_table = proc_table.result[1]
                    if res_table then
                        updateid = res_table.update_id
                    end
                else
                    updateid = 1 -- тут зададим значение 1, если таблица будет пустая
                end
            end
        end
    end)
end

--main

function main()
    while not isSampAvailable() do wait(0) end
    wait(200)
    
    sampRegisterChatCommand('acot', function ()
        WinState[0] = not WinState[0]
    end)    
    getLastUpdate() 
    lua_thread.create(get_telegram_updates)
    
    while true do
        wait(0)
        local thr1 = lua_thread.create_suspended(lookFor3dText)
        
        -- Обработка состояния бота
        if mode then
            thr1:run()
            if #array > 0 then
                local res, tbl = sortByType(array)
                if res then         
                    local tb1, tb2 = sortByType2(tbl)
                    local result, position, dist = GetNearestCoords(tb1, tb2)
                    if result then
                        local x, y, z = position[1], position[2], position[3]
                        local px, py, pz = getCharCoordinates(PLAYER_PED)
                        if totalct ~= SliderInt[0] then
                            if getDistanceBetweenCoords3d(px, py, pz, x, y, z) > 2 then
                                isRandom = false
                                runToPoint(x, y, z)
                            else
                                isRandom = true
                                array = {}
                                local rand = math.random(0, 9999999);
                                if rand >= 9959999 then
                                    setVirtualKeyDown(VK_Y, true)
                                    wait(100)
                                    setVirtualKeyDown(VK_Y, false)
                                    wait(200)
                                    sampSendClickTextdraw(2112)
                                end
                                repeat
                                    setGameKeyState(21, -256)
                                    wait(200)
                                    setGameKeyState(21, 0)
                                until true
                            end
                        else
                            mode = false
                            sampAddChatMessage('{cc66ff}[auto-cotton]: {FFFFFF}Бот собрал заданное кол-во ресурсов!', -1)
                            sendTelegramNotification('Бот собрал заданное кол-во ресурсов')
                        end
                    else
                        renderFontDrawText(fontonscreen, 'Куст не найден', resx / 2 + 500, resy / 2, -1, false)
                    end
                else
                    renderFontDrawText(fontonscreen, 'Куст не найден', resx / 2 + 500, resy / 2, -1, false)
                end
            else
                renderFontDrawText(fontonscreen, 'Куст не найден', resx / 2 + 500, resy / 2, -1, false)
            end
        else
            thr1:terminate()
        end
        
        -- Обработка команды через cheat
        if testCheat('acccc') then
            mode = not mode
        end
        
        -- Обработка нажатия клавиши END
        if isKeyDown(VK_END) then
            -- Переключаем состояние режима (mode)
            mode = not mode
            local modeText = mode and 'включен' or 'выключен'
            sampAddChatMessage('{cc66ff}[auto-cotton]: {FFFFFF}Бот ' .. modeText, -1)
            wait(200)  -- Добавляем задержку, чтобы избежать множественных срабатываний на одно нажатие
        end
    end
end


--logic

function lookFor3dText()
    for i = 0, 2048 do
        if sampIs3dTextDefined(i) then
            local text, color, x, y, z, distance, ignoreWalls, playerId, vehicleId = sampGet3dTextInfoById(i)
            local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
            local distance = getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z)

            if text:find('Можно собрать') and text:find('10') then
                if text:find("Лён") and isLien then
                    table.insert(array, {['position'] = {x, y, z}, ['distance'] = distance, ['type'] = 2})
                elseif text:find("Хлопок") and not isLien then
                    table.insert(array, {['position'] = {x, y, z}, ['distance'] = distance, ['type'] = 2})
                end
            else
                if text:find('этап 2') and text:find('Осталось') then
                    if text:find("Лён") and isLien then
                        for i = 1, 59 do
                            if text:find("00:" .. (i < 10 and ("0" .. i) or i)) then
                                table.insert(array, {['position'] = {x, y, z}, ['distance'] = distance, ['type'] = 1})
                                break
                            end
                        end
                    elseif text:find("Хлопок") and not isLien then
                        for i = 1, 59 do
                            if text:find("00:" .. (i < 10 and ("0" .. i) or i)) then
                                table.insert(array, {['position'] = {x, y, z}, ['distance'] = distance, ['type'] = 1})
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

function sortByType(tbl)
    if #tbl > 0 then
        table.sort(tbl, function (a, b) return a.type > b.type end)
        return true, tbl
    end
    return false
end

function sortByType2(tbl)
    if #tbl >= 1 then
        local tb1 = {}
        local tb2 = {}
        for k, v in pairs(tbl) do
            if v.type == 2 then
                table.insert(tb1, {['position'] = v.position, ['distance'] = v.distance})
            else
                table.insert(tb2, {['position'] = v.position, ['distance'] = v.distance})
            end
        end
        return tb1, tb2
    end
end

function GetNearestCoords(tbl1, tbl2)
    if #tbl1 > 0 then
        table.sort(tbl1, function(a, b) return (a.distance < b.distance) end)
        return true, tbl1[1].position, tbl1[1].distance
    elseif #tbl2 > 0 then
        table.sort(tbl2, function(a, b) return (a.distance < b.distance) end)
        return true, tbl2[1].position, tbl2[1].distance
    else
        return false
    end
end

function runToPoint(tox, toy, z1)
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local angle = getHeadingFromVector2d(tox - x, toy - y)
    local px, py = getActiveCameraCoordinates()
    local pangle = getHeadingFromVector2d(tox - px, toy - py)
    if getDistanceBetweenCoords2d(x, y, tox, toy) > 1.5 then setCameraPositionUnfixed(0, math.rad(angle - 90)) end
    stopRun = false
    while getDistanceBetweenCoords2d(x, y, tox, toy) > 1.5 do
        local tx, ty, tz = convert3DCoordsToScreen(tox, toy, z1)
        Draw3DCircle(tox, toy, z1 - 0.1, 3, 0xffcc66ff)
        setGameKeyState(1, -255)
        if sprint then setGameKeyState(16, 1) end
        if autojump and getDistanceBetweenCoords2d(x, y, tox, toy) > 18.0 then 
            local rand = math.random(0, 9999999);
            if rand >= 9909999 then
                setGameKeyState(16, 0);
                setGameKeyState(14, 255);
            end
        end
        wait(1)
        x, y, z = getCharCoordinates(PLAYER_PED)
        angle = getHeadingFromVector2d(tox - x, toy - y)
        setCameraPositionUnfixed(0, math.rad(angle - 90))
        if stopRun then
            stopRun = false
            break
        end
    end
end

function sampev.onDisplayGameText(style, tm, text)
	if text == "cotton + 1" then
        totalct = totalct + 1
    elseif text == 'cotton + 2' then
        totalct = totalct + 2
    elseif text == 'linen + 1' then
        totalct = totalct + 1
    elseif text == 'linen + 2' then
        totalct = totalct + 2
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if stopWithDialog then
        mode = false
        sendTelegramNotification('Администратор овтетил вам в /pm: ' .. text)
        if quitgame then
            os.execute('taskkill /IM gta_sa.exe /F')
        end
    end
end

function sampev.onSetPlayerPos(position)
    if stopWithSetPlayerPos then
        mode = false
        sendTelegramNotification('Сервер/Администратор изменил вашу позицию: ' .. position)
        if quitgame then
            os.execute('taskkill /IM gta_sa.exe /F')
        end
    end
end

function sampev.onSendAimSync(data)
    if isRandom then
        local spX = math.rad(getCharHeading(1) + 270)
        math.randomseed(os.time())
        local spY = -math.rad(math.random(30*100, 180*100)/100)
        data.camFront.x = math.cos(spX)*math.sin(spY)
        data.camFront.y = math.sin(spX)*math.sin(spY)
        data.camFront.z = math.cos(spY)
    end
end

function sampev.onServerMessage(color, text)
    if stopWithChatMessage and text:find("Вы тут?") or text:find("Вы тут") or text:find("Вы здесь") or text:find("Вы здесь?") or text:find("вы тут?") or text:find("вы тут") or text:find("вы здесь") or text:find("вы здесь?") or text:find("в ы з д е с ь?") then
        mode = false
        local allchat = '\n'
        for i = 100-3, 99 do
            local getstr = select(1,sampGetChatString(i))
            allchat = allchat .. getstr .. '\n'
        end
        sendTelegramNotification('Бота спросили: вы тут?'  .. allchat)
        if quitgame then
            os.execute('taskkill /IM gta_sa.exe /F')
        end
    end
end

function Draw3DCircle(x, y, z, radius, color)
    local screen_x_line_old, screen_y_line_old;

    for rot=0, 360 do
        local rot_temp = math.rad(rot)
        local lineX, lineY, lineZ = radius * math.cos(rot_temp) + x, radius * math.sin(rot_temp) + y, z
        local screen_x_line, screen_y_line = convert3DCoordsToScreen(lineX, lineY, lineZ)
        if screen_x_line ~=nil and screen_x_line_old ~= nil and isPointOnScreen(lineX, lineY, lineZ, 1) then renderDrawLine(screen_x_line, screen_y_line, screen_x_line_old, screen_y_line_old, 3, color) end
        screen_x_line_old, screen_y_line_old = screen_x_line, screen_y_line
    end
end

--imgui[[[[[[

imgui.OnFrame(function() return WinState[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(200, 480), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(210, 280), imgui.Cond.FirstUseEver)
    imgui.Begin('##act', WinState, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
    imgui.SetCursorPos(imgui.ImVec2(65, 25))
    imgui.PushFont(smal)
    imgui.Text(u8'auto-cotton')
    if imgui.BeginChild(u8'Настройки', imgui.ImVec2(190, 160), true) then
        imgui.PushFont(big)
        if imgui.RadioButtonBool(u8'Статус', mode) then mode = not mode end
        if imgui.RadioButtonBool(u8'Бег', sprint) then sprint = not sprint end
        if imgui.RadioButtonBool(u8'Прыжки', autojump) then autojump = not autojump end
        local isl = isLien and u8'лён' or u8'хлопок'
        if imgui.RadioButtonBool(u8'Собираю ' .. isl, isLien) then
            isLien = not isLien 
        end
        imgui.SliderInt('##', SliderInt, 1, 10000)
        imgui.SetCursorPos(imgui.ImVec2(135, 122))
        if imgui.Button(u8'Сброс') then totalct = 0 end
        imgui.SetCursorPos(imgui.ImVec2(100, 10))
        if imgui.Button('TG') then WinTg[0] = not WinTg[0] end
        imgui.SetCursorPos(imgui.ImVec2(128, 10))
        if imgui.Button('Stats') then WinStats[0] = not WinStats[0] end
        imgui.SetCursorPos(imgui.ImVec2(100, 35))
        if imgui.Button(u8'Настройки') then WinSet[0] = not WinSet[0] end
        imgui.EndChild() 
    end
    if imgui.BeginChild(u8'asd', imgui.ImVec2(190, 55), true) then
        imgui.SetCursorPos(imgui.ImVec2(12, 20))
        imgui.Text(u8'Автор: fokich')
        imgui.SetCursorPos(imgui.ImVec2(122, 10))
        imgui.Text(u8'Телеграм')
        if imgui.IsItemClicked() then os.execute('explorer https://t.me/devfokich') end
        imgui.SetCursorPos(imgui.ImVec2(123, 26))
        imgui.Text(u8'BlastHack')
        if imgui.IsItemClicked() then os.execute('explorer https://www.blast.hk/threads/199063/page-6') end
        imgui.EndChild() 
    end
    imgui.End()
end)

imgui.OnFrame(function() return WinSet[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500, 480), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(280, 200), imgui.Cond.FirstUseEver)
    imgui.Begin('##Window', WinSet, imgui.WindowFlags.NoResize)
    imgui.PushFont(big)
    imgui.Text(u8'Выключение')
    if imgui.RadioButtonBool(u8'при диалоге от админа', stopWithDialog) then stopWithDialog = not stopWithDialog end
    if imgui.RadioButtonBool(u8'при изменении позиции сервером', stopWithSetPlayerPos) then stopWithSetPlayerPos = not stopWithSetPlayerPos end
    if imgui.RadioButtonBool(u8'при проверке на бота в чате', stopWithChatMessage) then stopWithChatMessage = not stopWithChatMessage end
    if imgui.RadioButtonBool(u8'Выходить из игры', quitgame) then quitgame = not quitgame end
    imgui.End()
end)


imgui.OnFrame(function() return WinTg[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500, 480), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(210, 200), imgui.Cond.FirstUseEver)
    imgui.Begin('##Window', WinTg, imgui.WindowFlags.NoResize)
    imgui.PushFont(big)
    imgui.InputText(u8"Токен", tknField, 256)
    imgui.InputText(u8"User id", uIdField, 256)
    if imgui.Button(u8'Сохранить!') then
        mainIni.main.token = u8:decode(ffi.string(tknField))
        mainIni.main.userId = u8:decode(ffi.string(uIdField))
        inicfg.save(mainIni,'autocottonv3.ini')
        getLastUpdate() 
    end
    if imgui.Button(u8'Тестовое Сообщение') then
        sampAddChatMessage('[Telegram] Отправляю тестовое сообщение',-1)
        sendTelegramNotification('Тестовое сообщение от '..sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))))
    end
    imgui.End()
end)

imgui.OnFrame(function() return WinStats[0] end, function(player)
    imgui.SetNextWindowPos(imgui.ImVec2(500, 480), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(210, 85), imgui.Cond.FirstUseEver)
    imgui.Begin('##Window', WinTg, imgui.WindowFlags.NoResize)
    imgui.PushFont(big)
    local isl = isLien and u8'льна: ' or u8'хлопка: '
    imgui.Text(u8'Кол-во ' .. isl .. totalct)
    imgui.Text(u8'Осталось: ' .. SliderInt[0] - totalct)
    imgui.End()
end).HideCursor = true


imgui.OnInitialize(function()
    themeexam()
    imgui.GetIO().IniFilename = nil
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 14.0, nil, glyph_ranges)
    smal = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 17.0, _, glyph_ranges)
    big = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 15.0, _, glyph_ranges)
end)

function themeexam()
    imgui.SwitchContext()
    local style  = imgui.GetStyle()
    local colors = style.Colors
    local clr    = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
  
    style.WindowRounding         = 4.0
    style.WindowTitleAlign       = ImVec2(0.5, 0.5)
    style.FrameRounding          = 4.0
    style.ItemSpacing            = ImVec2(10, 5)
    style.ScrollbarSize          = 15
    style.ScrollbarRounding      = 0
    style.GrabMinSize            = 9.6
    style.GrabRounding           = 1.0
    style.WindowPadding          = ImVec2(10, 10)
    style.AntiAliasedLines       = true
    style.FramePadding           = ImVec2(5, 4)
    style.DisplayWindowPadding   = ImVec2(27, 27)
    style.DisplaySafeAreaPadding = ImVec2(5, 5)
    style.ButtonTextAlign        = ImVec2(0.5, 0.5)
    style.IndentSpacing          = 12.0
    style.Alpha                  = 1.0
  
      colors[clr.Text]                 = ImVec4(1.00, 1.00, 1.00, 1.00)
      colors[clr.TextDisabled]         = ImVec4(0.50, 0.50, 0.50, 1.00)
      colors[clr.WindowBg]             = ImVec4(0.06, 0.06, 0.06, 0.94)
      colors[clr.PopupBg]              = ImVec4(0.08, 0.08, 0.08, 0.94)
      colors[clr.Border]               = ImVec4(0.43, 0.43, 0.50, 0.50)
      colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)
      colors[clr.FrameBg]              = ImVec4(0.44, 0.44, 0.44, 0.60)
      colors[clr.FrameBgHovered]       = ImVec4(0.57, 0.57, 0.57, 0.70)
      colors[clr.FrameBgActive]        = ImVec4(0.76, 0.76, 0.76, 0.80)
      colors[clr.TitleBg]              = ImVec4(0.04, 0.04, 0.04, 1.00)
      colors[clr.TitleBgActive]        = ImVec4(0.16, 0.16, 0.16, 1.00)
      colors[clr.TitleBgCollapsed]     = ImVec4(0.00, 0.00, 0.00, 0.60)
      colors[clr.MenuBarBg]            = ImVec4(0.14, 0.14, 0.14, 1.00)
      colors[clr.ScrollbarBg]          = ImVec4(0.02, 0.02, 0.02, 0.53)
      colors[clr.ScrollbarGrab]        = ImVec4(0.31, 0.31, 0.31, 1.00)
      colors[clr.ScrollbarGrabHovered] = ImVec4(0.41, 0.41, 0.41, 1.00)
      colors[clr.ScrollbarGrabActive]  = ImVec4(0.51, 0.51, 0.51, 1.00)
      colors[clr.CheckMark]            = ImVec4(0.13, 0.75, 0.55, 0.80)
      colors[clr.SliderGrab]           = ImVec4(0.13, 0.75, 0.75, 0.80)
      colors[clr.SliderGrabActive]     = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.Button]               = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.ButtonHovered]        = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.ButtonActive]         = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.Header]               = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.HeaderHovered]        = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.HeaderActive]         = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.Separator]            = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.SeparatorHovered]     = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.SeparatorActive]      = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.ResizeGrip]           = ImVec4(0.13, 0.75, 0.55, 0.40)
      colors[clr.ResizeGripHovered]    = ImVec4(0.13, 0.75, 0.75, 0.60)
      colors[clr.ResizeGripActive]     = ImVec4(0.13, 0.75, 1.00, 0.80)
      colors[clr.PlotLines]            = ImVec4(0.61, 0.61, 0.61, 1.00)
      colors[clr.PlotLinesHovered]     = ImVec4(1.00, 0.43, 0.35, 1.00)
      colors[clr.PlotHistogram]        = ImVec4(0.90, 0.70, 0.00, 1.00)
      colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
      colors[clr.TextSelectedBg]       = ImVec4(0.26, 0.59, 0.98, 0.35)
  end

--imgui]]]]]]

