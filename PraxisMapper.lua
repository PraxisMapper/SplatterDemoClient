--helper functions for calling PraxisMapper server endpoints.
binaryHeaders = {}
binaryHeaders["Content-Type"] = "application/octet-stream"
binaryParams = {
    headers = binaryHeaders,
    bodyType = "binary"
}

normalHeaders = {}
normalParams = {
    headers = normalHeaders,
}

imageHeaders = {}
imageHeaders["response"]  =  {filename = ".png", baseDirectory = system.CachesDirectory}

simultaneousNetCalls = 7 
currentNetStatus = 'down'
netCallCount = 0
networkQueueBusy = false
networkQueue = {}

function AddAuthHeaders(headers)
    headers.AuthKey = authToken
    return headers 
end

function ClearAuthHeaders()
    authToken = ''
    normalParams.headers = AddAuthHeaders(normalParams)
    binaryParams.headers = AddAuthHeaders(binaryParams)
end

function QueueCall(url, verb, handler, params)
    --don't requeue calls that are already in the queue
    for i =1, #networkQueue do
        if networkQueue[i].url == url and networkQueue[i].verb == verb then
            return
        end
    end

    table.insert(networkQueue, { url = url, verb = verb, handlerFunc = handler, params = params})
end

function PostQueueCall(event)
    if NetCallCheck(event.status) then
        NetUp()
    else
        NetDown()
    end

    if netCallCount <= simultaneousNetCalls then
        NextNetworkQueue()
    end
end


function NetUp()
    currentNetStatus = 'up'
    networkQueueBusy = false
    netCallCount = netCallCount - 1
    if #networkQueue > 0 then
        return
    end
end

function NetDown(event)
    currentNetStatus = 'down'
    netCallCount = netCallCount - 1
    networkQueueBusy = false
    if #networkQueue > 0 then
        return
    end
end

function NetTransfer()
    currentNetStatus = 'open'
    netCallCount = netCallCount + 1
end

function DefaultNetCallHandler(event)
    print(dump(event))
    if NetCallCheck(event.status) then
        NetDown(event)
    else
        NetUp()
    end
end

function NetQueueCheck()
    if #networkQueue > 0 and networkQueueBusy == false then
        NextNetworkQueue()
    end
end

function NextNetworkQueue()
    while netCallCount <= simultaneousNetCalls do
        currentNetStatus = 'open'
        networkQueueBusy = true
        netData = networkQueue[1]
        if netData == nil then return end
        network.request(netData.url, netData.verb, netData.handlerFunc, netData.params)
        table.remove(networkQueue, 1)
        netCallCount = netCallCount + 1
    end
end

function NetCallCheck(status) -- returns true if the call is good, returns false if the network call should be handled like an error.
    if status == 419 or status == -1 then
        print('auth timeout or connection failure, reauthing')
        ReAuth()
        currentNetStatus = 'down'
        return false
    end

    if status < 200 or status > 206 then
        currentNetStatus = 'down'
        return false
    end

    return true
end

function ReAuth()
    print("Reauth occurring!")
    if isPendingReauth == true then
        return
    end

    if (credentials.password == nil) then
        credentials = LoadFromFile('credentials.json')
    end

    local url = serverURL .. "Server/Login/"  .. credentials.username .. "/" .. credentials.password
    network.request(url, "GET", ReauthListener, normalParams)
 end


function ReauthListener(event)
    isPendingReauth = false
    if (event.status == 204 or event.status == 200) then
        if (event.response == "") then
            -- We failed to reauth, retry again in 20 seconds.
            print('delaying reauth')
            timer.performWithDelay(20000, ReAuth, 1)
        else
            local authData = json.decode(event.response)
            authToken = authData.authToken

            authExpiration = os.time() + authData.expiration
            normalParams.headers = AddAuthHeaders(normalParams.headers)
            binaryParams.headers = AddAuthHeaders(binaryParams.headers)
        end
    end
end