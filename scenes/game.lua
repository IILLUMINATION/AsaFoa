local composer = require("composer")
local cards = require("cards")
local scene = composer.newScene()

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

-- Функция добавления сообщения в лог
local function addToLog(message)
    if logText then
        logText.text = message .. "\n" .. string.sub(logText.text, 1, 100) -- Ограничиваем длину лога
    end
    print(message) -- Дублируем в консоль
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
        -- Если первый ход противника, сразу выполняем его
        endTurn()
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
    local cardWidth = 80 -- Увеличиваем размер карт
    local cardHeight = 125
    local spacing = 10
    local startX = display.contentCenterX - ((#playerHand * cardWidth) + (#playerHand - 1) * spacing) / 2 + cardWidth / 2
    
    for i = 1, #playerHand do
        local card = playerHand[i]
        local cardGroup = display.newGroup()
        scene.view:insert(cardGroup)
        
        -- Добавляем эффект тени для карт
        local cardShadow = display.newRoundedRect(cardGroup, 3, 3, cardWidth, cardHeight, 6)
        cardShadow:setFillColor(0, 0, 0, 0.5)
        cardShadow:toBack()
        
        -- Фон карты
        local cardBg = display.newRoundedRect(cardGroup, 0, 0, cardWidth, cardHeight, 6)
        
        -- Если карта выбрана, добавляем заметную обводку и эффект выделения
        if selectedCardIndex == i then
            cardBg:setFillColor(0.8, 0.7, 0.2) -- Яркий оттенок для выбранной карты
            cardBg.strokeWidth = 3
            cardBg:setStrokeColor(1, 0.8, 0)
            
            -- Добавляем эффект свечения
            local glowEffect = display.newCircle(cardGroup, 0, 0, cardWidth * 0.7)
            glowEffect:setFillColor(1, 1, 0.5, 0.2)
            glowEffect:toBack()
            transition.to(glowEffect, {time=800, alpha=0.4, iterations=-1, transition=easing.inOutQuad})
            
            -- Эффект "парения" карты
            cardGroup.y = cardGroup.y - 10
        else
            -- Нормальный цвет для неактивных карт
            if card.cost <= playerMana then
                cardBg:setFillColor(0.35, 0.35, 0.4) -- Карта доступна для игры
            else
                cardBg:setFillColor(0.25, 0.25, 0.3) -- Карта недоступна из-за маны
            end
            
            cardBg.strokeWidth = 2
            cardBg:setStrokeColor(0.5, 0.5, 0.5)
        end
        
        -- Создаем фон для заголовка карты
        local titleBg = display.newRect(cardGroup, 0, -cardHeight/2 + 15, cardWidth, 30)
        titleBg:setFillColor(0.2, 0.2, 0.25)
        
        -- Имя карты
        local nameText = display.newText({
            parent = cardGroup,
            text = card.name,
            x = 0,
            y = -cardHeight/2 + 15,
            width = cardWidth - 10,
            font = native.systemFontBold,
            fontSize = 12,
            align = "center"
        })
        
        -- Стоимость маны с визуальным индикатором
        local manaSymbol = display.newCircle(cardGroup, -cardWidth/2 + 12, -cardHeight/2 + 12, 10)
        if card.cost <= playerMana then
            manaSymbol:setFillColor(0.2, 0.6, 1)
        else
            manaSymbol:setFillColor(0.4, 0.4, 0.6)
        end
        
        local costText = display.newText({
            parent = cardGroup,
            text = card.cost,
            x = -cardWidth/2 + 12,
            y = -cardHeight/2 + 12,
            font = native.systemFontBold,
            fontSize = 14
        })
        
        -- Атака и здоровье с иконками
        local attackIcon = display.newCircle(cardGroup, -cardWidth/4, cardHeight/2 - 15, 10)
        attackIcon:setFillColor(0.9, 0.3, 0.3)
        
        local attackText = display.newText({
            parent = cardGroup,
            text = card.attack,
            x = -cardWidth/4,
            y = cardHeight/2 - 15,
            font = native.systemFontBold,
            fontSize = 14
        })
        
        local healthIcon = display.newCircle(cardGroup, cardWidth/4, cardHeight/2 - 15, 10)
        healthIcon:setFillColor(0.3, 0.9, 0.3)
        
        local healthText = display.newText({
            parent = cardGroup,
            text = card.health,
            x = cardWidth/4,
            y = cardHeight/2 - 15,
            font = native.systemFontBold,
            fontSize = 14
        })
        
        -- Добавляем иконку способности
        local abilityIcon = display.newText({
            parent = cardGroup,
            text = "✦",
            x = cardWidth/2 - 10,
            y = -cardHeight/2 + 12,
            font = native.systemFontBold,
            fontSize = 14
        })
        abilityIcon:setFillColor(1, 0.8, 0.3)
        
        cardGroup.x = startX + (i - 1) * (cardWidth + spacing)
        cardGroup.y = display.contentHeight - cardHeight/2 - 20
        
        -- Добавляем обработчик нажатия на карту
        cardBg:addEventListener("tap", function(event)
            if isPlayerTurn then
                -- Показываем описание способности карты в логе
                addToLog(card.name .. ": " .. card.ability)
                showAction(card.name .. " - " .. card.ability)
                
                if selectedCardIndex == i then
                    -- Если карта уже выбрана, отменяем выбор
                    selectedCardIndex = nil
                else
                    -- Иначе выбираем эту карту
                    playCard(i)
                end
                updateHandVisuals() -- Обновляем отображение руки для подсветки выбранной карты
            end
            return true
        end)
        
        -- Сохраняем ссылку на группу
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
    
    local cellWidth = 65  -- Уменьшаем ячейки
    local cellHeight = 85
    local spacing = 8
    local startX = display.contentCenterX - ((5 * cellWidth) + 4 * spacing) / 2 + cellWidth / 2
    
    -- Создаем ячейки поля для противника (верхний ряд)
    for i = 1, 5 do
        local cellGroup = display.newGroup()
        scene.view:insert(cellGroup)
        
        local cell = display.newRect(cellGroup, 0, 0, cellWidth, cellHeight)
        cell:setFillColor(0.2, 0.2, 0.3)
        cell.strokeWidth = 2
        cell:setStrokeColor(0.4, 0.4, 0.5)
        
        cellGroup.x = startX + (i - 1) * (cellWidth + spacing)
        cellGroup.y = display.contentCenterY - cellHeight - 10
        
        fieldCells[i] = cellGroup
        
        -- Если в этой ячейке есть карта, отображаем ее
        if enemyField[i] then
            local card = enemyField[i]
            
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
            fieldCells[i].card = card
            card.group = cellGroup
            card.x = cellGroup.x
            card.y = cellGroup.y
        end
    end
    
    -- Создаем ячейки поля для игрока (нижний ряд)
    for i = 1, 5 do
        local cellGroup = display.newGroup()
        scene.view:insert(cellGroup)
        
        local cell = display.newRect(cellGroup, 0, 0, cellWidth, cellHeight)
        
        -- Если выбрана карта и ячейка свободна, подсвечиваем ее как доступную для размещения
        if selectedCardIndex and not playerField[i] and isPlayerTurn then
            cell:setFillColor(0.3, 0.5, 0.3) -- Зеленоватый цвет для доступных ячеек
        else
            cell:setFillColor(0.2, 0.3, 0.2)
        end
        
        cell.strokeWidth = 2
        cell:setStrokeColor(0.4, 0.5, 0.4)
        
        cellGroup.x = startX + (i - 1) * (cellWidth + spacing)
        cellGroup.y = display.contentCenterY + 10
        
        fieldCells[i + 5] = cellGroup
        
        -- Добавляем обработчик нажатия на ячейку
        cell:addEventListener("tap", function(event)
            if selectedCardIndex and isPlayerTurn and not playerField[i] then
                placeCardOnField(selectedCardIndex, i)
                -- Обновляем отображение поля и руки
                updateFieldVisuals()
            end
            return true
        end)
        
        -- Если в этой ячейке есть карта, отображаем ее
        if playerField[i] then
            local card = playerField[i]
            
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
            fieldCells[i + 5].card = card
            card.group = cellGroup
            card.x = cellGroup.x
            card.y = cellGroup.y
            
            -- Добавляем обработчик нажатия на карту
            cell:addEventListener("tap", function(event)
                if isPlayerTurn then
                    -- Показываем информацию о карте при клике на нее
                    addToLog(card.name .. ": " .. card.ability)
                    showAction(card.name .. " - " .. card.ability)
                    
                    if sleepingCards[card] then
                        addToLog(card.name .. " спит и не может атаковать в этот ход")
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
    
    -- Функция для добавления атаки в очередь
    local function queueAttack(attacker, defender, isHero, i)
        table.insert(animationQueue, function(callback)
            if isHero then
                local target = (attacker.y < display.contentCenterY) and {x = display.contentCenterX, y = display.contentHeight - 50} or {x = display.contentCenterX, y = 50}
                
                if attacker.y < display.contentCenterY then
                    -- Враг атакует игрока
                    addToLog(attacker.name .. " атакует вашего героя на " .. attacker.attack)
                else
                    -- Игрок атакует врага
                    addToLog(attacker.name .. " атакует героя противника на " .. attacker.attack)
                end
                
                animateAttack(attacker, target, attacker.attack, true, callback)
            else
                addToLog(attacker.name .. " (" .. attacker.attack .. ") атакует " .. defender.name .. " (" .. defender.health .. ")")
                animateAttack(attacker, defender, attacker.attack, false, callback)
            end
        end)
    end
    
    -- Функция для добавления уничтожения карты в очередь
    local function queueDestruction(card, position, isPlayer)
        table.insert(animationQueue, function(callback)
            addToLog(card.name .. " уничтожен")
            showAction(card.name .. " уничтожен!")
            
            -- Анимация уничтожения
            local cardGroup = card.group
            if cardGroup then
                transition.to(cardGroup, {
                    time = 300,
                    alpha = 0,
                    xScale = 0.5,
                    yScale = 0.5,
                    onComplete = function()
                        -- Удаляем карту из поля
                        if isPlayer then
                            playerField[position] = nil
                        else
                            enemyField[position] = nil
                        end
                        
                        if callback then
                            callback()
                        end
                    end
                })
            else
                -- Если нет визуального представления, просто удаляем карту
                if isPlayer then
                    playerField[position] = nil
                else
                    enemyField[position] = nil
                end
                
                if callback then
                    callback()
                end
            end
        end)
    end
    
    -- Проверка карт, которые проснулись
    for card, _ in pairs(sleepingCards) do
        sleepingCards[card] = nil -- Удаляем все спящие карты (они просыпаются)
        addToLog(card.name .. " просыпается и готов атаковать")
    end
    
    -- Атаки карт игрока
    for i = 1, 5 do
        if playerField[i] then
            local attackerCard = playerField[i]
            
            -- Проверяем, не спит ли карта
            if not sleepingCards[attackerCard] then
                -- Если напротив есть карта противника, атакуем ее
                if enemyField[i] then
                    local defenderCard = enemyField[i]
                    
                    -- Добавляем анимацию атаки в очередь
                    queueAttack(attackerCard, defenderCard, false, i)
                    
                    -- Наносим урон (но не удаляем карту сразу)
                    defenderCard.health = defenderCard.health - attackerCard.attack
                    attackerCard.health = attackerCard.health - defenderCard.attack
                    
                    -- Проверяем, уничтожена ли карта противника
                    if defenderCard.health <= 0 then
                        queueDestruction(defenderCard, i, false)
                    end
                    
                    -- Проверяем, уничтожена ли карта игрока
                    if attackerCard.health <= 0 then
                        queueDestruction(attackerCard, i, true)
                    end
                    
                    -- Применяем особые эффекты
                    if attackerCard.name == "Вампир" and attackerCard.health > 0 then
                        -- Вампиризм: восстанавливает здоровье равное урону
                        local healing = attackerCard.attack
                        table.insert(animationQueue, function(callback)
                            addToLog(attackerCard.name .. " восстанавливает " .. healing .. " здоровья")
                            showAction(attackerCard.name .. " восстанавливает " .. healing .. " здоровья")
                            
                            -- Анимация исцеления
                            local healVisual = display.newCircle(scene.view, attackerCard.x, attackerCard.y, 15)
                            healVisual:setFillColor(0, 1, 0, 0.5) -- Зеленый круг
                            
                            transition.to(healVisual, {
                                time = 500,
                                alpha = 0,
                                xScale = 2,
                                yScale = 2,
                                onComplete = function()
                                    healVisual:removeSelf()
                                    if callback then callback() end
                                end
                            })
                            
                            attackerCard.health = attackerCard.health + healing
                        end)
                    end
                    
                    if defenderCard.name == "Жрец Тьмы" and defenderCard.health <= 0 then
                        -- При уничтожении наносит урон герою противника
                        table.insert(animationQueue, function(callback)
                            local damage = 2
                            addToLog("Жрец Тьмы наносит " .. damage .. " урона вашему герою при гибели")
                            showAction("Жрец Тьмы наносит " .. damage .. " урона вашему герою!")
                            
                            playerHealth = playerHealth - damage
                            
                            -- Анимация урона
                            local damageText = display.newText({
                                parent = scene.view,
                                text = "-" .. damage,
                                x = display.contentCenterX,
                                y = display.contentHeight - 50,
                                font = native.systemFontBold,
                                fontSize = 24
                            })
                            damageText:setFillColor(1, 0, 0)
                            
                            transition.to(damageText, {
                                time = 500,
                                y = damageText.y - 30,
                                alpha = 0,
                                onComplete = function()
                                    damageText:removeSelf()
                                    if callback then callback() end
                                end
                            })
                        end)
                    end
                else
                    -- Если напротив нет карты, атакуем героя противника
                    queueAttack(attackerCard, nil, true, i)
                    enemyHealth = enemyHealth - attackerCard.attack
                end
            end
        end
    end
    
    -- Атаки карт противника (те, которые не были атакованы)
    for i = 1, 5 do
        if enemyField[i] and not sleepingCards[enemyField[i]] then
            local attackerCard = enemyField[i]
            
            -- Если напротив есть карта игрока, пропускаем (урон уже был нанесен)
            if not playerField[i] then
                -- Если напротив нет карты, атакуем героя игрока
                queueAttack(attackerCard, nil, true, i)
                playerHealth = playerHealth - attackerCard.attack
            end
        end
    end
    
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
    
    -- Увеличиваем размеры элементов
    local scale = 1.1 -- Больший масштаб элементов
    
    -- Кнопка завершения хода
    local endTurnButton = display.newRect(
        sceneGroup,
        display.contentWidth - 70,
        display.contentCenterY,
        120,
        50
    )
    endTurnButton:setFillColor(0.3, 0.5, 0.3)
    endTurnButton.strokeWidth = 2
    endTurnButton:setStrokeColor(0.5, 0.8, 0.5)
    
    local endTurnText = display.newText({
        parent = sceneGroup,
        text = "Конец хода",
        x = display.contentWidth - 70,
        y = display.contentCenterY,
        font = native.systemFontBold,
        fontSize = 18
    })
    
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
        x = 70,
        y = display.contentHeight - 50 * scale,
        font = native.systemFontBold,
        fontSize = 18
    })
    manaText:setFillColor(0.2, 0.6, 0.9)
    
    -- Текст с информацией о здоровье игрока
    playerHealthText = display.newText({
        parent = sceneGroup,
        text = "Игрок: 30",
        x = 70,
        y = display.contentHeight - 25 * scale,
        font = native.systemFontBold,
        fontSize = 20
    })
    playerHealthText:setFillColor(0.2, 0.9, 0.3)
    
    -- Текст с информацией о здоровье противника
    enemyHealthText = display.newText({
        parent = sceneGroup,
        text = "Враг: 30",
        x = 70,
        y = 25 * scale,
        font = native.systemFontBold,
        fontSize = 20
    })
    enemyHealthText:setFillColor(0.9, 0.3, 0.2)
    
    -- Текст с информацией о текущем ходе
    turnText = display.newText({
        parent = sceneGroup,
        text = "Ваш ход",
        x = display.contentCenterX,
        y = 25 * scale,
        font = native.systemFontBold,
        fontSize = 24
    })
    turnText:setFillColor(1, 0.9, 0.4)
    
    -- Текст действия (анимируемый)
    actionText = display.newText({
        parent = sceneGroup,
        text = "",
        x = display.contentCenterX,
        y = display.contentCenterY - 100,
        width = display.contentWidth - 40,
        font = native.systemFontBold,
        fontSize = 18,
        align = "center"
    })
    actionText:setFillColor(1, 0.8, 0)
    actionText.alpha = 0 -- Изначально скрыт
    
    -- Лог событий
    logText = display.newText({
        parent = sceneGroup,
        text = "Игра началась",
        x = display.contentCenterX,
        y = display.contentHeight - 180 * scale,
        width = display.contentWidth - 40,
        height = 100,
        font = native.systemFont,
        fontSize = 14,
        align = "left"
    })
    logText:setFillColor(0.9, 0.9, 0.9)
    
    -- Добавляем фоновую подложку для лога
    local logBackground = display.newRoundedRect(
        sceneGroup,
        display.contentCenterX,
        display.contentHeight - 180 * scale,
        display.contentWidth - 20,
        110,
        8
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
    end
end

-- Функция атаки между картами
attack = function(attackerCol, targetCol)
    local attacker = playerField[attackerCol]
    local target = enemyField[targetCol]
    
    if not attacker then
        addToLog("Ошибка: атакующая карта не найдена")
        return false
    end
    
    if not target then
        addToLog("Ошибка: цель атаки не найдена")
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
    
    -- Логирование события атаки
    addToLog(attacker.name .. " атакует " .. target.name)
    
    -- Сохраняем исходные координаты атакующей карты
    local originalX, originalY
    if attacker.group then
        originalX, originalY = attacker.group.x, attacker.group.y
    else
        originalX, originalY = attacker.x, attacker.y
    end
    
    -- Получаем координаты цели
    local targetX, targetY
    if target.group then
        targetX, targetY = target.group.x, target.group.y
    else
        targetX, targetY = target.x, target.y
    end
    
    -- Создаем анимацию атаки в очереди
    table.insert(animationQueue, function(callback)
        -- Анимация движения атакующей карты к цели
        local attackEffect = display.newCircle(scene.view, originalX, originalY, 15)
        attackEffect:setFillColor(1, 0.3, 0.3, 0.8)
        
        transition.to(attackEffect, {
            time = 300,
            x = targetX,
            y = targetY,
            onComplete = function()
                -- Визуальный эффект удара
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
                        
                        -- Отображение урона для обеих карт
                        local damageToTarget = display.newText({
                            parent = scene.view,
                            text = "-" .. attacker.attack,
                            x = targetX,
                            y = targetY,
                            font = native.systemFontBold,
                            fontSize = 24
                        })
                        damageToTarget:setFillColor(1, 0, 0)
                        
                        local damageToAttacker = display.newText({
                            parent = scene.view,
                            text = "-" .. target.attack,
                            x = originalX,
                            y = originalY,
                            font = native.systemFontBold,
                            fontSize = 24
                        })
                        damageToAttacker:setFillColor(1, 0, 0)
                        
                        transition.to(damageToTarget, {
                            time = 500,
                            y = targetY - 30,
                            alpha = 0,
                            onComplete = function() damageToTarget:removeSelf() end
                        })
                        
                        transition.to(damageToAttacker, {
                            time = 500,
                            y = originalY - 30,
                            alpha = 0,
                            onComplete = function() damageToAttacker:removeSelf() end
                        })
                        
                        -- Обновление отображения здоровья карт
                        updateCardHealth(attacker)
                        updateCardHealth(target)
                        
                        -- Проверка на уничтожение карт после атаки
                        local checkDestruction = function()
                            local cardsDestroyed = false
                            
                            if target.health <= 0 then
                                destroyCard(target, enemyField, targetCol)
                                cardsDestroyed = true
                            end
                            
                            if attacker.health <= 0 then
                                destroyCard(attacker, playerField, attackerCol)
                                cardsDestroyed = true
                            end
                            
                            -- Проверка победы/поражения после уничтожения карт
                            local gameEnded = checkWinCondition()
                            
                            -- Если игра не завершилась и колбэк существует, вызываем его
                            if not gameEnded and callback then
                                callback()
                            end
                        end
                        
                        -- Небольшая задержка перед проверкой уничтожения
                        timer.performWithDelay(300, checkDestruction)
                    end
                })
            end
        })
    end)
    
    -- Запускаем очередь анимаций, если она не запущена
    if not animationInProgress then
        processAnimationQueue()
    end
    
    return true
end

-- Функция атаки игрока напрямую
attackPlayer = function(attackerCol, targetType)
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
    
    -- Определяем цель атаки (игрок или противник)
    local targetHealth, targetY
    if targetType == "enemy" then
        targetHealth = enemyHealth
        targetY = 50 -- Верхняя часть экрана (враг)
    else
        targetHealth = playerHealth
        targetY = display.contentHeight - 50 -- Нижняя часть экрана (игрок)
    end
    
    -- Сохраняем исходные координаты атакующей карты
    local originalX, originalY
    if attacker.group then
        originalX, originalY = attacker.group.x, attacker.group.y
    else
        originalX, originalY = attacker.x, attacker.y
    end
    
    -- Создаем анимацию атаки в очереди
    table.insert(animationQueue, function(callback)
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
                
                -- Визуальный эффект удара
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
                        
                        -- Применяем урон и логируем результат
                        if targetType == "enemy" then
                            enemyHealth = enemyHealth - damage
                            addToLog(attacker.name .. " атаковал противника напрямую, нанеся " .. damage .. " урона")
                        else
                            playerHealth = playerHealth - damage
                            addToLog(attacker.name .. " атаковал вас напрямую, нанеся " .. damage .. " урона")
                        end
                        
                        -- Отображаем текст с уроном
                        local damageText = display.newText({
                            parent = scene.view,
                            text = "-" .. damage,
                            x = display.contentCenterX,
                            y = targetY,
                            font = native.systemFontBold,
                            fontSize = 28
                        })
                        damageText:setFillColor(1, 0, 0)
                        
                        transition.to(damageText, {
                            time = 500,
                            y = targetY - 30,
                            alpha = 0,
                            onComplete = function()
                                damageText:removeSelf()
                                -- Обновление отображения здоровья
                                updateHealthDisplay()
                                
                                -- Проверка победы/поражения после атаки
                                local gameEnded = checkWinCondition()
                                
                                -- Если игра не завершилась, продолжаем выполнение callback
                                if not gameEnded and callback then
                                    callback()
                                end
                            end
                        })
                    end
                })
            end
        })
    end)
    
    -- Запускаем очередь анимаций, если она не запущена
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

return scene 