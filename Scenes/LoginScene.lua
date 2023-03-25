local composer = require( "composer" )
local scene = composer.newScene()
local json = require("json")
 
 local username = ''
 local password = ''
 local statusText = ''
 local server = ''
 local isCreating = false

 function SaveLoginData()
    credentials.username = username.text
    credentials.password = password.text
    credentials.lastServer = server.text
    SaveToFile('credentials.json', credentials)
 end

 function CreateServerAccount()
    if (username.text == '' or password.text == '') then
        statusText.text = "Enter the username and password you want to use, then tap Create Account again"
        return
    end

    SaveLoginData()
    isCreating = true
    local urlA = serverURL .. "Server/CreateAccount/"  .. username.text .. "/" .. password.text
    network.request(urlA, "PUT", CreateAccountListenerA, normalParams)
    composer.showOverlay("Overlays.LoadingOverlay", {isModal = true})
 end

 function CreateAccountListenerA(event)
    if (event.status == 200) then
        if (event.response == "false") then
            composer.hideOverlay()
            statusText.text = "Account already exists"
        else
            Login()
        end
    else
        composer.hideOverlay()
        statusText.text = "Could not connect to server."
    end
 end

 function AccountListener(event)
    composer.hideOverlay()
    if (event.status == 200 or event.status == 204) then
        composer.gotoScene("scenes.TestScene")
    else
        statusText.text = "Could not connect to server."
    end
 end
 
 function Login()
    ClearAuthHeaders()
    local connectServer = server.text
    if EndsWith(connectServer, '/') == false then
        connectServer = connectServer .. '/'
        server.text = connectServer
    end
    credentials.lastServer = connectServer
    serverURL = connectServer
    local url = connectServer .. "Server/Login/"  .. username.text .. "/" .. password.text    
    network.request(url, "GET", LoginListener, normalParams)
    composer.showOverlay("Overlays.LoadingOverlay", {isModal = true})
 end

 function SetAuthInfoOnLogin(event)
    local authData = json.decode(event.response)
    authToken = authData.authToken
    authExpiration = os.time() + authData.expiration
    playerData.Name = username.text

    normalParams.headers = AddAuthHeaders(normalParams.headers)
    binaryParams.headers = AddAuthHeaders(binaryParams.headers)
    reauthTimer = timer.performWithDelay(authData.expiration * 900, ReAuth, -1) --function ReAuth in PraxisMapper.lua. Run it when 90% of the way to expiration.
 end

function CommonLoginBehavior(source, event)
    if (event.status == 204 or event.status == 200) then
        if (event.response == "") then
            statusText.text = "Login failed."
            composer.hideOverlay()
        else
            serverURL = server.text
            SaveLoginData()
            SetAuthInfoOnLogin(event)
            composer.gotoScene("Scenes.SplatScene")
        end
    else
        composer.hideOverlay()
        statusText.text = "Could not connect to server."
    end
end

 function LoginListener(event)
    CommonLoginBehavior('login', event)
 end

--Because this simple demo has no wa to log out, this was removed. If you uncomment this, your build will automatically try to log in
--to the last server used with the last account and password used upon game start.
 --  function TryLogin()
--     if (credentials.username ~= nil) then
--         composer.showOverlay("Overlays.LoadingOverlay", {isModal = true})
--         statusText.text = "Logging in..."

--         local url = serverURL .. "Server/Login/"  .. credentials.username .. "/" .. credentials.password
--         network.request(url, "GET", LoginListener, normalParams)
--     end
--  end
 
function scene:create( event )
    local sceneGroup = self.view

    local header = display.newText({ parent = sceneGroup, text = "PraxisMapper Splatter Demo", x = 35, y = 100, fontSize = 80})
    header.anchorX = 0

    local jump1 = display.newText({ parent = sceneGroup, text = "Create Account", x = 100, y = 1200})
    jump1.anchorX = 0
    jump1:addEventListener("tap", CreateServerAccount)

    local jump2 = display.newText({ parent = sceneGroup, text = "Login to Account", x = 100, y = 800})
    jump2.anchorX = 0
    jump2:addEventListener("tap", Login)
 
    statusText = display.newText({ parent = sceneGroup, text = "", x = 100, y = 300, width = 800})
    statusText.anchorX = 0
end

function scene:show( event )
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then
 
    elseif ( phase == "did" ) then

        if DoesFileExist('credentials.json', system.DocumentsDirectory) == true then
            credentials = LoadFromFile('credentials.json')
            if (credentials. username == nil or credentials.username == '') then
                print('Credentials file exist, but is empty.')
            end
        end

        username = native.newTextField(400, 500, 600, 100)
        username.placeholder= "account id"

        password = native.newTextField(400, 600, 600, 100)
        password.placeholder= "password"
        password.isSecure = true

        local serverLabel = display.newText({parent = sceneGroup, text = 'Server URL:', x = 100, y = 1500})
        serverLabel.anchorX = 0
        server = native.newTextField(550, 1600, 900, 100)
        server.placeholder= "server url"
        if (credentials.lastServer ~= '') then
            server.text = credentials.lastServer
        else
            server.text = serverURL
        end

        if (credentials == {}) then
            composer.hideOverlay()
            return
        end

        username.text = credentials.username
        password.text = credentials.password

        if (credentials.username ~= '' and TryLogin ~= nil) then
            timer.performWithDelay(2, TryLogin, 1) --This is required because android won't see the text assigned 2 lines up until after the frame is drawn.
        end
    end
end
 
function scene:hide( event )
    local sceneGroup = self.view
    local phase = event.phase
 
    if ( phase == "will" ) then
        if username.removeSelf  ~= nil then username:removeSelf() end
        if password.removeSelf ~= nil then password:removeSelf() end 
        if server.removeSelf ~= nil then server:removeSelf() end 
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