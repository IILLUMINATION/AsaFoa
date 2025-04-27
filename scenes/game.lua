local composer = require("composer")
local cards = require("cards")
local scene = composer.newScene()

-- Позиционирование UI элементов
local UI = {
    -- Кнопки
    endTurnButton = {
        x = display.contentWidth - 100,
        y = _Dy - _Dh / 15,
        width = 160,
        height = 70
    },
    menuButton = {
        x = display.contentWidth - 100,
        y = 50,
        width = 160,
        height = 70
    },
    
    -- Тексты состояния
    manaText = {
        x = 100,
        y = _Dy - _Dh / 10,
        fontSize = 24
    },
    playerHealthText = {
        x = 100,
        y = _Dy - _Dh / 15,
        fontSize = 28
    },
    enemyHealthText = {
        x = 100,
        y = 30,
        fontSize = 28
    },
    turnText = {
        x = display.contentCenterX,
        y = 30,
        fontSize = 32
    },
    
    -- Текст действия
    actionText = {
        x = display.contentCenterX,
        y = display.contentCenterY - 120,
        width = display.contentWidth - 60,
        fontSize = 24
    },
    
    -- Лог событий
    logText = {
        x = display.contentCenterX,
        y = _Cy + _Dh / 7,
        width = display.contentWidth - 60,
        height = 120,
        fontSize = 18
    },
    logBackground = {
        x = display.contentCenterX,
        y = _Cy + _Dh / 7,
        width = display.contentWidth - 40,
        height = 140,
        cornerRadius = 10
    },
    
    -- Карты
    card = {
        width = 100,
        height = 150,
        spacing = 15,
        fontSize = {
            name = 16,
            cost = 18,
            stats = 18,
            ability = 18
        }
    },
    
    -- Поле
    field = {
        cellWidth = 80,
        cellHeight = 100,
        spacing = 10,
        playerY = display.contentCenterY + 20,
        enemyY = display.contentCenterY - 120
    }
}

-- Локальные переменные
local playerHealth = 30
local enemyHealth = 30
local playerMana = 1
local enemyMana = 1
local maxMana = 10
local currentTurn = 1  -- 1 - ход игрока, 2 - ход противника
local isPlayerTurn = false  -- Определяется случайно в начале игры

-- Игровое поле: 5 клеток для игрока, 5 для противника
local playerField = {nil, nil, nil, nil, nil}
local enemyField = {nil, nil, nil, nil, nil}

-- Рука игрока и противника (по 4 карты)
local playerHand = {}
local enemyHand = {}

-- Колоды игрока и противника
local playerDeck = {}
local enemyDeck = {}

-- Графические элементы
local fieldCells = {}  -- Ячейки поля
local cardVisuals = {} -- Визуальные представления карт
local manaText, playerHealthText, enemyHealthText, turnText, logText, actionText

-- Переменная для выбранной карты
local selectedCardIndex = nil

-- Переменные для анимации и состояний
local animationInProgress = false
local animationQueue = {}
local sleepingCards = {} -- Карты, которые только что разыграны и спят 1 ход

-- Предварительные объявления функций, которые вызываются до их определения
local updateHandVisuals
local updateFieldVisuals
local playCard
local placeCardOnField
local endTurn
local aiTurn
local performAttacks
local checkWinCondition
local showGameOver
local createUI
local updateUI
local animateAttack
local showAction
local processAnimationQueue

-- Вспомогательная функция для создания визуального представления карты на поле
local function createCardVisualOnField(cellGroup, card, cellWidth, cellHeight)
    -- Имя карты
    local nameText = display.newText({
        parent = cellGroup,
        text = card.name,
        x = 0,
        y = -cellHeight/2 + 15,
        width = cellWidth - 10,
        font = native.systemFont,
        fontSize = 10,
        align = "center"
    })
    
    -- Атака и здоровье
    local statsText = display.newText({
        parent = cellGroup,
        text = card.attack .. "/" .. card.health,
        x = 0,
        y = 0,
        font = native.systemFontBold,
        fontSize = 14
    })
    
    -- Если карта спит, показываем индикатор
    if sleepingCards[card] then
        local sleepIndicator = display.newText({
            parent = cellGroup,
            text = "Z",
            x = cellWidth/2 - 10,
            y = -cellHeight/2 + 15,
            font = native.systemFontBold,
            fontSize = 14
        })
        sleepIndicator:setFillColor(0.7, 0.7, 1)
    end
    
    -- Сохраняем ссылку на карту и ее визуальное представление
    card.group = cellGroup
    card.x = cellGroup.x
    card.y = cellGroup.y
    
    return cellGroup
end

-- Функция добавления сообщения в лог
local function addToLog(message)
    if logText then
        -- Ограничиваем длину лога и добавляем новое сообщение
        local maxLines = 10
        local lines = {}
        for line in string.gmatch(logText.text, "[^\r\n]+") do
            table.insert(lines, line)
        end
        table.insert(lines, 1, message)
        if #lines > maxLines then
            table.remove(lines)
        end
        logText.text = table.concat(lines, "\n")
    end
    -- Дублируем в консоль с правильным форматированием
    print(string.format("[Игра] %s", message))
end

-- Инициализация игры
local function initGame()
    -- Создаем колоды
    playerDeck = cards.createDeck()
    enemyDeck = cards.createDeck()
    
    -- Раздаем начальные карты
    for i = 1, 4 do
        playerHand[i] = cards.drawCard(playerDeck)
        enemyHand[i] = cards.drawCard(enemyDeck)
    end
    
    -- Определяем случайно, кто ходит первым
    isPlayerTurn = math.random(1, 2) == 1
    if isPlayerTurn then
        currentTurn = 1
    else
        currentTurn = 2
        -- Если первый ход противника, запускаем его ход с небольшой задержкой
        timer.performWithDelay(1000, function()
            addToLog("Противник ходит первым")
            showAction("Противник начинает игру!")
            aiTurn()
            
            -- После действий противника проводим атаки
            timer.performWithDelay(2000, function()
                performAttacks()
                
                -- Проверяем условие победы после атак
                timer.performWithDelay(1000, function()
                    checkWinCondition()
                    
                    -- Передаем ход игроку
                    if playerHealth > 0 and enemyHealth > 0 then
                        isPlayerTurn = true
                        turnText.text = "Ваш ход"
                        addToLog("Ваш ход начался")
                        showAction("Ваш ход! Разыгрывайте карты")
                        updateUI()
                    end
                end)
            end)
        end)
    end
    
    -- Сбрасываем выбранную карту
    selectedCardIndex = nil
    
    -- Сбрасываем здоровье и ману
    playerHealth = 30
    enemyHealth = 30
    playerMana = 1
    enemyMana = 1
end

-- Обновление интерфейса
updateUI = function()
    manaText.text = "Мана: " .. playerMana .. "/" .. maxMana
    playerHealthText.text = "Игрок: " .. playerHealth
    enemyHealthText.text = "Враг: " .. enemyHealth
    
    if isPlayerTurn then
        turnText.text = "Ваш ход"
    else
        turnText.text = "Ход противника"
    end
    
    -- Обновление карт в руке
    updateHandVisuals()
    
    -- Обновление поля
    updateFieldVisuals()
end

-- Обновление отображения карт в руке
updateHandVisuals = function()
    -- Удаляем предыдущие визуальные элементы
    for i = 1, #cardVisuals do
        if cardVisuals[i] and cardVisuals[i].group then
            cardVisuals[i].group:removeSelf()
            cardVisuals[i].group = nil
        end
    end
    cardVisuals = {}
    
    -- Создаем новые визуальные элементы для карт в руке игрока
    local startX = display.contentCenterX - ((#playerHand * UI.card.width) + (#playerHand - 1) * UI.card.spacing) / 2 + UI.card.width / 2
    
    for i = 1, #playerHand do
        local card = playerHand[i]
        local cardGroup = display.newGroup()
        scene.view:insert(cardGroup)
        
        -- Добавляем эффект тени для карт
        local cardShadow = display.newRoundedRect(cardGroup, 3, 3, UI.card.width, UI.card.height, 8)
        cardShadow:setFillColor(0, 0, 0, 0.5)
        cardShadow:toBack()
        
        -- Фон карты
        local cardBg = display.newRoundedRect(cardGroup, 0, 0, UI.card.width, UI.card.height, 8)
        
        -- Если карта выбрана, добавляем заметную обводку и эффект выделения
        if selectedCardIndex == i then
            cardBg:setFillColor(0.8, 0.7, 0.2)
            cardBg.strokeWidth = 4
            cardBg:setStrokeColor(1, 0.8, 0)
            
            -- Добавляем эффект свечения
            local glowEffect = display.newCircle(cardGroup, 0, 0, UI.card.width * 0.7)
            glowEffect:setFillColor(1, 1, 0.5, 0.2)
            glowEffect:toBack()
            transition.to(glowEffect, {time=800, alpha=0.4, iterations=-1, transition=easing.inOutQuad})
            
            -- Эффект "парения" карты
            cardGroup.y = cardGroup.y - 15
        else
            if card.cost <= playerMana then
                cardBg:setFillColor(0.35, 0.35, 0.4)
            else
                cardBg:setFillColor(0.25, 0.25, 0.3)
            end
            
            cardBg.strokeWidth = 3
            cardBg:setStrokeColor(0.5, 0.5, 0.5)
        end
        
        -- Создаем фон для заголовка карты
        local titleBg = display.newRect(cardGroup, 0, -UI.card.height/2 + 20, UI.card.width, 40)
        titleBg:setFillColor(0.2, 0.2, 0.25)
        
        -- Имя карты
        local nameText = display.newText({
            parent = cardGroup,
            text = card.name,
            x = 0,
            y = -UI.card.height/2 + 20,
            width = UI.card.width - 15,
            font = native.systemFontBold,
            fontSize = UI.card.fontSize.name,
            align = "center"
        })
        
        -- Стоимость маны с визуальным индикатором
        local manaSymbol = display.newCircle(cardGroup, -UI.card.width/2 + 15, -UI.card.height/2 + 15, 12)
        if card.cost <= playerMana then
            manaSymbol:setFillColor(0.2, 0.6, 1)
        else
            manaSymbol:setFillColor(0.4, 0.4, 0.6)
        end
        
        local costText = display.newText({
            parent = cardGroup,
            text = card.cost,
            x = -UI.card.width/2 + 15,
            y = -UI.card.height/2 + 15,
            font = native.systemFontBold,
            fontSize = UI.card.fontSize.cost
        })
        
        -- Атака и здоровье с иконками
        local attackIcon = display.newCircle(cardGroup, -UI.card.width/4, UI.card.height/2 - 20, 12)
        attackIcon:setFillColor(0.9, 0.3, 0.3)
        
        local attackText = display.newText({
            parent = cardGroup,
            text = card.attack,
            x = -UI.card.width/4,
            y = UI.card.height/2 - 20,
            font = native.systemFontBold,
            fontSize = UI.card.fontSize.stats
        })
        
        local healthIcon = display.newCircle(cardGroup, UI.card.width/4, UI.card.height/2 - 20, 12)
        healthIcon:setFillColor(0.3, 0.9, 0.3)
        
        local healthText = display.newText({
            parent = cardGroup,
            text = card.health,
            x = UI.card.width/4,
            y = UI.card.height/2 - 20,
            font = native.systemFontBold,
            fontSize = UI.card.fontSize.stats
        })
        
        -- Добавляем иконку способности
        local abilityIcon = display.newText({
            parent = cardGroup,
            text = "✦",
            x = UI.card.width/2 - 15,
            y = -UI.card.height/2 + 15,
            font = native.systemFontBold,
            fontSize = UI.card.fontSize.ability
        })
        abilityIcon:setFillColor(1, 0.8, 0.3)
        
        cardGroup.x = startX + (i - 1) * (UI.card.width + UI.card.spacing)
        cardGroup.y = display.contentHeight - UI.card.height/2 - 30
        
        -- Добавляем обработчик нажатия на карту
        cardBg:addEventListener("tap", function(event)
            if isPlayerTurn then
                addToLog(card.name .. ": " .. card.ability)
                showAction(card.name .. " - " .. card.ability)
                
                if selectedCardIndex == i then
                    selectedCardIndex = nil
                else
                    playCard(i)
                end
                updateHandVisuals()
            end
            return true
        end)
        
        cardVisuals[i] = {
            group = cardGroup,
            card = card
        }
    end
end

-- Обновление отображения поля
updateFieldVisuals = function()
    -- Удаляем предыдущие элементы поля
    for i = 1, #fieldCells do
        if fieldCells[i] then
            fieldCells[i]:removeSelf()
            fieldCells[i] = nil
        end
    end
    fieldCells = {}
    
    local startX = display.contentCenterX - ((5 * UI.field.cellWidth) + 4 * UI.field.spacing) / 2 + UI.field.cellWidth / 2
    
    -- Создаем ячейки поля для противника (верхний ряд)
    for i = 1, 5 do
        local cellGroup = display.newGroup()
        scene.view:insert(cellGroup)
        
        local cell = display.newRect(cellGroup, 0, 0, UI.field.cellWidth, UI.field.cellHeight)
        cell:setFillColor(0.2, 0.2, 0.3)
        cell.strokeWidth = 3
        cell:setStrokeColor(0.4, 0.4, 0.5)
        
        cellGroup.x = startX + (i - 1) * (UI.field.cellWidth + UI.field.spacing)
        cellGroup.y = UI.field.enemyY
        
        fieldCells[i] = cellGroup
        
        if enemyField[i] then
            createCardVisualOnField(cellGroup, enemyField[i], UI.field.cellWidth, UI.field.cellHeight)
            fieldCells[i].card = enemyField[i]
        end
    end
    
    -- Создаем ячейки поля для игрока (нижний ряд)
    for i = 1, 5 do
        local cellGroup = display.newGroup()
        scene.view:insert(cellGroup)
        
        local cell = display.newRect(cellGroup, 0, 0, UI.field.cellWidth, UI.field.cellHeight)
        
        if selectedCardIndex and not playerField[i] and isPlayerTurn then
            cell:setFillColor(0.3, 0.5, 0.3)
        else
            cell:setFillColor(0.2, 0.3, 0.2)
        end
        
        cell.strokeWidth = 3
        cell:setStrokeColor(0.4, 0.5, 0.4)
        
        cellGroup.x = startX + (i - 1) * (UI.field.cellWidth + UI.field.spacing)
        cellGroup.y = UI.field.playerY
        
        fieldCells[i + 5] = cellGroup
        
        cell:addEventListener("tap", function(event)
            if selectedCardIndex and isPlayerTurn and not playerField[i] then
                placeCardOnField(selectedCardIndex, i)
                updateFieldVisuals()
            end
            return true
        end)
        
        if playerField[i] then
            createCardVisualOnField(cellGroup, playerField[i], UI.field.cellWidth, UI.field.cellHeight)
            fieldCells[i + 5].card = playerField[i]
            
            cell:addEventListener("tap", function(event)
                if isPlayerTurn then
                    addToLog(playerField[i].name .. ": " .. playerField[i].ability)
                    showAction(playerField[i].name .. " - " .. playerField[i].ability)
                    
                    if sleepingCards[playerField[i]] then
                        addToLog(playerField[i].name .. " спит и не может атаковать в этот ход")
                    end
                end
                return true
            end)
        end
    end
end

-- Функция разыгрывания карты из руки на поле
playCard = function(cardIndex)
    -- Если не ход игрока, то ничего не делаем
    if not isPlayerTurn then
        addToLog("Сейчас не ваш ход")
        return false
    end
    
    local card = playerHand[cardIndex]
    
    -- Проверяем, хватает ли маны
    if card.cost > playerMana then
        -- Недостаточно маны
        addToLog("Недостаточно маны: нужно " .. card.cost .. ", доступно " .. playerMana)
        return false
    end
    
    -- Помечаем карту как выбранную
    selectedCardIndex = cardIndex
    addToLog("Выбрана карта: " .. card.name)
    return true
end

-- Функция размещения карты на поле
placeCardOnField = function(cardIndex, fieldPosition)
    -- Если не ход игрока, то ничего не делаем
    if not isPlayerTurn then
        addToLog("Сейчас не ваш ход")
        return false
    end
    
    -- Если нет выбранной карты
    if not cardIndex then
        addToLog("Нет выбранной карты")
        return false
    end
    
    local card = playerHand[cardIndex]
    
    -- Проверяем, не занята ли клетка
    if playerField[fieldPosition] then
        -- Клетка уже занята
        addToLog("Клетка " .. fieldPosition .. " уже занята")
        selectedCardIndex = nil
        return false
    end
    
    addToLog("Размещаем " .. card.name .. " на позицию " .. fieldPosition)
    
    -- Размещаем карту на поле
    playerField[fieldPosition] = card
    
    -- Помечаем карту как спящую (не может атаковать в первый ход)
    if not card.berserk then -- Карты с берсерком не засыпают
        sleepingCards[card] = true
        addToLog(card.name .. " засыпает на 1 ход")
    end
    
    -- Проверяем способности карт при входе в игру
    if card.name == "Дракон" then
        -- Наносит 2 урона всем вражеским юнитам
        showAction(card.name .. " наносит 2 урона всем вражеским юнитам!")
        for i = 1, 5 do
            if enemyField[i] then
                enemyField[i].health = enemyField[i].health - 2
                if enemyField[i].health <= 0 then
                    addToLog(enemyField[i].name .. " уничтожен драконом")
                    enemyField[i] = nil
                end
            end
        end
    elseif card.name == "Призыватель" then
        -- Призывает миньона 1/1
        addToLog(card.name .. " призывает миньона")
        
        -- Ищем свободную клетку рядом
        for i = math.max(1, fieldPosition-1), math.min(5, fieldPosition+1) do
            if i ~= fieldPosition and not playerField[i] then
                playerField[i] = {
                    name = "Миньон",
                    attack = 1,
                    health = 1,
                    cost = 1,
                    ability = "Призван Призывателем"
                }
                -- Миньон тоже засыпает
                sleepingCards[playerField[i]] = true
                break
            end
        end
    elseif card.name == "Элементаль" then
        -- Усиливает соседних элементалей
        addToLog(card.name .. " усиливает соседних элементалей")
        for i = math.max(1, fieldPosition-1), math.min(5, fieldPosition+1) do
            if i ~= fieldPosition and playerField[i] and playerField[i].name == "Элементаль" then
                playerField[i].attack = playerField[i].attack + 1
                addToLog("Элементаль на позиции " .. i .. " усилен до " .. playerField[i].attack .. " атаки")
            end
        end
    end
    
    -- Уменьшаем ману
    playerMana = playerMana - card.cost
    
    -- Удаляем карту из руки
    table.remove(playerHand, cardIndex)
    
    -- Берем новую карту
    table.insert(playerHand, cards.drawCard(playerDeck))
    
    -- Сбрасываем выбранную карту
    selectedCardIndex = nil
    
    -- Обновляем интерфейс
    updateUI()
    return true
end

-- Функция передачи хода
endTurn = function()
    if isPlayerTurn then
        -- Был ход игрока, теперь ход противника
        isPlayerTurn = false
        turnText.text = "Ход противника"
        addToLog("Ход противника начался")
        
        -- Увеличиваем ману в начале хода
        local oldPlayerMana = playerMana
        local oldEnemyMana = enemyMana
        playerMana = math.min(playerMana + 1, maxMana)
        enemyMana = math.min(enemyMana + 1, maxMana)
        addToLog("Мана противника: " .. oldEnemyMana .. " → " .. enemyMana)
        
        -- Простая ИИ-стратегия для противника (с задержкой)
        aiTurn()
        
        -- После действий противника проводим атаки с задержкой
        timer.performWithDelay(3000, function()
            -- Атакуем картами на поле
            addToLog("Проводим атаки")
            performAttacks()
            
            -- Проверяем условие победы после окончания всех анимаций
            timer.performWithDelay(1000, function()
                checkWinCondition()
                
                -- После хода противника снова ход игрока
                if playerHealth > 0 and enemyHealth > 0 then
                    isPlayerTurn = true
                    turnText.text = "Ваш ход"
                    addToLog("Ваш ход начался")
                    addToLog("Мана игрока: " .. oldPlayerMana .. " → " .. playerMana)
                    showAction("Ваш ход! Разыгрывайте карты")
                    
                    -- Обновляем интерфейс
                    updateUI()
                end
            end)
        end)
    else
        -- Если функция вызвана не во время хода игрока, значит это инициализация
        -- или какой-то специальный случай - просто обновляем интерфейс
        updateUI()
    end
end

-- Функция хода ИИ
aiTurn = function()
    -- Простая стратегия: разыгрываем карты, начиная с самых дорогих, которые можем себе позволить
    addToLog("ИИ начинает ход, мана: " .. enemyMana)
    showAction("Ход противника! Противник думает...")
    
    -- Имитируем "размышления" ИИ
    timer.performWithDelay(1000, function()
        -- Сортируем карты в руке по стоимости (от большей к меньшей)
        table.sort(enemyHand, function(a, b) return a.cost > b.cost end)
        
        -- Пытаемся разыграть карты
        local cardsPlaced = 0
        local cardsToPlace = {}
        
        -- Сначала собираем все карты, которые будут размещены
        for cardIndex, card in ipairs(enemyHand) do
            -- Если хватает маны
            if card.cost <= enemyMana then
                -- Ищем свободную ячейку
                for i = 1, 5 do
                    if not enemyField[i] then
                        -- Добавляем в список для размещения
                        table.insert(cardsToPlace, {
                            cardIndex = cardIndex,
                            card = card,
                            position = i
                        })
                        enemyMana = enemyMana - card.cost
                        break
                    end
                end
            end
        end
        
        -- Теперь размещаем карты с задержкой для анимации
        local function placeNextCard(index)
            if index > #cardsToPlace then
                -- Все карты размещены
                if cardsPlaced == 0 then
                    addToLog("ИИ не смог разместить карты")
                    showAction("Противник не смог разместить карты")
                else
                    addToLog("ИИ разместил " .. cardsPlaced .. " карт")
                    showAction("Противник разместил " .. cardsPlaced .. " карт")
                end
                return
            end
            
            local placement = cardsToPlace[index]
            local card = placement.card
            local position = placement.position
            
            -- Размещаем карту
            enemyField[position] = card
            
            -- Удаляем карту из руки
            for i, handCard in ipairs(enemyHand) do
                if handCard == card then
                    table.remove(enemyHand, i)
                    break
                end
            end
            
            -- Берем новую карту
            table.insert(enemyHand, cards.drawCard(enemyDeck))
            
            -- Помечаем карту как спящую (не может атаковать в первый ход)
            if not card.berserk then -- Карты с берсерком не засыпают
                sleepingCards[card] = true
            end
            
            addToLog("ИИ размещает " .. card.name .. " на позицию " .. position)
            showAction("Противник размещает " .. card.name)
            
            -- Обновляем поле
            updateFieldVisuals()
            
            cardsPlaced = cardsPlaced + 1
            
            -- Переходим к следующей карте с задержкой
            timer.performWithDelay(800, function()
                placeNextCard(index + 1)
            end)
        end
        
        -- Начинаем размещение карт
        placeNextCard(1)
    end)
end

-- Функция проведения атак
performAttacks = function()
    -- Очищаем очередь анимаций
    animationQueue = {}
    
    -- Проверка карт, которые проснулись
    for card, _ in pairs(sleepingCards) do
        sleepingCards[card] = nil -- Удаляем все спящие карты (они просыпаются)
        addToLog(card.name .. " просыпается и готов атаковать")
    end
    
    -- Обработка атак для обоих игроков
    local function processFieldAttacks(attackerField, defenderField, isPlayer)
        for i = 1, 5 do
            local attacker = attackerField[i]
            if attacker and not sleepingCards[attacker] then
                local target = defenderField[i]
                
                if target then
                    -- Карта атакует карту напротив
                    table.insert(animationQueue, function(callback)
                        -- Логируем атаку
                        addToLog(attacker.name .. " (" .. attacker.attack .. ") атакует " .. target.name .. " (" .. target.health .. ")")
                        
                        -- Анимируем атаку
                        animateAttack(attacker, target, attacker.attack, false, function()
                            -- Наносим урон
                            target.health = target.health - attacker.attack
                            attacker.health = attacker.health - target.attack
                            
                            -- Проверяем, уничтожены ли карты
                            if target.health <= 0 then
                                destroyCard(target, defenderField, i)
                            else
                                updateCardHealth(target)
                            end
                            
                            if attacker.health <= 0 then
                                destroyCard(attacker, attackerField, i)
                            else
                                updateCardHealth(attacker)
                                
                                -- Применяем особые эффекты
                                if attacker.name == "Вампир" then
                                    -- Вампиризм: восстанавливает здоровье равное урону
                                    local healing = attacker.attack
                                    attacker.health = attacker.health + healing
                                    updateCardHealth(attacker)
                                    addToLog(attacker.name .. " восстанавливает " .. healing .. " здоровья")
                                    showAction(attacker.name .. " восстанавливает " .. healing .. " здоровья")
                                end
                            end
                            
                            if callback then callback() end
                        end)
                    end)
                else
                    -- Карта атакует героя напрямую
                    local targetHealth = isPlayer and enemyHealth or playerHealth
                    local healthRef = isPlayer and "enemyHealth" or "playerHealth"
                    
                    table.insert(animationQueue, function(callback)
                        local targetPos = {
                            x = display.contentCenterX,
                            y = isPlayer and 50 or display.contentHeight - 50
                        }
                        
                        addToLog(attacker.name .. " атакует героя напрямую на " .. attacker.attack)
                        animateAttack(attacker, targetPos, attacker.attack, true, function()
                            -- Наносим урон
                            if isPlayer then
                                enemyHealth = enemyHealth - attacker.attack
                            else
                                playerHealth = playerHealth - attacker.attack
                            end
                            
                            if callback then callback() end
                        end)
                    end)
                end
            end
        end
    end
    
    -- Обрабатываем атаки игрока и противника
    processFieldAttacks(playerField, enemyField, true)
    processFieldAttacks(enemyField, playerField, false)
    
    -- Запускаем анимации
    timer.performWithDelay(100, processAnimationQueue)
end

-- Проверка условий победы или поражения
checkWinCondition = function()
    if playerHealth <= 0 then
        -- Игрок проиграл
        endGame("defeat")
        return true
    elseif enemyHealth <= 0 then
        -- Игрок победил
        endGame("victory")
        return true
    end
    return false -- Игра продолжается
end

-- Функция завершения игры
endGame = function(result)
    -- Блокируем взаимодействие
    local isGameOver = true
    
    -- Создаем затемнение
    local overlay = display.newRect(scene.view, display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)
    overlay:setFillColor(0, 0, 0, 0.7)
    
    -- Создаем текст результата
    local resultText
    if result == "victory" then
        resultText = "Победа!"
        -- Здесь должен быть звук победы, если есть
        if soundEffects and soundEffects.victory then
            audio.play(soundEffects.victory)
        end
    else
        resultText = "Поражение!"
        -- Здесь должен быть звук поражения, если есть
        if soundEffects and soundEffects.defeat then
            audio.play(soundEffects.defeat)
        end
    end
    
    local gameOverText = display.newText({
        parent = scene.view,
        text = resultText,
        x = display.contentCenterX,
        y = display.contentCenterY - 50,
        font = native.systemFontBold,
        fontSize = 48
    })
    gameOverText:setFillColor(1, 1, 1)
    
    -- Кнопка возврата в меню
    local menuButton = display.newRoundedRect(scene.view, display.contentCenterX, display.contentCenterY + 50, 200, 60, 10)
    menuButton:setFillColor(0.3, 0.3, 0.8)
    
    local menuButtonText = display.newText({
        parent = scene.view,
        text = "В главное меню",
        x = display.contentCenterX,
        y = display.contentCenterY + 50,
        font = native.systemFont,
        fontSize = 22
    })
    menuButtonText:setFillColor(1, 1, 1)
    
    -- Обработчик нажатия на кнопку
    menuButton:addEventListener("tap", function()
        if soundEffects and soundEffects.button then
            audio.play(soundEffects.button)
        end
        composer.gotoScene("scenes.menu", {effect = "fade", time = 300})
    end)
    
    -- Добавляем небольшую анимацию для экрана завершения
    overlay.alpha = 0
    gameOverText.xScale = 0.5
    gameOverText.yScale = 0.5
    menuButton.alpha = 0
    menuButtonText.alpha = 0
    
    -- Анимация появления
    transition.to(overlay, {time = 300, alpha = 0.7})
    transition.to(gameOverText, {time = 400, xScale = 1, yScale = 1, delay = 200})
    transition.to(menuButton, {time = 300, alpha = 1, delay = 400})
    transition.to(menuButtonText, {time = 300, alpha = 1, delay = 400})
    
    -- Логируем результат игры
    addToLog("Игра завершена: " .. resultText)
end

-- Создание интерфейса
createUI = function()
    local sceneGroup = scene.view
    
    -- Кнопка завершения хода
    local endTurnButton = display.newRect(
        sceneGroup,
        UI.endTurnButton.x,
        UI.endTurnButton.y,
        UI.endTurnButton.width,
        UI.endTurnButton.height
    )
    endTurnButton:setFillColor(0.3, 0.5, 0.3)
    endTurnButton.strokeWidth = 3
    endTurnButton:setStrokeColor(0.5, 0.8, 0.5)
    
    local endTurnText = display.newText({
        parent = sceneGroup,
        text = "Конец хода",
        x = UI.endTurnButton.x,
        y = UI.endTurnButton.y,
        font = native.systemFontBold,
        fontSize = UI.endTurnButton.fontSize or 24
    })
    
    -- Кнопка выхода в меню
    local menuButton = display.newRect(
        sceneGroup,
        UI.menuButton.x,
        UI.menuButton.y,
        UI.menuButton.width,
        UI.menuButton.height
    )
    menuButton:setFillColor(0.5, 0.3, 0.3)
    menuButton.strokeWidth = 3
    menuButton:setStrokeColor(0.8, 0.5, 0.5)
    
    local menuButtonText = display.newText({
        parent = sceneGroup,
        text = "В меню",
        x = UI.menuButton.x,
        y = UI.menuButton.y,
        font = native.systemFontBold,
        fontSize = UI.menuButton.fontSize or 24
    })
    
    -- Обработчик нажатия на кнопку меню
    menuButton:addEventListener("tap", function(event)
        if soundEffects and soundEffects.button then
            audio.play(soundEffects.button)
        end
        -- Завершаем игру с поражением
        endGame("defeat")
        return true
    end)
    
    -- Обработчик нажатия на кнопку
    endTurnButton:addEventListener("tap", function(event)
        if isPlayerTurn and not animationInProgress then
            addToLog("Конец хода игрока")
            -- Эффект нажатия
            transition.to(endTurnButton, {time=100, xScale=0.95, yScale=0.95, onComplete=function()
                transition.to(endTurnButton, {time=100, xScale=1, yScale=1})
                endTurn()
            end})
        end
        return true
    end)
    
    -- Текст с информацией о мане
    manaText = display.newText({
        parent = sceneGroup,
        text = "Мана: 1/10",
        x = UI.manaText.x,
        y = UI.manaText.y,
        font = native.systemFontBold,
        fontSize = UI.manaText.fontSize
    })
    manaText:setFillColor(0.2, 0.6, 0.9)
    
    -- Текст с информацией о здоровье игрока
    playerHealthText = display.newText({
        parent = sceneGroup,
        text = "Игрок: 30",
        x = UI.playerHealthText.x,
        y = UI.playerHealthText.y,
        font = native.systemFontBold,
        fontSize = UI.playerHealthText.fontSize
    })
    playerHealthText:setFillColor(0.2, 0.9, 0.3)
    
    -- Текст с информацией о здоровье противника
    enemyHealthText = display.newText({
        parent = sceneGroup,
        text = "Враг: 30",
        x = UI.enemyHealthText.x,
        y = UI.enemyHealthText.y,
        font = native.systemFontBold,
        fontSize = UI.enemyHealthText.fontSize
    })
    enemyHealthText:setFillColor(0.9, 0.3, 0.2)
    
    -- Текст с информацией о текущем ходе
    turnText = display.newText({
        parent = sceneGroup,
        text = "Ваш ход",
        x = UI.turnText.x,
        y = UI.turnText.y,
        font = native.systemFontBold,
        fontSize = UI.turnText.fontSize
    })
    turnText:setFillColor(1, 0.9, 0.4)
    
    -- Текст действия (анимируемый)
    actionText = display.newText({
        parent = sceneGroup,
        text = "",
        x = UI.actionText.x,
        y = UI.actionText.y,
        width = UI.actionText.width,
        font = native.systemFontBold,
        fontSize = UI.actionText.fontSize,
        align = "center"
    })
    actionText:setFillColor(1, 0.8, 0)
    actionText.alpha = 0 -- Изначально скрыт
    
    -- Лог событий
    logText = display.newText({
        parent = sceneGroup,
        text = "Игра началась",
        x = UI.logText.x,
        y = UI.logText.y,
        width = UI.logText.width,
        height = UI.logText.height,
        font = native.systemFont,
        fontSize = UI.logText.fontSize,
        align = "left"
    })
    logText:setFillColor(0.9, 0.9, 0.9)
    
    -- Добавляем фоновую подложку для лога
    local logBackground = display.newRoundedRect(
        sceneGroup,
        UI.logBackground.x,
        UI.logBackground.y,
        UI.logBackground.width,
        UI.logBackground.height,
        UI.logBackground.cornerRadius
    )
    logBackground:setFillColor(0.1, 0.1, 0.1, 0.6)
    logBackground:toBack()
end

-- Обработчики событий сцены
function scene:create(event)
    local sceneGroup = self.view
    
    -- Создание интерфейса
    createUI()
    
    -- Инициализация игры
    initGame()
    
    -- Обновление интерфейса
    updateUI()
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

-- Функция анимации атаки
animateAttack = function(attacker, defender, damage, isHero, callback)
    -- Создаем временное визуальное представление для анимации
    local attackVisual = display.newCircle(scene.view, attacker.x, attacker.y, 10)
    attackVisual:setFillColor(1, 0, 0, 0.7) -- Красный шар
    
    -- Назначение конечной точки анимации
    local targetX, targetY
    if isHero then
        if attacker.y < display.contentCenterY then -- Если атакующий сверху (враг)
            targetX = defender.x
            targetY = display.contentHeight - 50 -- Нижняя часть экрана (игрок)
        else
            targetX = defender.x
            targetY = 50 -- Верхняя часть экрана (враг)
        end
    else
        targetX = defender.x
        targetY = defender.y
    end
    
    -- Анимируем движение
    transition.to(attackVisual, {
        time = 300,
        x = targetX,
        y = targetY,
        onComplete = function()
            -- Показываем урон
            local damageText = display.newText({
                parent = scene.view,
                text = "-" .. damage,
                x = targetX,
                y = targetY,
                font = native.systemFontBold,
                fontSize = 20
            })
            damageText:setFillColor(1, 0, 0)
            
            -- Анимируем текст урона
            transition.to(damageText, {
                time = 500,
                y = targetY - 30,
                alpha = 0,
                onComplete = function()
                    damageText:removeSelf()
                    attackVisual:removeSelf()
                    
                    -- Вызываем callback, если он предоставлен
                    if callback then
                        callback()
                    end
                end
            })
            
            -- Добавляем анимацию тряски для цели
            if not isHero and defender.group then
                local originalX = defender.group.x
                local originalY = defender.group.y
                
                local function shake()
                    defender.group.x = originalX + math.random(-5, 5)
                    defender.group.y = originalY + math.random(-5, 5)
                end
                
                -- Применяем тряску несколько раз
                timer.performWithDelay(30, shake, 5)
                
                -- Возвращаем в исходное положение
                timer.performWithDelay(200, function()
                    defender.group.x = originalX
                    defender.group.y = originalY
                end)
            end
        end
    })
    
    -- Показываем описание действия
    showAction(attacker.name .. " атакует " .. (isHero and "героя" or defender.name) .. " и наносит " .. damage .. " урона!")
end

-- Функция для отображения текста действия
showAction = function(text)
    if actionText then
        actionText.text = text
        actionText.alpha = 1
        
        -- Анимируем появление и исчезновение текста
        transition.to(actionText, {
            delay = 2000, -- Задержка перед исчезновением
            time = 500,
            alpha = 0
        })
        
        -- Дублируем в консоль
        print(string.format("[Действие] %s", text))
    end
end

-- Универсальная функция атаки
attack = function(attackerCol, targetCol, targetType)
    local attacker = playerField[attackerCol]
    
    if not attacker then
        addToLog("Ошибка: атакующая карта не найдена")
        return false
    end
    
    -- Проверка на ход игрока
    if not isPlayerTurn then
        addToLog("Сейчас не ваш ход")
        return false
    end
    
    -- Проверка на возможность атаки
    if sleepingCards[attacker] then
        addToLog(attacker.name .. " спит и не может атаковать в этом ходу")
        return false
    end
    
    -- Сохраняем исходные координаты атакующей карты
    local originalX = attacker.x
    local originalY = attacker.y
    
    -- Определяем цель атаки
    if targetType == "hero" then
        -- Атака по герою
        local targetY = 50 -- Верхняя часть экрана (враг)
        
        -- Создаем анимацию атаки в очереди
        table.insert(animationQueue, function(callback)
            addToLog(attacker.name .. " атакует героя противника на " .. attacker.attack)
            
            -- Анимация движения к цели
            local attackEffect = display.newCircle(scene.view, originalX, originalY, 15)
            attackEffect:setFillColor(1, 0.3, 0.3, 0.8)
            
            transition.to(attackEffect, {
                time = 300,
                x = display.contentCenterX,
                y = targetY,
                onComplete = function()
                    -- Применение урона после завершения анимации
                    local damage = attacker.attack
                    enemyHealth = enemyHealth - damage
                    
                    -- Эффект удара
                    local impactEffect = display.newCircle(scene.view, display.contentCenterX, targetY, 25)
                    impactEffect:setFillColor(1, 0, 0, 0.6)
                    
                    transition.to(impactEffect, {
                        time = 200,
                        alpha = 0,
                        xScale = 2,
                        yScale = 2,
                        onComplete = function()
                            impactEffect:removeSelf()
                            attackEffect:removeSelf()
                            
                            -- Обновляем отображение здоровья
                            updateHealthDisplay()
                            
                            -- Проверка победы
                            checkWinCondition()
                            
                            if callback then callback() end
                        end
                    })
                end
            })
        end)
    else
        -- Атака по карте
        local target = enemyField[targetCol]
        
        if not target then
            addToLog("Ошибка: цель атаки не найдена")
            return false
        end
        
        -- Получаем координаты цели
        local targetX = target.x
        local targetY = target.y
        
        -- Логируем атаку
        addToLog(attacker.name .. " атакует " .. target.name)
        
        -- Создаем анимацию атаки в очереди
        table.insert(animationQueue, function(callback)
            -- Анимация атаки
            local attackEffect = display.newCircle(scene.view, originalX, originalY, 15)
            attackEffect:setFillColor(1, 0.3, 0.3, 0.8)
            
            transition.to(attackEffect, {
                time = 300,
                x = targetX,
                y = targetY,
                onComplete = function()
                    -- Эффект удара
                    local impactEffect = display.newCircle(scene.view, targetX, targetY, 25)
                    impactEffect:setFillColor(1, 0, 0, 0.6)
                    
                    transition.to(impactEffect, {
                        time = 200,
                        alpha = 0,
                        xScale = 2,
                        yScale = 2,
                        onComplete = function()
                            impactEffect:removeSelf()
                            attackEffect:removeSelf()
                            
                            -- Применение урона
                            target.health = target.health - attacker.attack
                            attacker.health = attacker.health - target.attack
                            
                            -- Обновляем отображение здоровья
                            updateCardHealth(attacker)
                            updateCardHealth(target)
                            
                            -- Проверка на уничтожение
                            if target.health <= 0 then
                                destroyCard(target, enemyField, targetCol)
                            end
                            
                            if attacker.health <= 0 then
                                destroyCard(attacker, playerField, attackerCol)
                            end
                            
                            -- Проверка победы
                            checkWinCondition()
                            
                            if callback then callback() end
                        end
                    })
                end
            })
        end)
    end
    
    -- Запускаем анимации, если они не запущены
    if not animationInProgress then
        processAnimationQueue()
    end
    
    return true
end

-- Обновление отображения здоровья игроков
updateHealthDisplay = function()
    if playerHealthText then
        playerHealthText.text = "Здоровье: " .. playerHealth
    end
    
    if enemyHealthText then
        enemyHealthText.text = "Здоровье: " .. enemyHealth
    end
end

-- Функция обработки очереди анимаций
processAnimationQueue = function()
    -- Если очередь пуста или уже идет анимация, выходим
    if #animationQueue == 0 or animationInProgress then
        return
    end
    
    -- Устанавливаем флаг, что анимация в процессе
    animationInProgress = true
    
    -- Получаем первую анимацию из очереди
    local currentAnimation = table.remove(animationQueue, 1)
    
    -- Запускаем анимацию с колбэком, который вызовет следующую анимацию
    currentAnimation(function()
        -- Когда анимация завершена, снимаем флаг
        animationInProgress = false
        -- И запускаем следующую анимацию, если она есть
        if #animationQueue > 0 then
            timer.performWithDelay(200, processAnimationQueue)
        end
    end)
end

-- Обновление отображения здоровья карты
updateCardHealth = function(card)
    -- Ищем визуальное представление карты
    if card and card.group then
        -- Находим текст здоровья в группе
        for i = 1, card.group.numChildren do
            local child = card.group[i]
            if child.text and string.find(child.text, "/") then
                -- Обновляем текст с атакой и здоровьем
                child.text = card.attack .. "/" .. card.health
                break
            end
        end
    end
end

-- Уничтожение карты
destroyCard = function(card, field, position)
    addToLog(card.name .. " уничтожен")
    
    -- Если карта имеет визуальное представление, анимируем уничтожение
    if card.group then
        -- Сохраняем ссылку на ячейку поля
        local cellGroup = fieldCells[position + (field == playerField and 5 or 0)]
        
        -- Анимируем уничтожение карты
        transition.to(card.group, {
            time = 300,
            alpha = 0,
            xScale = 0.5,
            yScale = 0.5,
            onComplete = function()
                card.group:removeSelf()
                card.group = nil
                -- Удаляем карту из поля, но сохраняем ячейку
                field[position] = nil
                
                -- Обновляем отображение поля
                updateFieldVisuals()
            end
        })
    else
        -- Если нет визуального представления, просто удаляем карту
        field[position] = nil
        -- Обновляем отображение поля
        updateFieldVisuals()
    end
    
    -- Применяем особые эффекты при гибели
    if card.name == "Жрец Тьмы" then
        -- Добавляем урон игроку при гибели
        local damage = 2
        playerHealth = playerHealth - damage
        addToLog("Жрец Тьмы наносит " .. damage .. " урона вашему герою при гибели")
        showAction("Жрец Тьмы наносит " .. damage .. " урона вашему герою!")
    end
end

return scene 