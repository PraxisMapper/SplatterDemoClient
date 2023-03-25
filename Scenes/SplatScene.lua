local composer = require( "composer" )
local scene = composer.newScene()
local widget = require("widget")
local json = require("json")
local lfs = require('lfs')

local thisScenesView = '' 

--Splatter: Walk to build up paint points, tap the screen to throw paint on an area.
--Radius will be some percentage of your paint points, up to a max.

local updateLoopTimer = nil
local SplatTileTimer = nil
local gameMapDisplaySplat = {} -- scrollview 
local gameMapTilesSplat = {} -- background map tiles
local splatterMapTiles = {} -- overlay compete Splat maptiles.
local playerHeading = {}
local paintPointsLabel = {}

local header = {}
local muniTimer = {}

local netStatusTimer = {}

function TileGenHandlerSplatter(event)
    NetUp()

    if NetCallCheck(event.status) == false then
        return
    end

    local piece = string.gsub(event.url, serverURL .. "MapTile/Generation/", "")
    local pieces = Split(piece, '/') -- 1 = plusCode, 2 = styleSet (splatter)
    local answer = event.response

    if (answer == 'Timed out') then
        --abort this logic!
        return
    end
    local imageExists = false
    imageExists = DoesFileExist(pieces[1] .. "-splat.png", system.TemporaryDirectory)

    local hasData = false
    local redownload = false
    local tileGen = 0
    local tileInfoOnPlusCode = tileGenInfo[pieces[1]]
    if tileInfoOnPlusCode ~= nil then
        if tileInfoOnPlusCode.Splatter ~= nil then
            hasData = true
            tileGen = tileInfoOnPlusCode.Splatter
        end
    end
    
    if hasData == true and tonumber(tileGen) < tonumber(answer)then
        tileGenInfo[pieces[1]].Splatter = answer
        redownload = true
    end

    if hasData == false then
        tileGenInfo[pieces[1]] = { Compete = answer }
        redownload = true
    end
    
    redownload = (imageExists == false) or redownload or answer == '-1'
    if redownload then
        GetSplatterTile(pieces[1])
    end
end

local function RedrawEntireMapSplat()
    gameMapDisplaySplat:removeSelf()
    CreateFullMapDisplaySplat(scene.view, zoomData[currentZoom])
    UpdateScrollViewSplat(0)
end

local function TapScreen(self, event)
    local baseX, baseY = self:getContentPosition()
    local innerX = event.x - baseX
    local innerY = event.y - baseY
    local xDiff = innerX - playerPoint.x + currentMapValues.playerPointOffsetX --playerPoint is centered, for our calcs we need to use its lower left corner.
    local yDiff = innerY - playerPoint.y + currentMapValues.playerPointOffsetY
    local cell10ShiftX = math.floor(xDiff / currentMapValues.cell10SizeX)
    local cell10ShiftY = -math.floor(yDiff / currentMapValues.cell10SizeY)
    --TODO: work out padding values and adjust appropriately.
    local workingPlusCode = RemovePlus(currentPlusCode)
    local tapPlusCode = ShiftCellNoPlus(workingPlusCode, cell10ShiftX, 10)
    tapPlusCode = ShiftCellNoPlus(tapPlusCode, cell10ShiftY, 9)

    lastTappedCode = tapPlusCode
    TappedElementListenerSplat(tapPlusCode)
    return true
end

function TappedElementListenerSplat(plusCode)
    --pick a random amount of paint points (a minimum percentage of the player's total, an absolute maximum cap)
    --Send a splat request to the server, refresh map tiles on complete
    if (playerData.paintPoints <= 0) then
        return
    end

    local min = math.max(1, playerData.paintPoints / 10)
    local max = math.min(20, playerData.paintPoints)

    local radiusTiles = 0
    
    if (min < max) then
        radiusTiles = math.random(min, max)
    else
        radiusTiles = max
    end

    playerData.paintPoints = playerData.paintPoints - radiusTiles
    paintPointsLabel.text = "Paint: " .. playerData.paintPoints

    local url = serverURL .. 'Splatter/Splat/' .. plusCode .. '/' .. radiusTiles
    network.request(url, "PUT", SplatHandler, normalParams) 
end

function SplatHandler(event)
    CheckForSplatTiles()
end

function GetSplatterTile(plusCode)
    local params = GetImageDownloadParams(plusCode .. '-splat.png', system.TemporaryDirectory)
    local url = serverURL .. 'Splatter/MapTile/' .. plusCode
    QueueCall(url, 'GET', SplatterTileListener, params)
end

function SplatterTileListener(event)
    NetUp()
    local pieces = Split(event.url, '/')
    local plusCode = pieces[#pieces]
    if NetCallCheck(event.status) == false then
        return
    end
    --save file, draw file.
    for tile = 1, #splatterMapTiles do
        if splatterMapTiles[tile].pluscode == plusCode then
            if PaintOneTile(splatterMapTiles[tile], plusCode .. '-splat.png', system.TemporaryDirectory) == false then 
            end
            return
        end
    end
end

function SplatPlusCodeChange(event)
    local url = serverURL .. "Splatter/Enter/" .. RemovePlus(currentPlusCode)
    network.request(url, "PUT", SplatEnterHandler, normalParams)
end

function SplatEnterHandler(event)
    if NetCallCheck(event.status) == false then
        return
    end
    playerData.paintPoints = tonumber(event.response)
    paintPointsLabel.text = "Paint: " .. playerData.paintPoints
end

function WalkaroundGpsCallbackSplat(event)
    ScrollToPlayerLocation(gameMapDisplaySplat, playerPoint, currentMapValues, 0, playerHeading)
    playerHeading.rotation = currentHeading
    header.locText.text = "Loc: " .. currentPlusCode
    header.muniDisplay.text = currentMuni

    if (event.accuracy ~= nil) then --doesnt work in simulator.
        header.accuracyLabel.text = math.round(event.accuracy) .. 'm'
    end
end

function ZoomInSplat(event)
    currentZoom = currentZoom - 1
    if (currentZoom == 0) then
        currentZoom = 1
        return true
    end

    RedrawEntireMapSplat()
    return true
end

function ZoomOutSplat(event)
    currentZoom = currentZoom + 1
    if (currentZoom > #zoomData) then
        currentZoom = #zoomData
        return true
    end

    RedrawEntireMapSplat()
    return true
end

function PauseUpdateTimerSplat()
    if updateLoopTimer ~= nil then        
        timer.pause(updateLoopTimer)
    end
end

function ScrollCallbackSplat()
    if (updateLoopTimer ~= nil) then
        timer.resume(updateLoopTimer)
    end
end

function CreateFullMapDisplaySplat(gridGroup, sizeProps) 
    PauseUpdateTimerSplat()
    currentMapValues = sizeProps
    gameMapTilesSplat = {}
    splatterMapTiles = {}

    playerPoint.width = currentMapValues.playerPointWidth
    playerPoint.height = currentMapValues.playerPointHeight

    playerHeading.width = currentMapValues.playerPointHeight --correct, this image is square and we want the larger value.
    playerHeading.height = currentMapValues.playerPointHeight

    gameMapDisplaySplat = CreateBaseMapDisplay(TapScreen)
    CreateInnerGrid(gridGroup, gameMapTilesSplat, gameMapDisplaySplat)
    CreateInnerGrid(gridGroup, splatterMapTiles, gameMapDisplaySplat)

    gameMapDisplaySplat:insert(playerPoint)
    playerPoint:toFront()
    
    gameMapDisplaySplat:insert(playerHeading)
    playerHeading:toFront()

    gameMapDisplaySplat:toBack()
    ScrollToPlayerLocation(gameMapDisplaySplat, playerPoint, currentMapValues, 0, playerHeading)
    ScrollCallbackSplat()
end

local function GetTileListener(event)
    --update the appropriate map tile.
    NetUp()
    if NetCallCheck(event.status) == true then
        local plusCode = string.gsub(event.url, serverURL .. "MapTile/Area/", "")

        for tile = 1, #gameMapTilesSplat do
            if gameMapTilesSplat[tile].pluscode == plusCode then
                if PaintOneTile(gameMapTilesSplat[tile], plusCode .. '.png', system.CachesDirectory, true) == false then GetNewTile(plusCode, GetTileListener) end
                return
            end
        end
    end
end

function UpdateScrollViewSplat(speed)
    --call this when current and previous plus code are different.
    for tile = 1, #gameMapTilesSplat do
        local thisTilesPlusCode = currentPlusCode
        thisTilesPlusCode = ShiftCell(thisTilesPlusCode, gameMapTilesSplat[tile].gridX, 8)
        thisTilesPlusCode = ShiftCell(thisTilesPlusCode, gameMapTilesSplat[tile].gridY, 7)
        thisTilesPlusCode = thisTilesPlusCode:sub(1,8)    

        --Check if this imageRect has a different plusCode (meaning the player walked into a new Cell8)
        --and if so we have some extra processing to do.
        if gameMapTilesSplat[tile].pluscode ~= thisTilesPlusCode then
            gameMapTilesSplat[tile].pluscode = thisTilesPlusCode
            splatterMapTiles[tile].pluscode = thisTilesPlusCode
            if PaintOneTile(gameMapTilesSplat[tile], thisTilesPlusCode .. '.png', system.CachesDirectory, true) == false then GetNewTile(thisTilesPlusCode, GetTileListener) end
            if PaintOneTile(splatterMapTiles[tile], thisTilesPlusCode .. '-splat.png', system.TemporaryDirectory) == false then GetSplatterTile(thisTilesPlusCode) end
        end   
    end
    ScrollToPlayerLocation(gameMapDisplaySplat, playerPoint, currentMapValues, speed, playerHeading)
end

function CheckForSplatTiles()
    for i = 1, #splatterMapTiles do
        --CheckTileGenerationSplatter(splatterMapTiles[i].pluscode)
        CheckTileGeneration(splatterMapTiles[i].pluscode, 'splatter', TileGenHandlerSplatter)
    end
end

function UpdateLoopSplat()
    local cell8 = currentPlusCode:sub(1,8)
    if cell8 ~= lastDrawnPlusCode then
        UpdateScrollViewSplat(0) -- resets all the tiles drawn, if necessary.
        lastDrawnPlusCode = cell8
    end
end

function UpdateNetStatusIconSplat()
    UpdateNetStatusIcon(header)
end

function scene:create( event )
    local sceneGroup = self.view

    playerPoint = display.newImageRect(sceneGroup, "themables/PlayerTemplate.png", 48, 60) 
    playerPoint.anchorX = 0.5
    playerPoint.anchorY = 0.5

    playerHeading = display.newImageRect(sceneGroup, "themables/headingIndicator.png", 60, 60)
    playerHeading.anchorX = 0.5
    playerHeading.anchorY = 0.5

    CreateFullMapDisplaySplat(sceneGroup, defaultSizes)
    gameMapDisplaySplat:insert(sceneGroup)

    local ZoomOut = display.newImageRect(sceneGroup, "themables/ZoomOut.png",300, 100)
    ZoomOut.x = 200
    ZoomOut.y = 1850
    ZoomOut:addEventListener("tap", ZoomOutSplat)

    local ZoomIn = display.newImageRect(sceneGroup, "themables/ZoomIn.png",300, 100)
    ZoomIn.x = 860
    ZoomIn.y = 1850
    ZoomIn:addEventListener("tap", ZoomInSplat)

    header = MakeHeaderBar(false)
    sceneGroup:insert(header)
    netStatusTimer = timer.performWithDelay(50, UpdateNetStatusIconSplat, -1)

    paintPointsLabel = display.newText({parent = header, text = "Paint:", x = 700, y = 10})
    paintPointsLabel.anchorY = 0
end
 
function scene:show( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        gameMapDisplaySplat.isVisible = true
    elseif ( phase == "did" ) then
        updateLoopTimer = timer.performWithDelay(updateLoopDelay, UpdateLoopSplat, -1)
        SplatTileTimer = timer.performWithDelay(modeTileDelay, CheckForSplatTiles, -1)
        currentGpsCallback = WalkaroundGpsCallbackSplat
        onPlusCodeChangeCallback = SplatPlusCodeChange
        RedrawEntireMapSplat()
        muniTimer = timer.performWithDelay(muniCheckDelay, GetMuniTimed, -1)
        SplatPlusCodeChange() --enter the cell we start in.
    end
end
 
-- hide()
function scene:hide( event )
 
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then
        gameMapDisplaySplat.isVisible = false
        timer.cancel(updateLoopTimer)
        timer.cancel(SplatTileTimer)
        timer.cancel(muniTimer)
        timer.cancel(netStatusTimer) 
        currentGpsCallback = nil
        onPlusCodeChangeCallback = nil
    elseif ( phase == "did" ) then
 
    end
end

function scene:destroy( event )
    local sceneGroup = self.view
end

scene:addEventListener("create", scene )
scene:addEventListener("show", scene )
scene:addEventListener("hide", scene )
scene:addEventListener("destroy", scene )
 
return scene