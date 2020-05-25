--		(c) 2018 Tim Dorohin
--		This program is free software: you can redistribute it and/or modify
--		it under the terms of the GNU General Public License as published by
--		the Free Software Foundation, either version 3 of the License, or
--		(at your option) any later version.
-- 
--		This program is distributed in the hope that it will be useful,
--		but WITHOUT ANY WARRANTY; without even the implied warranty of
--		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
--		GNU General Public License for more details.
-- 
--		You should have received a copy of the GNU General Public License
--		along with this program. If not, see <https://www.gnu.org/licenses/>.

local insecure = minetest.request_insecure_environment()
assert(insecure, "Add mtstat mod to trusted!")

local status = {}
local answer = ""
local lavg = insecure.io.open('/proc/loadavg')
local mems = insecure.io.open('/proc/meminfo')

function update_status()
	--local t = os.clock()
	local num = #minetest.get_connected_players()
        local nummod= #minetest.get_modnames()
	local lag = string.match(minetest.get_server_status(), "lag=(.-), cli")
	local la1, la5, la15 = string.match(lavg:read("*a"), "(.-) (.-) (.-) ")
	local total = tonumber(string.match(mems:read(), "%d+"))
	mems:read()
	local free = tonumber(string.match(mems:read(), "%d+"))
	local mem = (total-free)/total*100
	lavg:seek("set",0) -- return to start of file for next iteration
	mems:read("*a") -- read to the end of file, otherwise on next iteration data will be old
	mems:seek("set",0) -- return to start of file for next iteration
	local response = "HTTP/1.1 200 OK\nConnection: close\nContent-Length: %d\nContent-Type: text/json\n\n%s"
	local json = string.format('{"la1":%s,"la5":%s,"la15":%s,"lag":%s,"mem":%f,"num":%d}\n', la1, la5, la15, lag, mem, num)
        local time = minetest.get_gametime()
	local days = minetest.get_day_count()

        for k,kk in pairs(minetest.get_version()) do
           json=json..k..":"..kk..", "
	end
-- 	json=json..time..","..minetest.get_version()['string']
	json = json..time..", "..days

	for _,player in ipairs(minetest.get_connected_players()) do
		json=json..player:get_player_name()
	end
	
	json="# HELP Mintest Value \n"
	json=json.."# TYPE players counter\n"
	json=json.."minetest{type=\"player\"} "..string.format("%d",num).."\n"
	json=json.."minetest{type=\"days\"} "..string.format("%d",days).."\n"
	json=json.."minetest{type=\"time\"} "..string.format("%d",time).."\n"
	json=json.."minetest{type=\"mods\"} "..string.format("%d",nummod).."\n"


	--print(os.clock() - t)
	answer = string.format(response, #json, json)
	minetest.after(10, update_status)
end

old_require = require				-- Hacky hack
require = insecure.require			-- Setting global require to insecure 'cause
local socket = require('socket')	-- When we try to load any lib that uses require() itself
require = old_require				-- We will get errors otherwise
assert(socket, "Can't bind socket!")
local port = tonumber(minetest.settings:get("mtstat.port")) or 30000
local adress = minetest.settings:get("mtstat.adress") or "*"
local server = assert(socket.bind(adress, port))
server:settimeout(0)

function respond()
	local client = server:accept()
	if client then
		client:settimeout(0.1)
		client:receive('*a') -- without this we will get some errors on other side of connection
		client:send(answer)
		client:close()
	end
end

minetest.register_globalstep(respond)
minetest.after(10, update_status)
print('MTStat loaded! Port: ' .. port .. ' adress: ' .. adress)
