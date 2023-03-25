require('common')
require("helpers")
require("plusCodes")
require("PraxisMapper")
require('gameSettings')
require('gameValues')
local composer = require("composer")
json = require("json")
widget = require("widget")
widget.setTheme('widget_theme_android_holo_dark')

reauthTimer ={}
currentPlusCode = ''
lastPlusCode = ''

currentGpsCallback = nil
onPlusCodeChangeCallback = nil
previousGpsCallback = nil

--Some alternative options are available here
maxZoomedInSizes = { gridSize = 3, cellSizeX = 1280, cellSizeY = 1600, padding = 2, cell10SizeX = 64, cell10SizeY = 80,  cell11SizeX = 16, cell11SizeY = 16, playerPointOffsetX = 32, playerPointOffsetY = 40, viewWidth = 1080, viewHeight = 1920, viewX = 370, viewY = 500, playerPointWidth = 192, playerPointHeight = 240} --cell11 is 16x16, probably the point where i want to use cell11s for claiming stuff instead of cell10 if detecting Places instead of Areas.
--veryZoomedInSizes = { gridSize = 3, cellSizeX = 960, cellSizeY = 1200, padding = 2, cell10SizeX = 48, cell10SizeY = 60, playerPointOffsetX = 24, playerPointOffsetY = 30, viewWidth = 1080, viewHeight = 1920, viewX = 370, viewY = 500, playerPointWidth = 144, playerPointHeight = 180} --pretty huge zoom in, cell11 is 12x12
--veryZoomedInSizes is not particularly distinct from maxZoomedInSized in play.
zoomedInSizes = { gridSize = 5, cellSizeX = 640, cellSizeY = 800, padding = 2, cell10SizeX = 32, cell10SizeY = 40, playerPointOffsetX = 16, playerPointOffsetY = 20, viewWidth = 1080, viewHeight = 1920, viewX = 370, viewY = 500, playerPointWidth = 96, playerPointHeight = 120} --means that a Cell11 is 8x8 pixels. probably still too small to reliably click.
defaultSizes = { gridSize = 7, cellSizeX = 320, cellSizeY = 400, padding = 2, cell10SizeX = 16, cell10SizeY = 20, playerPointOffsetX = 8, playerPointOffsetY = 10, viewWidth = 1080, viewHeight = 1920, viewX = 0, viewY = 0, playerPointWidth = 48, playerPointHeight = 60}  --means that a Cell11 is 4x4 pixels. Not yet clickable?
zoomedOutSizes = { gridSize = 13, cellSizeX = 160, cellSizeY = 200, padding = 2, cell10SizeX = 8, cell10SizeY = 10, playerPointOffsetX = 4, playerPointOffsetY = 5, viewWidth = 1080, viewHeight = 1920, viewX = 370, viewY = 500, playerPointWidth = 24, playerPointHeight = 30} --original tile resolution. 2x2 cell11 resolution
--veryZoomedOutSizes = { gridSize = 19, cellSizeX = 80, cellSizeY = 100, padding = 2, cell10SizeX = 4, cell10SizeY = 5, playerPointOffsetX = 2, playerPointOffsetY = 2, viewWidth = 1080, viewHeight = 1920, viewX = 370, viewY = 500, playerPointWidth = 12, playerPointHeight = 15} --original tile resolution. Each pixel is 1 Cell11 in size. when these are 80x100
--NOTE: VeryZoomedOut is a lot of work for little reward. It's almost 800 calls to do map tiles and an overlay layer.

currentZoom = 3
zoomData = {}
table.insert(zoomData, maxZoomedInSizes)
--table.insert(zoomData, veryZoomedInSizes)
table.insert(zoomData, zoomedInSizes)
table.insert(zoomData, defaultSizes)
table.insert(zoomData, zoomedOutSizes)
--table.insert(zoomData, veryZoomedOutSizes)

function FakeScroll()
    lastPlusCode = currentPlusCode
    -- currentPlusCode = ShiftCell(currentPlusCode, 1, 9) -- move north
    currentPlusCode = ShiftCell(currentPlusCode, 1, 10) -- move east
    -- currentPlusCode = ShiftCell(currentPlusCode, -1, 10) -- move west
    -- currentPlusCode = ShiftCell(currentPlusCode, 1, 9) -- move north
    if onPlusCodeChangeCallback ~= nil then onPlusCodeChangeCallback() end

    currentHeading = currentHeading + 5
    if (currentHeading > 360) then currentHeading = 0 end

    if (currentGpsCallback ~= nil) then
        timer.performWithDelay(1, currentGpsCallback, 1)
    end
end

totalGpsCalls = 0
lastGpsData = {}
function GpsListener(event)
    if (event.errorCode ~= nil) then return end

    totalGpsCalls = totalGpsCalls + 1
	lastGpsData = event

    if (event.direction ~= 0) then currentHeading = event.direction end

    local lat = event.latitude
    local lon = event.longitude
    currentAltitude = event.altitude

    local NewPluscode = EncodeLatLon(lat, lon, 11)
    if (currentPlusCode ~= NewPluscode) then
        lastPlusCode = currentPlusCode
        currentPlusCode = NewPluscode
        if (onPlusCodeChangeCallback ~= nil) then
            onPlusCodeChangeCallback()
        end
    end
    currentPlusCode = '85633JC8+QF'

    if (currentGpsCallback ~= nil) then currentGpsCallback(event) end
end

if debugGPS == true then timer.performWithDelay(1000, FakeScroll, -1) end --set automatically if on the simulator.
Runtime:addEventListener("location", GpsListener)
timer.performWithDelay(5, NetQueueCheck, -1) -- in PraxisMapper.lua

composer.gotoScene("scenes.LoginScene")
