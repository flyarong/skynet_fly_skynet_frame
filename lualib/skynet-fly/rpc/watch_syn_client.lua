local skynet = require "skynet"
local frpc_client = require "skynet-fly.client.frpc_client"
local log = require "skynet-fly.log"
local skynet_util = require "skynet-fly.utils.skynet_util"
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"
local WATCH_SYN_RET = require "skynet-fly.enum.WATCH_SYN_RET"

local table = table
local pairs = pairs
local next = next
local assert = assert
local type = type
local tunpack = table.unpack

local M = {}

local g_is_watch_up_map = {}            --监听上线的svr_name 列表
local g_watch_channel_name_map = {}     --监听svr_name所有节点的channel_name处理函数 列表
local g_watch_channel_svr_id_map = {}   --指定svr_id的channel_name处理函数 列表
local g_cluster_reqing_map = {}         --是否请求中
local g_cluster_reqfunc_map = {}        --下发已有值用

local function get_channel_map(svr_name, channel_name)
    if not g_watch_channel_name_map[svr_name] then
        return 
    end

    if not g_watch_channel_name_map[svr_name][channel_name] then
        return 
    end

    return g_watch_channel_name_map[svr_name][channel_name]
end

local function get_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not g_watch_channel_svr_id_map[svr_name] then
        return
    end

    if not g_watch_channel_svr_id_map[svr_name][svr_id] then
        return
    end

    if not g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] then
        return
    end

    return g_watch_channel_svr_id_map[svr_name][svr_id][channel_name]
end

local function watch_channel_name(svr_name, svr_id, channel_name, handler)
    local cluster_name = svr_name .. ':' .. svr_id

    if handler then
        --监听同步时，已经存在值了，需要触发一次回调
        local reqfunc = g_cluster_reqfunc_map[cluster_name]
        if reqfunc then
            local msg = reqfunc()
            if msg then
                skynet.fork(handler, cluster_name, skynet.unpack(msg))
            end
        end
    end

    if g_cluster_reqing_map[cluster_name] then return end
    g_cluster_reqing_map[cluster_name] = true
    local version, luamsg
    version = 0
    g_cluster_reqfunc_map[cluster_name] = function()
        return luamsg
    end
    skynet.fork(function()
        while true do
            local ret, cv, cl = frpc_client:instance(svr_name, ""):set_svr_id(svr_id):subsyn(channel_name, version)
            if not ret then
                log.warn_fmt("watch_channel_name err %s ",version)
                break                                               --退出 有watch_up重启拉起
            elseif ret == WATCH_SYN_RET.disconnect or ret == WATCH_SYN_RET.unsyn then
                break                                               --退出 有watch_up重启拉起
            elseif ret == WATCH_SYN_RET.move then
                skynet.sleep(10)
                log.warn("watch_channel_name move ", cluster_name, channel_name)
            else
                version = cv
                luamsg = cl

                local channel_map = get_channel_map(svr_name, channel_name)
                local channel_svr_id_map = get_channel_svr_id_map(svr_name, svr_id, channel_name)
                if channel_map or channel_svr_id_map then
                    local args = {skynet.unpack(luamsg)}
                    if channel_map then
                        for _, handler in pairs(channel_map) do
                            skynet.fork(handler, cluster_name, tunpack(args))
                        end
                    end

                    if channel_svr_id_map then
                        for _, handler in pairs(channel_svr_id_map) do
                            skynet.fork(handler, cluster_name, tunpack(args))
                        end
                    end
                end
            end
        end

        g_cluster_reqing_map[cluster_name] = nil
        g_cluster_reqfunc_map[cluster_name] = nil
    end)
end

local function unwatch_channel_name(svr_name, svr_id, channel_name)
    local isok,err = frpc_client:instance(svr_name, ""):set_svr_id(svr_id):unsubsyn(channel_name)
    if not isok then
        log.warn("unwatch_channel_name faild", svr_name, svr_id, channel_name, err)
    else
        log.warn("unwatch_channel_name succ ", svr_name, svr_id, channel_name)
    end
end

local function check_unwatch_channel_name(svr_name, svr_id, channel_name)
    if get_channel_map(svr_name, channel_name) then
        return 
    end

    if get_channel_svr_id_map(svr_name, svr_id, channel_name) then
        return
    end

    unwatch_channel_name(svr_name, svr_id, channel_name)
end

local function up_cluster_server(svr_name, svr_id)
    local watch_channel_map = g_watch_channel_name_map[svr_name]
    if watch_channel_map then
        for channel_name in pairs(watch_channel_map) do
            watch_channel_name(svr_name, svr_id, channel_name)
        end
    end

    if g_watch_channel_svr_id_map[svr_name] and g_watch_channel_svr_id_map[svr_name][svr_id] then
        local watch_svr_map = g_watch_channel_svr_id_map[svr_name][svr_id]
        for channel_name in pairs(watch_svr_map) do
            watch_channel_name(svr_name, svr_id, channel_name)
        end
    end
end

--watch监听 svr_name 的所有结点
function M.watch(svr_name, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    if not g_watch_channel_name_map[svr_name] then
        g_watch_channel_name_map[svr_name] = {}
    end

    if not g_watch_channel_name_map[svr_name][channel_name] then
        g_watch_channel_name_map[svr_name][channel_name] = {}
    end
    assert(not g_watch_channel_name_map[svr_name][channel_name][handle_name], "exists handle_name " .. handle_name)
    g_watch_channel_name_map[svr_name][channel_name][handle_name] = handler
    if not skynet_util.is_hot_container_server() or contriner_interface.get_server_state() ~= SERVER_STATE_TYPE.loading then
        local svr_list = frpc_client:get_active_svr_ids(svr_name)
        if #svr_list == 0 then
            log.warn("watch not node ", svr_name, channel_name, handle_name)
        else
            for i = 1,#svr_list do
                local svr_id = svr_list[i]
                watch_channel_name(svr_name, svr_id, channel_name, handler)
            end
        end
    end
end

--取消监听 svr_name 的所有结点
function M.unwatch(svr_name, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")

    local channel_map = get_channel_map(svr_name, channel_name)
    if not channel_map then return end

    if not channel_map[handle_name] then return end
    channel_map[handle_name] = nil

    if next(channel_map) then          --说明还存在监听
        return
    end
    --不存在了本服务可以取消对channel_name的监听了
    g_watch_channel_name_map[svr_name][channel_name] = nil
    local svr_list = frpc_client:get_active_svr_ids(svr_name)
    for i = 1, #svr_list do
        local svr_id = svr_list[i]
        check_unwatch_channel_name(svr_name, svr_id, channel_name)
    end
    if next(g_watch_channel_name_map[svr_name]) then
        return
    end

    g_watch_channel_name_map[svr_name] = nil
end

--指定svr_id监听
function M.watch_byid(svr_name, svr_id, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    if not g_watch_channel_svr_id_map[svr_name] then
        g_watch_channel_svr_id_map[svr_name] = {}
    end
    if not g_watch_channel_svr_id_map[svr_name][svr_id] then
        g_watch_channel_svr_id_map[svr_name][svr_id] = {}
    end
    if not g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] then
        g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] = {}
    end
    assert(not g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name], "exists handle_name " .. handle_name)
    g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name] = handler
    if not skynet_util.is_hot_container_server() or contriner_interface.get_server_state() ~= SERVER_STATE_TYPE.loading then
        watch_channel_name(svr_name, svr_id, channel_name, handler)
    end
end

--指定svr_id取消监听
function M.unwatch_byid(svr_name, svr_id, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")

    local channel_map = get_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not channel_map then return end
    if not channel_map[handle_name] then return end

    channel_map[handle_name] = nil

    if next(channel_map) then          --说明还存在监听
        return
    end
    
    g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] = nil
    if next(g_watch_channel_svr_id_map[svr_name][svr_id]) then
        return
    end
    --不存在了本服务可以取消对channel_name的监听了
    g_watch_channel_svr_id_map[svr_name][svr_id] = nil
    check_unwatch_channel_name(svr_name, svr_id, channel_name)
    if next(g_watch_channel_svr_id_map[svr_name]) then
        return
    end

    g_watch_channel_svr_id_map[svr_name] = nil
end

return M