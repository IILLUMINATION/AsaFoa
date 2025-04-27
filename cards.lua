-- Модуль для работы с картами
local cards = {}

-- Список всех возможных карт в игре
cards.allCards = {
    {
        id = 1,
        name = "Воин Света",
        cost = 2,
        attack = 2,
        health = 3,
        ability = "Нет особых способностей"
    },
    {
        id = 2,
        name = "Маг Огня",
        cost = 3,
        attack = 4,
        health = 1,
        ability = "Наносит урон всем соседним юнитам противника"
    },
    {
        id = 3,
        name = "Целитель",
        cost = 3,
        attack = 1,
        health = 4,
        ability = "Восстанавливает 1 здоровье соседним дружественным юнитам"
    },
    {
        id = 4,
        name = "Танк",
        cost = 5,
        attack = 3,
        health = 7,
        ability = "Получает на 1 меньше урона от атак"
    },
    {
        id = 5,
        name = "Ассасин",
        cost = 4,
        attack = 5,
        health = 2,
        ability = "Игнорирует защитные эффекты"
    },
    {
        id = 6,
        name = "Лучник",
        cost = 2,
        attack = 3,
        health = 1,
        ability = "Может атаковать через линию"
    },
    {
        id = 7,
        name = "Рыцарь",
        cost = 4,
        attack = 3,
        health = 5,
        ability = "Защищает соседних юнитов"
    },
    {
        id = 8,
        name = "Призыватель",
        cost = 3,
        attack = 2,
        health = 2,
        ability = "Призывает 1/1 миньона при размещении"
    },
    {
        id = 9,
        name = "Вампир",
        cost = 3,
        attack = 2,
        health = 3,
        ability = "Восстанавливает здоровье равное нанесенному урону"
    },
    {
        id = 10,
        name = "Берсерк",
        cost = 4,
        attack = 2,
        health = 4,
        ability = "Атака увеличивается на 1 за каждое потерянное здоровье"
    },
    {
        id = 11,
        name = "Чародей",
        cost = 5,
        attack = 4,
        health = 3,
        ability = "Наносит двойной урон существам с полным здоровьем"
    },
    {
        id = 12,
        name = "Жрец Тьмы",
        cost = 3,
        attack = 2,
        health = 4,
        ability = "При уничтожении наносит 2 урона герою противника"
    },
    {
        id = 13,
        name = "Элементаль",
        cost = 2,
        attack = 2,
        health = 2,
        ability = "Увеличивает атаку соседних элементалей на 1"
    },
    {
        id = 14,
        name = "Дракон",
        cost = 7,
        attack = 6,
        health = 6,
        ability = "При входе в игру наносит 2 урона всем вражеским юнитам"
    },
    {
        id = 15,
        name = "Паладин",
        cost = 6,
        attack = 4,
        health = 6,
        ability = "Восстанавливает 2 здоровья вашему герою в конце хода"
    },
    {
        id = 16,
        name = "Чумной доктор",
        cost = 4,
        attack = 3,
        health = 3,
        ability = "При уничтожении отравляет соседних врагов (1 урон в конце хода)"
    }
}

-- Функция создания новой колоды
function cards.createDeck()
    local deck = {}
    
    -- Копируем все карты в колоду
    for i = 1, #cards.allCards do
        deck[i] = table.deepcopy(cards.allCards[i])
    end
    
    -- Перемешиваем колоду
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    
    return deck
end

-- Функция глубокого копирования
function table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Функция получения случайной карты из колоды
function cards.drawCard(deck)
    if #deck > 0 then
        local card = table.remove(deck, 1)
        table.insert(deck, card) -- Помещаем карту в конец колоды
        return card
    end
    return nil
end

return cards 