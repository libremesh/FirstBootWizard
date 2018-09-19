#!/usr/bin/lua

local json = require 'luci.json'
local ft = require('firstbootwizard.functools')
local iwinfo = require("iwinfo")
local wireless = require("lime.wireless")
local fs = require("nixio.fs")
local uci = require("uci")
local nixio = require "nixio"

local function print_json(obj)
    print(json.encode(obj))
end

local function execute(cmd)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return s
end

local function eui64(mac)
    local cmd = [[
    function eui64 {
        mac="$(echo "$1" | tr -d : | tr A-Z a-z)"
        mac="$(echo "$mac" | head -c 6)fffe$(echo "$mac" | tail -c +7)"
        let "b = 0x$(echo "$mac" | head -c 2)"
        let "b ^= 2"
        printf "%02x" "$b"
        echo "$mac" | tail -c +3 | head -c 2
        echo -n :
        echo "$mac" | tail -c +5 | head -c 4
        echo -n :
        echo "$mac" | tail -c +9 | head -c 4
        echo -n :
        echo "$mac" | tail -c +13
    }
    echo -n `eui64 ]]..mac..'`'
    return 'fe80::'..execute(cmd)
end

function file_exists(filename)
    return fs.stat(filename, "type") == "reg"
end

local function split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

-- splits a multiline string in a list of strings, one per line
local function lsplit(mlstring)
    return split(mlstring, "\n")
end

local function phy_to_idx(phy)
    local substr = string.gsub(phy, "phy", "")
    return tonumber(substr)
end

function get_networks()
    local allRadios = wireless.scandevices()
    nixio.syslog("crit", "FBW radios "..json.encode(allRadios))
    local all_networks = {}
    local phys = {}
    for _, radio in pairs (allRadios) do
        -- if wireless.is5Ghz(radio[".name"]) then
            local phyIndex = radio[".name"].sub(radio[".name"], -1)
            phys[#phys+1] = "phy"..phyIndex
        -- end
    end
    nixio.syslog("crit", "FBW phys"..json.encode(phys))
    for idx, phy in pairs(phys) do
        networks = iwinfo.nl80211.scanlist(phy)
        nixio.syslog("crit", "FBW networs"..json.encode(networks))
        for k,network in pairs(networks) do
            network["phy"] = phy
            network["phy_idx"] = phy_to_idx(phy)
            all_networks[#all_networks+1] = network
        end
    end
    return all_networks
end

function backup_wifi_config()
    execute("cp /etc/config/wireless /tmp/wireless-temp")
end

function restore_wifi_config()
    execute("cp /tmp/wireless-temp /etc/config/wireless")
end

function connect(mesh_network)
    local phy_idx = mesh_network["phy_idx"]
    local device_name = "lm_wlan"..phy_idx.."adhoc_radio"..phy_idx
    local mode = mesh_network.mode == "Mesh Point" and 'mesh' or 'adhoc'

    local uci_cursor = uci.cursor()
    -- remove networks
    uci_cursor:foreach("wireless", "wifi-iface", function(entry)
        uci_cursor:delete("wireless", entry['.name'])
    end)

    -- set wifi config
    uci_cursor:set("wireless", 'radio'..phy_idx, "channel", mesh_network.channel)

    uci_cursor:set("wireless", device_name, "wifi-iface")
    uci_cursor:set("wireless", device_name, "device", 'radio'..phy_idx)
    uci_cursor:set("wireless", device_name, "ifname", 'wlan'..phy_idx..'-'..mode)
    uci_cursor:set("wireless", device_name, "network", 'lm_net_wlan'..phy_idx..'_'..mode)
    uci_cursor:set("wireless", device_name, "distance", '1000')
    uci_cursor:set("wireless", device_name, "mode", mode)
    uci_cursor:set("wireless", device_name, "mesh_id", 'LiMe')
    uci_cursor:set("wireless", device_name, "ssid", 'LiMe')
    uci_cursor:set("wireless", device_name, "mesh_fwding", '0')
    uci_cursor:set("wireless", device_name, "bssid", 'ca:fe:00:c0:ff:ee')
    uci_cursor:set("wireless", device_name, "mcast_rate", '24000')

    --10uci_c then   if ()
    -- endursor:commit("wireless")

    -- apply wifi config
    execute("wifi down; wifi up;")
end

function fetch_config(host)
    local filename = "/tmp/lime-defaults-"..host
    nixio.syslog("crit", "FBW fetch config "..filename)
    execute("wget http://["..host.."]/lime-defaults -O "..filename.." 2>&1")
    return file_exists(filename) and filename or nil
end

function get_stations_macs(network)
    nixio.syslog("crit", "FBW get_stations_macs "..network)
    return lsplit(execute('iw dev '..network..' station dump | grep ^Station | cut -d\\  -f 2'))
end

local function getAp(path)
    local uci_cursor = uci.cursor("/tmp")
    return uci_cursor:get(path, "wifi", "ap_ssid")
end

function read_configs()
    local tempFiles = fs.dir("/tmp/")
    local result = {}
    for file in tempFiles do
        if (file ~= nil and file:sub(1, 12) == "lime-default") then
            local ap = getAp(file)
            table.insert(result, {
                ap = string.gsub(ap, "\"", ""),
                file = file
            })
        end
    end
    return result
end

local function tableEmpty(self)
    for _, _ in pairs(self) do
        return false
    end
    return true
end

function get_config(mesh_network)
    connect(mesh_network)
    local mode = mesh_network.mode == "Mesh Point" and 'mesh' or 'adhoc'
    local dev_id = 'wlan'..mesh_network['phy_idx']..'-'..mode
    -- time for the mesh to settle
    -- TODO: check if connected if not sleep some more
    local isAssociated = iwinfo.nl80211.assoclist(dev_id)
    local i = 0
    while (tableEmpty(isAssociated)) and i < 10 do
        execute("sleep 1")
        isAssociated = iwinfo.nl80211.assoclist(dev_id)
        i = i + 1
    end
    local stations = get_stations_macs(dev_id)
    local append_network = ft.curry(function (s1, s2) return s2..'%'..s1 end, 2) (dev_id)
    local hosts = ft.map(append_network, ft.map(eui64, stations))
    configs = ft.map(fetch_config, hosts)
    return ft.filter(function(el) return el ~= nil end, configs)
end

function unpack_table(t)
    local unpacked = {}
    for k,v in ipairs(t) do
        for sk, sv in ipairs(v) do
            unpacked[#unpacked+1] = sv
        end
    end
    return unpacked
end

function hash_file(file)
    return execute("md5sum "..file.." | awk '{print $1}'")
end

function are_files_different(file1, file2)
    return hash_file(file1) ~= hash_file(file2)
end

function clean_lime_config()
    local f = io.open("/etc/config/lime", "w")
    local command = [[
config lime system
config lime network
config lime wifi
    ]]
    local s = f:write(command)
    f:close()
end

function apply_config(config)
    conn:call("log", "write", { event = "fbw: "..config })
    -- execute("cp "..config.." /etc/config/lime-defaults")
    -- clean_lime_config()
    -- execute("/rom/etc/uci-defaults/91_lime-config")
    -- execute("rm /var/lock/first_run")
    -- execute("reboot")
end

function filter_mesh(n)
    return n.mode == "Ad-Hoc" or n.mode == "Mesh Point"
end

local function start_scan_file()
    local file = io.open("/tmp/scanning", "w")
    file:write("true")
    file:close()
end

local function stop_scan()
    local file = io.open("/tmp/scanning", "w")
    file:write("false")
    file:close()
end

function check_scan_file()
    local file = io.open("/tmp/scanning", "r")
    if(file == nil) then
        return nil
    end
    return assert(file:read("*a"), nil)
end

function check_lock_file()
    local file = io.open("/etc/first_run", "r")
    if(file == nil) then
        return false
    end
    return true
end

function remove_lock_file()
    execute("rm /etc/first_run")
end

function apply_user_configs(configs)
    local ssid = configs.ssid
    local uci_cursor = uci.cursor()
    print(ssid)
    uci_cursor:set("lime-defaults", 'wifi', 'ap_ssid', ssid)
    uci_cursor:commit("lime-defaults")
    -- apply wifi config
    execute("wifi down; wifi up;")
    return { configs = configs }
end

function get_all_networks()
    start_scan_file()
    local all_mesh = ft.filter(filter_mesh, get_networks())
    nixio.syslog("crit", "FBW MESH"..json.encode(all_mesh))
    backup_wifi_config()
    local configs = unpack_table(ft.map(get_config, all_mesh))
    restore_wifi_config()
    execute("wifi down; wifi up;")

    local equal_than_mine = ft.curry(are_files_different)('/etc/config/lime-defaults')
    -- local configs = ft.filter(equal_than_mine, configs)
    stop_scan()
end