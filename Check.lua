-- Packages needed: lua-socket
local http = require("ssl.https")
local ltn12 = require("ltn12")
local io = require("io")

dofile("config.lua")

function fsize (filename)
	local file = io.open(filename, "r")
	local current = file:seek()      -- get current position
	local size = file:seek("end")    -- get file size
	file:seek("set", current)        -- restore position
	return size
end

if (show_info == true) then print (os.date ("%x %X")) end

if (download_dir == nil) then download_dir = "." end

local file = io.open("history", "r")
if (file ~= nil) then
   history = file:read("*all")
   file:close()
end
if history == nil then history = "" end

local baseUrl = 'https://api.t411.ai'

local http_res = http.request(baseUrl.."/auth", "username="..username.."&password="..password)
if (http_res == nil) then return 1 end
_, _, uid, token = string.find(http_res, '"uid":"(%d+)","token":"([^"]+)"')

local today_json_table = {}
http_res = http.request{url = baseUrl.."/torrents/top/today", sink = ltn12.sink.table(today_json_table), headers = { ["Authorization"] = token }}
today_json = ""
for i, v in pairs(today_json_table) do today_json = today_json..v end

for i, v in pairs(patterns) do
   torrent_name = v.pattern
   torrent_lines = string.gmatch(today_json, '{("id":"%d+","name":" *'..torrent_name..'[^"]*",[^}]+)}')
   for torrent_line in torrent_lines do
      _, _, id, name, size = string.find(torrent_line, '"id":"(%d+)","name":"([^"]+)".*"size":"(%d+)"')
      nsize = size / (1024 * 1024)
      if ((nsize ~= 0) and (v.min_size == nil or nsize >= v.min_size) and
         (v.max_size == nil or nsize <= v.max_size)) then
         if (string.find(history, id)) then
         else
            local file = ltn12.sink.file(io.open(download_dir.."/"..id..".torrent", 'w'))
            http.request{url = baseUrl.."/torrents/download/"..id, sink=file, headers = { ["Authorization"] = token }}
	    if (fsize(download_dir.."/"..id..".torrent") > 1024) then
	       print(torrent_line, id, size)
	       history = history..id..": "..name.."\n"
	    end
         end
      end
   end
end

local file = io.open("history", "w")
file:write(history)
file:close()
