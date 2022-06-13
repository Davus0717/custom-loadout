---
--- Created by Davus.
---
--- This script utilizes some functionalities of the weapon-attachments.lua, whose author I don't know tho
---
--- Version 1.2
---

util.require_natives(1627063482)

local STOREDIR = filesystem.store_dir() --- not using this much, consider moving it to the 2 locations it's used in..
local LIBDIR = filesystem.scripts_dir() .. "lib\\"
local do_autoload = false
local attachments_table = {}
local weapons_table = {}
if filesystem.exists(LIBDIR .. "wpcmplabels.lua") and filesystem.exists(LIBDIR .. "weapons.lua") then
    attachments_table = require("lib.wpcmplabels")
    weapons_table = require("lib.weapons")
else
    util.toast("You didn't install the resources properly. Make sure weapons.lua and wpcmplabels.lua are in the lib directory")
    util.stop_script()
end


save_loadout = menu.action(menu.my_root(), "Save Loadout", {}, "Save all currently equipped weapons and their attachments to be loaded in the future",
        function()
            local charS,charE = "   ","\n"
            local player = PLAYER.GET_PLAYER_PED(players.user())
            file = io.open(STOREDIR .. "loadout.lua", "wb")
            file:write("return {" .. charE)
            for category, weapon in pairs(weapons_table) do
                for n, weapon_hash in pairs(weapon) do
                    if WEAPON.HAS_PED_GOT_WEAPON(player, weapon_hash, false) then
                        file:write(charS .. "[" .. weapon_hash .. "] = ")
                        WEAPON.SET_CURRENT_PED_WEAPON(player, weapon_hash, true)
                        util.yield(100)
                        local num_attachments = 0
                        for attachment_hash, attachment_name in pairs(attachments_table) do
                            if (WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, attachment_hash)) then
                                util.yield(10)
                                if WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(player, weapon_hash, attachment_hash) then
                                    num_attachments = num_attachments + 1
                                    if num_attachments == 1 then
                                        file:write("{")
                                    else
                                        file:write(",")
                                    end
                                    file:write(charE .. charS .. charS .. "[" .. num_attachments .. "] = " .. attachment_hash)
                                end
                            end
                        end
                        local cur_tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(player, weapon_hash)
                        if num_attachments > 0 then
                            file:write("," .. charE .. charS .. charS .. "[\"tint\"] = " .. cur_tint)
                            file:write(charE .. charS .. "}," .. charE)
                        else
                            file:write("{" .. charE .. charS .. charS .. "[\"tint\"] = " .. cur_tint)
                            file:write(charE .. charS .. "}," .. charE)
                            --file:write("{nil}," .. charE)
                        end
                    end
                end
            end
            file:write("}")
            file:close()
            util.toast("save complete")
        end
)

load_loadout = menu.action(menu.my_root(), "Load Loadout", {"loadloadout"}, "Equip every weapon of the last save",
        function()
            if filesystem.exists(STOREDIR .. "loadout.lua") then
                util.toast("loading your weapons..")
                player = PLAYER.GET_PLAYER_PED(players.user())
                WEAPON.REMOVE_ALL_PED_WEAPONS(player, false)
                WEAPON._SET_CAN_PED_EQUIP_ALL_WEAPONS(player, true)
                local loadout_table = require("store\\" .. "loadout")
                for w_hash, attach in pairs(loadout_table) do
                    WEAPON.GIVE_WEAPON_TO_PED(player, w_hash, 10, false, true)
                        for n, a_hash in pairs(attach) do
                            if n ~= "tint" then
                                WEAPON.GIVE_WEAPON_COMPONENT_TO_PED(player, w_hash, a_hash)
                                util.yield(10)
                            end
                        end
                    WEAPON.SET_PED_WEAPON_TINT_INDEX(player, w_hash, attach["tint"])
                end
                regen_menu()
                util.toast("loadout equipped")
            else
                util.toast("You never saved a loadout before.. what should I load *.*")
            end
            package.loaded["store\\loadout"] = nil --- load_loadout should always get the current state of loadout.lua, therefore always load it again or else the last required table would be taken, as it has already been loaded before..
        end
)

auto_load = menu.toggle(menu.my_root(), "Auto-Load", {}, "Automatically equips every weapon of your last save when you join a new session",
        function(on)
            do_autoload = on
        end
)

from_scratch = menu.action(menu.my_root(), "Start From Scratch", {}, "Delete all your current weapons, so that you can build your loadout exactly how you want it to be",
        function()
            WEAPON.REMOVE_ALL_PED_WEAPONS(PLAYER.GET_PLAYER_PED(players.user()), false)
            regen_menu()
            util.toast("your weapons have been yeeted!")
        end
)

menu.divider(menu.my_root(), "Edit Weapons")

function regen_menu()
    attachments = {}
    weapon_deletes = {}
    tints = {}
    for category, weapon in pairs(weapons_table) do
        category = string.gsub(category, "_", " ")
        for weapon_name, weapon_hash in pairs(weapon) do
            weapon_name = string.gsub(weapon_name, "_", " ")
            menu.delete(weapons[weapon_name])
            if WEAPON.HAS_PED_GOT_WEAPON(PLAYER.GET_PLAYER_PED(players.user()), weapon_hash, false) == true then
                generate_for_new_weapon(category, weapon_name, weapon_hash)
            else
                weapons[weapon_name] = menu.action(categories[category], weapon_name .. "(not equipped)", {}, "Equip " .. weapon_name,
                        function()
                            menu.delete(weapons[weapon_name])
                            equip_weapon(category, weapon_name, weapon_hash)
                        end
                )
            end
            WEAPON.ADD_AMMO_TO_PED(PLAYER.GET_PLAYER_PED(players.user()), weapon_hash, 10) --- if a special ammo type has been equipped.. it should get some ammo
        end
    end
end

function equip_comp(category, weapon_name, weapon_hash, attachment_hash)
    WEAPON.GIVE_WEAPON_COMPONENT_TO_PED(PLAYER.GET_PLAYER_PED(players.user()), weapon_hash, attachment_hash)
    generate_attachments(category, weapon_name, weapon_hash)
end

function equip_weapon(category, weapon_name, weapon_hash)
    WEAPON.GIVE_WEAPON_TO_PED(PLAYER.GET_PLAYER_PED(players.user()), weapon_hash, 10, false, true)
    util.yield(10)
    weapon_deletes[weapon_name] = nil
    generate_for_new_weapon(category, weapon_name, weapon_hash)
end

function generate_for_new_weapon(category, weapon_name, weapon_hash)
    weapons[weapon_name] = menu.list(categories[category], weapon_name, {}, "Edit attachments for " .. weapon_name,
            function()
                WEAPON.SET_CURRENT_PED_WEAPON(PLAYER.GET_PLAYER_PED(players.user()), weapon_hash, true)
                generate_attachments(category, weapon_name, weapon_hash)
            end
    )
end

function generate_attachments(category, weapon_name, weapon_hash)
    player = PLAYER.GET_PLAYER_PED(players.user())
    if weapon_deletes[weapon_name] == nil then
        weapon_deletes[weapon_name] = menu.action(weapons[weapon_name], "Delete " .. weapon_name, {}, "",
                function()
                    WEAPON.REMOVE_WEAPON_FROM_PED(player, weapon_hash)
                    menu.delete(weapons[weapon_name])
                    util.toast(weapon_name .. " has been deleted")
                    weapons[weapon_name] = menu.action(categories[category], weapon_name .. "(not equipped)", {}, "Equip " .. weapon_name,
                            function()
                                for a_key, a_action in pairs(attachments) do
                                    if string.find(a_key, weapon_hash) ~= nil then
                                        attachments[a_key] = nil
                                    end
                                end
                                menu.delete(weapons[weapon_name])
                                equip_weapon(category, weapon_name, weapon_hash)
                                weapon_deletes[weapon_name] = nil
                            end
                    )
                end
        )

        local tint_count = WEAPON.GET_WEAPON_TINT_COUNT(weapon_hash)
        local cur_tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(player, weapon_hash)
        tints[weapon_hash] = menu.slider(weapons[weapon_name], "Tint", {}, "Choose the tint for your " .. weapon_name, 0, tint_count - 1, cur_tint, 1,
                function(change)
                    WEAPON.SET_PED_WEAPON_TINT_INDEX(player, weapon_hash, change)
                end
        )

        menu.divider(weapons[weapon_name], "Attachments")
    end

    for attachment_hash, attachment_name in pairs(attachments_table) do
        if (WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, attachment_hash)) then
            if (attachments[weapon_hash .. " " .. attachment_hash] ~= nil) then menu.delete(attachments[weapon_hash .. " " .. attachment_hash]) end
            attachments[weapon_hash .. " " .. attachment_hash] = menu.action(weapons[weapon_name], attachment_name, {}, "Equip " .. attachment_name .. " on your " .. weapon_name,
                    function()
                        equip_comp(category, weapon_name, weapon_hash, attachment_hash)
                        util.yield(1)
                        if string.find(attachment_name, "Rounds") ~= nil and WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(player, weapon_hash, attachment_hash) then
                            --- if the type of rounds is changed, the player needs some bullets of the new type to be able to use them
                            WEAPON.ADD_AMMO_TO_PED(player, weapon_hash, 10)
                            util.toast("gave " .. weapon_name .. " some rounds due to new ammo type")
                        end
                    end
            )
        end
    end
end








categories = {}
weapons = {}
attachments = {}
weapon_deletes = {}
tints = {}
for category, weapon in pairs(weapons_table) do
    category = string.gsub(category, "_", " ")
    categories[category] = menu.list(menu.my_root(), category, {}, "Edit weapons of the " .. category .. " category")
    for weapon_name, weapon_hash in pairs(weapon) do
        weapon_name = string.gsub(weapon_name, "_", " ")
        if WEAPON.HAS_PED_GOT_WEAPON(PLAYER.GET_PLAYER_PED(players.user()), weapon_hash, false) == true then
            generate_for_new_weapon(category, weapon_name, weapon_hash)
        else
            weapons[weapon_name] = menu.action(categories[category], weapon_name .. "(not equipped)", {}, "Equip " .. weapon_name,
                    function()
                        menu.delete(weapons[weapon_name])
                        equip_weapon(category, weapon_name, weapon_hash)
                    end
            )
        end
    end
end

while true do
    if NETWORK.NETWORK_IS_IN_SESSION() == false then
        while NETWORK.NETWORK_IS_IN_SESSION() == false or util.is_session_transition_active() do
            util.yield(1000)
        end
        util.yield(10000) --- wait until even the clownish animation on spawn is definitely finished..
        if do_autoload then
            menu.trigger_commands("loadloadout")
        else
            regen_menu()
        end
    end
    util.yield()
end
