local widget = require('widget')

--adjustable values that get reused around the app.
updateLoopDelay = 50
modeTileDelay = 5000
muniCheckDelay = 15000

tileGenInfo = {}

lastDrawnPlusCode = ''
currentMapValues = {}
currentHeading = 0
lastMuniCall = os.time()

--built-in colors and fills
bgFill = {.6, .6, .6, 1}
paintClear = {0, 0, 0, 0.01}

paintStatic = {
    type = "image",
    filename = "themables/staticTile.png",
    baseDir = system.resourceDirectory
}

--Generic listener to stop UI elements pretending to be overlays from passing touch events through.
function blockTouch(event)
    return true
end

function ScrollToPlayerLocation(scrollView, playerPoint, currentMapValues, speed, playerHeading)
    --do the math to figure out the player's current location on the scroll view, then move there
    --should use a speed of 0 when redrawing all the map tiles, and something fast but gentle otherwise.
    local xPos = 0
    local yPos = 0

    local shift = CODE_ALPHABET_:find(currentPlusCode:sub(11, 11)) - 10 -- X 
    local shift2 = CODE_ALPHABET_:find(currentPlusCode:sub(10, 10)) - 10 -- Y

    local shiftX11, shiftY11
    if (#currentPlusCode == 12) then
        shiftX11, shiftY11 = GetCell11Shift(currentPlusCode:sub(12,12))
    end
    
    --upper left is 0, 0
    --need to figure out the center of the center map tile, then the pixels needed to move center map tile to center of view area, then the offset amount to keep the player centered.
    --center of map tile is (cellSizeX * gridSize) * .5 (3 * .5 = 1.5 for simplicity)
    local mapMid = currentPlusCode:sub(1,8) .. "+FF" -- map center.
    local mapMidX = currentMapValues.cellSizeX * currentMapValues.gridSize * .5
    local mapMidY = currentMapValues.cellSizeY * currentMapValues.gridSize * .5
    
    local ViewMidX = currentMapValues.viewWidth * .5
    local ViewMidY = currentMapValues.viewHeight * .5

    --pixel difference is midPoint - (viewSize * .5)
    local scaleShiftX = (mapMidX - (currentMapValues.viewWidth * .5))
    local scaleShiftY = (mapMidY - (currentMapValues.viewHeight * .5))   

    --existing xPos and yPos values are correct for my needs
    local playerShiftX = (shift * currentMapValues.cell10SizeX)
    local playerShiftY = (shift2 * currentMapValues.cell10SizeY)

    if (#currentPlusCode == 12) then
        playerShiftX = playerShiftX + (shiftX11 * (currentMapValues.cell10SizeX / 4))
        playerShiftY = playerShiftY + (shiftY11 * (currentMapValues.cell10SizeY / 5))
    end
    
    xPos = scaleShiftX + playerShiftX
    yPos = scaleShiftY - playerShiftY

    local printData = false
    if printData == true then
        print("Code Shift values are " .. shift .. ", " .. shift2)
        print("Map Mid is " .. mapMidX .. ", " .. mapMidY)
        print("View Mid is " .. ViewMidX .. ", " .. ViewMidY)
        print("scale shift is " .. scaleShiftX .. ", " .. scaleShiftY)
        print("player shift is " .. playerShiftX .. ", " .. playerShiftY)
        print("scrolling to " .. xPos .. ", " .. yPos)
    end

    local pad = currentMapValues.padding * math.floor(currentMapValues.gridSize / 2)

    playerPoint.x = mapMidX + playerShiftX - currentMapValues.playerPointOffsetX + pad
    playerPoint.y = mapMidY - playerShiftY + currentMapValues.playerPointOffsetY + pad

    if (playerHeading ~= nil) then
        playerHeading.x = playerPoint.x
        playerHeading.y = playerPoint.y
    else
        print('playerHeading nil')
    end

    --scrolling is backwards from positioning
    local options = {x = -xPos, y = -yPos, time = speed}
    scrollView:scrollToPosition(options)
end

function MakeUnqueuedRequest(url, listener)
    local desturl = serverURL .. url
    network.request(desturl, 'GET', listener, normalParams)
end

function CreateBaseMapDisplay(tapListener)
    local MapDisplay = widget.newScrollView({x = 0, y = 0, width = currentMapValues.viewWidth, height = currentMapValues.viewHeight, hideScrollBar = true, isLocked = true, backgroundColor = {0, 0, 0, 1}})
    MapDisplay.anchorX = 0
    MapDisplay.anchorY = 0
    MapDisplay.tap = tapListener
    MapDisplay:addEventListener("tap", MapDisplay)
    return MapDisplay
end

function CreateInnerGrid(gridGroup, mapTiles,  mapDisplay)
    local cellSizeX = currentMapValues.cellSizeX
    local cellSizeY = currentMapValues.cellSizeY
    
    local padding = currentMapValues.padding --space between cells.
    local range = math.floor(currentMapValues.gridSize / 2) -- 7 becomes 3, which is right. 6 also becomes 3.

    local fullRange = range * 2

    for x = 0, fullRange, 1 do
        for y = 0, fullRange, 1 do
            --create cell, tag it with x and y values.
            newSquare = display.newRect(gridGroup,  (cellSizeX * x) + (padding * x), (cellSizeY * y)  + (padding * y), cellSizeX, cellSizeY) --x y w h
            newSquare.gridX = x - range
            newSquare.gridY = -y + range --invert this so cells get identified top-to-bottom, rather than bottom-to-top
            newSquare.pluscode = "" --to potentially be filled in by the game mode
            newSquare.fill = paintStatic  -- {0, 0, 0, .1} --default to transparent, but using 0, 0 means they don't register at all?
            --newSquare.fill = {math.random(), .5} --Uncomment this to make the grid visible for debug/layout purposes
            newSquare.anchorX = 0
            newSquare.anchorY = 0

            table.insert(mapTiles, newSquare)
            mapDisplay:insert(newSquare)
        end
    end
end

function CheckTileGeneration(plusCode, styleSet, handler)
    if (plusCode == '') then return end

    local url = serverURL .. "MapTile/Generation/" .. plusCode .. "/" .. styleSet
    QueueCall(url, "GET", handler, normalParams)
end

function GetNewTile(plusCode8, callback)
    local params = GetImageDownloadParams(plusCode8 .. '.png', system.CachesDirectory)
    local url = serverURL .. "MapTile/Area/" .. plusCode8
    QueueCall(url, "GET", callback, params)
end

function PaintOneTile(mapTile, filename, folder, useStatic)
    local imageExists = DoesFileExist(filename, folder)
    if (imageExists == true) then
        mapTile.fill = paintClear
        local paint = {
            type = "image",
            filename = filename,
            baseDir = folder
        }
        mapTile.fill = paint
        return true
    else
        --file doesn't exist, queue up a request for it by returning false
        if (useStatic) then
            mapTile.fill = paintStatic
        else
            mapTile.fill = paintClear
        end
        return false
    end
end

function GetImageDownloadParams(filename, folder)
    local params = {}
    local headers = {}
    headers = AddAuthHeaders(headers)
    params.headers = headers
    params["response"] = {}
    params["PraxisAuthKey"] = "testingKey" --the proper way to authenticate
    params.response["filename"] = filename
    params.response["baseDirectory"] = folder

    return params
end

function GetMuniListener(event)
    NetUp()
    if NetCallCheck(event.status) == true then
        currentMuni = event.response
    end
end

function GetMuni(plusCode)
    if lastMuniCall + (muniCheckDelay / 1000) > os.time() then
        return
    end

    lastMuniCall = os.time()
    local url = serverURL .. 'Municipality/Muni/' .. plusCode
    QueueCall(url, 'GET', GetMuniListener, normalParams)
end

function GetMuniTimed()
    local url = serverURL .. 'Municipality/Muni/' .. RemovePlus(currentPlusCode)
    QueueCall(url, 'GET', GetMuniListener, normalParams)
end

function MakeHeaderBar()
    local header = display.newGroup()
    local headerBG = display.newRect(header, 0, 0, 1080, 100)
    headerBG.anchorX = 0
    headerBG.anchorY =0
    headerBG.fill = bgFill

    headerLoc = display.newText({ parent = header, text = "Loc: " .. currentPlusCode, x = 15, y = 10})
    headerLoc.anchorX = 0
    headerLoc.anchorY = 0

    muniDisplay = display.newText({ parent = header, text = "", x = 15, y = 60, fontSize = 30})
    muniDisplay.anchorX = 0
    muniDisplay.anchorY = 0

    netStatusLight = display.newImageRect(header, "themables/networkDown.png", 25, 25)
    netStatusLight.x = display.contentCenterX + 30
    netStatusLight.y = 25

    accuracyInfo = display.newText({ parent = header, text = "", x = display.contentCenterX + 30, y = 60, fontSize = 35})
    accuracyInfo.anchorX = 0.5
    accuracyInfo.anchorY = 0.5

    header.locText = headerLoc
    header.possibleLabel = headerPossibleLabel
    header.muniDisplay = muniDisplay
    header.netStatusLight = netStatusLight
    header.accuracyLabel = accuracyInfo
    
    return header
end

function UpdateNetStatusIcon(header)
    local lightPaint = {
        type = "image",
        filename = '',
        baseDir =  system.ResourceDirectory
    }
    if currentNetStatus == 'up' then
        lightPaint.filename = 'themables/networkUp.png'
    elseif currentNetStatus == 'open' then
        lightPaint.filename = 'themables/networkTransfer.png'
    else
        lightPaint.filename = 'themables/networkDown.png'
    end
    header.netStatusLight.fill = lightPaint
end