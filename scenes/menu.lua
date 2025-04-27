local composer = require("composer")
local scene = composer.newScene()

-- Функция для создания меню
local function createMenu()
    local sceneGroup = scene.view
    
    -- Заголовок игры
    local title = display.newText({
        text = "Владыка Астрала",
        x = display.contentCenterX,
        y = display.contentCenterY - 100,
        font = native.systemFontBold,
        fontSize = 36
    })
    sceneGroup:insert(title)
    
    -- Кнопка "Играть"
    local playButton = display.newRect(display.contentCenterX, display.contentCenterY, 200, 50)
    playButton:setFillColor(0.2, 0.2, 0.2)
    sceneGroup:insert(playButton)
    
    local playText = display.newText({
        text = "Играть",
        x = display.contentCenterX,
        y = display.contentCenterY,
        font = native.systemFont,
        fontSize = 24
    })
    sceneGroup:insert(playText)
    
    -- Обработчик нажатия на кнопку
    playButton:addEventListener("tap", function()
        composer.gotoScene("scenes.game", {effect = "fade", time = 300})
    end)
end

-- Обработчики событий сцены
function scene:create(event)
    createMenu()
end

function scene:show(event)
    local phase = event.phase
    
    if phase == "will" then
        -- Код выполняется перед появлением сцены
    elseif phase == "did" then
        -- Код выполняется после появления сцены
    end
end

function scene:hide(event)
    local phase = event.phase
    
    if phase == "will" then
        -- Код выполняется перед скрытием сцены
    elseif phase == "did" then
        -- Код выполняется после скрытия сцены
    end
end

function scene:destroy(event)
    -- Очистка ресурсов
end

-- Подписка на события сцены
scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene 