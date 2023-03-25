clientVersion = '1'
serverURL = 'https://us.praxismapper.org/praxismapper/' -- Official server for official builds.
serverSimulatorURL = 'http://localhost:5000/' -- Assuming you have the fast LocalDB setup going in the simulator.

if system.getInfo("environment") == "simulator" then
    serverURL = serverSimulatorURL
    debugGPS = true
end