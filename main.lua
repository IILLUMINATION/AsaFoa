-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Игра "Владыка Астрала"
-- Основной файл игры

_Cx = display.contentCenterX --центр х
_Cy = display.contentCenterY --центр у
_Dh = display.actualContentHeight --высота
_Dw = display.actualContentWidth --ширина
_Ty = _Cy - _Dh / 2 --верхняя точка
_Dy = _Cy + _Dh / 2 --нижняя точка
_Lx = _Cx - _Dw / 2 --левая точка х
_Rx = _Cx + _Dw / 2 --правая точка х

-- Используем строгий режим
local composer = require("composer")

-- Скрываем строку состояния
display.setStatusBar(display.HiddenStatusBar)

-- Переход на начальный экран
composer.gotoScene("scenes.menu")


