local snapshot = require "snapshot"
local snapshot_utils = require "common.utils.snapshot_utils"
local construct_indentation = snapshot_utils.construct_indentation
local log = require "skynet-fly.log"

print = log.info

local S1 = snapshot()

local a = {}
local c = {}
a.b = c
c.d = a

local msg = "bar"
local foo = function()
    print(msg)
end

local _ = coroutine.create(function ()
    print("hello world")
end)

local S2 = snapshot()

local diff = {}
for k,v in pairs(S2) do
	if not S1[k] then
        diff[k] = v
	end
end

print(diff)
print("===========================")

local result = construct_indentation(diff)
print(result)
