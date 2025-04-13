local socket = require("socket")
local ltn12 = require("ltn12") 

do

	log.write('ExportTelemetry.LUA',log.INFO,' Preparing export ')

	local logFile = nil

	local PrevLuaExportStart=LuaExportStart

	LuaExportStart=function()

		-- Works once just before mission start.
		-- Make initializations of your files or connections here.

		logFile = io.open(lfs.writedir() .. "/Logs/telemetry.csv", "w")
		
		-- Write CSV header	
		logFile:write(string.format("Time,PilotName,Lat,Lon,Heading,Speed,Alt\n"))
 

	end


	local PrevLuaExportActivityNextEvent=LuaExportActivityNextEvent

	LuaExportActivityNextEvent=function(t)
		local tNext = t
		local pilotName = LoGetPilotName() 

		--local http = require "socket.http"
		
		
		local myData = LoGetSelfData()
		--myData.LatLongAlt.Lat             
		--myData.LatLongAlt.Long 
		--myData.Heading 
				
		local indicateAirSpeed = LoGetIndicatedAirSpeed()
		local altitudeSeaLevel = LoGetAltitudeAboveSeaLevel()   
		

		--logFile:write(string.format("%s,%s,%.6f,%.6f,%.2f,%.2f,%.2f\n",os.date("%Y-%m-%d %H:%M:%S"),pilotName,myData.LatLongAlt.Lat,myData.LatLongAlt.Long,myData.Heading,indicateAirSpeed,altitudeSeaLevel))

		-- Target server and port
		local host = "localhost"
		local port = 9200

		-- JSON payload
		local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
		local json_data = '{"time":"'..timestamp..'","pilotName":"'..pilotName..'","indicateAirSpeed":"'..indicateAirSpeed..'","altitudeSeaLevel":"'..altitudeSeaLevel..'","heading":"'..myData.Heading..'","latitude":"'..myData.LatLongAlt.Lat..'","longitude":"'..myData.LatLongAlt.Long..'"}'

		-- Construct HTTP POST request
		local request = table.concat({
			"POST /dcs_telemetry/_doc?pretty HTTP/1.1",
			"Host: " .. host,
			"Content-Type: application/json",
			"Content-Length: " .. #json_data,
			"Connection: close", -- Important to signal the server to close the socket
			"",
			json_data
		}, "\r\n")

		-- Connect to the server
		local tcp = assert(socket.tcp())
		tcp:connect(host, port)
		tcp:send(request)

		-- Receive response
		local response = {}
		while true do
			local line, err = tcp:receive('*l')
			if not line then break end
			table.insert(response, line)
		end

		tcp:close()

		-- Print the raw HTTP response
		logFile:write(table.concat(response, "\n"))

		tNext = tNext + 1.0

		return tNext
	end

	local PrevLuaExportStop=ExportStop

	ExportStop=function()

		-- Works once just after mission stop.
		-- Close files and/or connections here.

		if logFile then        
			logFile:close()
			logFile = nil
		end
	end

	log.write('ExportTelemetry.LUA',log.INFO,' Finishing export ')

end