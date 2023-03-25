local composer = require( "composer" )
local scene = composer.newScene()
 
--Not available in the default app, but if you're expanding on it you may want to give yourself
--a way to show this scene to get some GPS info in the field.

--display a bunch of GPS info here.
local eventLabel = {}
local plusCodeLabel = {}

 function OnGPS(event)
	eventLabel.text = dump(event):gsub(',', '\n'):gsub('}', ''):gsub('{ ', '')
	plusCodeLabel.text = currentPlusCode
 end
 
-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------
 
-- create()
function scene:create( event )
 
    local sceneGroup = self.view
    -- Code here runs when the scene is first created but has not yet appeared on screen
	local staticA = display.newText({parent = sceneGroup, text = 'GPS Data:', x = 20, y = 0})
	staticA.anchorX = 0
	staticA.anchorY = 0

	eventLabel = display.newText({parent = sceneGroup, text = dump(lastGpsData):gsub(',', '\n'):gsub('}', ''):gsub('{ ', ''), x = 20, y = 80, width = 900})
	eventLabel.anchorX = 0
	eventLabel.anchorY = 0

	local staticB = display.newText({parent = sceneGroup, text = 'Current Plus Code:', x = 20, y = 600})
	staticB.anchorX = 0
	staticB.anchorY = 0

	plusCodeLabel = display.newText({parent = sceneGroup, text = currentPlusCode, x = 20, y = 660, width = 900})
	plusCodeLabel.anchorX = 0
	plusCodeLabel.anchorY = 0
 
end
 
 
-- show()
function scene:show( event )
 
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then
        -- Code here runs when the scene is still off screen (but is about to come on screen)
 
    elseif ( phase == "did" ) then
        -- Code here runs when the scene is entirely on screen
        currentGpsCallback = OnGPS
 
    end
end
 
 
-- hide()
function scene:hide( event )
 
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then
        -- Code here runs when the scene is on screen (but is about to go off screen)
 
    elseif ( phase == "did" ) then
        -- Code here runs immediately after the scene goes entirely off screen
        currentGpsCallback = nil
 
    end
end
 
 
-- destroy()
function scene:destroy( event )
 
    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view
 
end
 
 
-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------
 
return scene