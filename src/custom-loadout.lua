--[[
 Created by Davus

 Version 1.3
]]

util.require_natives(1663599433)

local STOREDIR = filesystem.store_dir() --- not using this much, consider moving it to the 2 locations it's used in..
local LIBDIR = filesystem.scripts_dir() .. "lib\\custom-loadout\\"
local do_autoload = false
local wpcmpTable = {}
local weapons_table = {}
if filesystem.exists(LIBDIR .. "component_resources.lua") then
    wpcmpTable = require("lib.custom-loadout.component_resources")
    weapons_table = util.get_weapons()
else
    util.toast("You didn't install the resources properly.\nMake sure component-resources.lua is in the " .. LIBDIR .. " directory")
    util.stop_script()
end
local attachments_dict = wpcmpTable[1]
local liveries_dict = wpcmpTable[2]

root = menu.my_root()

save_loadout = root:action("Save Loadout", {}, "Save all currently equipped weapons and their attachments to be loaded in the future",
        function()
            local charS,charE = "   ","\n"
            local player = players.user_ped()
            file = io.open(STOREDIR .. "loadout.lua", "wb")
            file:write("return {" .. charE)
            local num_weapons = 0
            for _, weapon in weapons_table do
                local weapon_hash = weapon.hash

                if WEAPON.HAS_PED_GOT_WEAPON(player, weapon_hash, false) then
                    num_weapons = num_weapons + 1
                    if num_weapons > 1 then
                        file:write("," .. charE)
                    end
                    file:write(charS .. "[" .. weapon_hash .. "] = ")
                    --WEAPON.SET_CURRENT_PED_WEAPON(player, weapon_hash, true)
                    local num_attachments = 0
                    for attachment_hash, _ in attachments_dict do
                        if (WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, attachment_hash)) then
                            --util.yield(10)
                            if WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(player, weapon_hash, attachment_hash) then
                                num_attachments = num_attachments + 1
                                if num_attachments == 1 then
                                    file:write("{")
                                    file:write(charE .. charS .. charS .. "[\"attachments\"] = {")
                                else
                                    file:write(",")
                                end
                                file:write(charE .. charS .. charS .. charS .. "[" .. num_attachments .. "] = " .. attachment_hash)
                            end
                        end
                    end
                    local cur_tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(player, weapon_hash)
                    if num_attachments > 0 then
                        file:write(charE .. charS .. charS .. "},")
                    else
                        file:write("{")
                    end
                    file:write(charE .. charS .. charS .. "[\"tint\"] = " .. cur_tint)
                    --- Livery
                    for livery_hash, _ in liveries_dict do
                        if WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(player, weapon_hash, livery_hash) then
                            local colour = WEAPON.GET_PED_WEAPON_COMPONENT_TINT_INDEX(player, weapon_hash, livery_hash)
                            file:write("," .. charE .. charS .. charS .. "[\"livery\"] = {")
                            file:write(charE .. charS .. charS .. charS .. "[\"hash\"] = " .. livery_hash .. ",")
                            file:write(charE .. charS .. charS .. charS .. "[\"colour\"] = " .. colour)
                            file:write(charE .. charS .. charS .. "}")
                            break
                        end
                    end
                    file:write(charE .. charS .. "}")
                end
            end
            file:write(charE .. "}")
            file:close()
            util.toast("save complete")
        end
)

load_loadout = root:action("Load Loadout", {"loadloadout"}, "Equip every weapon of the last save",
        function()
            if filesystem.exists(STOREDIR .. "loadout.lua") then
                player = players.user_ped()
                WEAPON.REMOVE_ALL_PED_WEAPONS(player, false)
                WEAPON.SET_CAN_PED_SELECT_ALL_WEAPONS(player, true)
                local loadout = require("store\\" .. "loadout")
                for w_hash, attach_dict in loadout do
                    WEAPON.GIVE_WEAPON_TO_PED(player, w_hash, 10, false, true)
                    if attach_dict.attachments ~= nil then
                        for _, hash in attach_dict.attachments do
                            WEAPON.GIVE_WEAPON_COMPONENT_TO_PED(player, w_hash, hash)
                        end
                    end
                    WEAPON.SET_PED_WEAPON_TINT_INDEX(player, w_hash, attach_dict["tint"])
                    if attach_dict.livery ~= nil then
                        WEAPON.GIVE_WEAPON_COMPONENT_TO_PED(player, w_hash, attach_dict.livery.hash)
                        WEAPON.SET_PED_WEAPON_COMPONENT_TINT_INDEX(player, w_hash, attach_dict.livery.hash, attach_dict.livery.colour)
                    end
                end
                regen_menu()
                util.toast("loadout equipped")
            else
                util.toast("You never saved a loadout before.. what should I load *.*")
            end
            package.loaded["store\\loadout"] = nil --- load_loadout should always get the current state of loadout.lua, therefore always load it again or else the last required table would be taken, as it has already been loaded before..
        end
)

auto_load = root:toggle("Auto-Load", {}, "Automatically equips every weapon of your last save when you join a new session",
        function(on)
            do_autoload = on
        end
)

from_scratch = root:action("Start From Scratch", {}, "Delete your current weapons, so that you can build your loadout exactly how you want it to be",
        function()
            WEAPON.REMOVE_ALL_PED_WEAPONS(players.user_ped(), false)
            regen_menu()
            util.toast("your weapons have been yeeted!")
        end
)

root:divider("Edit Weapons")

function regen_menu()
    for _, weapon in weapons_table do
        if weapons_action[weapon.hash] ~= nil then
            if weapons_action[weapon.hash]:isValid() then
                weapons_action[weapon.hash]:delete()
            end
        end
    end
    weapons_action = {}
    attachments_action = {}
    weapon_deletes = {}
    cosmetics_list = {}
    tints_slider = {}
    livery_action_divider = {}
    livery_actions = {}
    livery_colour_slider = {}
    livery = {}

    for _, weapon in weapons_table do
        local category = weapon.category
        local weapon_name = util.get_label_text(weapon.label_key)
        local weapon_hash = weapon.hash
        if WEAPON.HAS_PED_GOT_WEAPON(players.user_ped(), weapon_hash, false) then
            generate_for_new_weapon(category, weapon_name, weapon_hash, false)
        else
            weapons_action[weapon_hash] = categories[category]:action(weapon_name .. " (not equipped)", {}, "Equip " .. weapon_name,
                    function()
                        weapons_action[weapon_hash]:delete()
                        equip_weapon(category, weapon_name, weapon_hash)
                    end
            )
        end
        WEAPON.ADD_AMMO_TO_PED(players.user_ped(), weapon_hash, 10) --- if a special ammo type has been equipped.. it should get some ammo
    end
end

function equip_comp(category, weapon_name, weapon_hash, attachment_hash)
    WEAPON.GIVE_WEAPON_COMPONENT_TO_PED(players.user_ped(), weapon_hash, attachment_hash)
end

function equip_weapon(category, weapon_name, weapon_hash)
    WEAPON.GIVE_WEAPON_TO_PED(players.user_ped(), weapon_hash, 10, false, true)
    util.yield(10)
    weapon_deletes[weapon_name] = nil
    generate_for_new_weapon(category, weapon_name, weapon_hash, true)
end

function generate_for_new_weapon(category, weapon_name, weapon_hash, focus)
    weapons_action[weapon_hash] = categories[category]:list(weapon_name, {}, "Edit attachments for " .. weapon_name,
            function()
                WEAPON.SET_CURRENT_PED_WEAPON(players.user_ped(), weapon_hash, true)
                generate_attachments(category, weapon_name, weapon_hash)
            end
    )
    if focus then
        weapons_action[weapon_hash]:trigger()
    end
end

function generate_cosmetics(weapon_hash, weapon_name)
    -- clear old cosmetic stuff
    livery_action_divider = {}
    livery_colour_slider = {}
    livery = {}
    tints_slider = {}
    livery_actions = {}

    if cosmetics_list[weapon_hash] ~= nil then
        if cosmetics_list[weapon_hash]:isValid() then
            cosmetics_list[weapon_hash]:delete()
        end
        regenerated_cosmetics = true
    end
    cosmetics_list[weapon_hash] = weapons_action[weapon_hash]:list("cosmetics", {}, "",
            function()
                local tint_count = WEAPON.GET_WEAPON_TINT_COUNT(weapon_hash)
                local cur_tint = WEAPON.GET_PED_WEAPON_TINT_INDEX(player, weapon_hash)

                if tints_slider[weapon_hash] == nil then
                    tints_slider[weapon_hash] = cosmetics_list[weapon_hash]:slider("Tint", {}, "Choose the tint for your " .. weapon_name, 0, tint_count - 1, cur_tint, 1,
                            function(change)
                                WEAPON.SET_PED_WEAPON_TINT_INDEX(player, weapon_hash, change)
                            end
                    )
                end

                --- livery colour
                local has_liveries = false
                for livery_hash, _ in liveries_dict do
                    if WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, livery_hash) then
                        has_liveries = true
                        break
                    end
                end


                if has_liveries then
                    --- get current camo component
                    for hash, _ in liveries_dict do
                        if WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(player, weapon_hash, hash) then
                            livery[weapon_hash] = hash
                            break
                        end
                    end
                    --- livery colour slider
                    if livery_colour_slider[weapon_hash] == nil then
                        local cur_ctint_colour = WEAPON.GET_PED_WEAPON_COMPONENT_TINT_INDEX(player, weapon_hash, livery[weapon_hash])
                        if cur_ctint_colour == -1 then cur_ctint_colour = 0 end
                        livery_colour_slider[weapon_hash] = cosmetics_list[weapon_hash]:slider("Livery Colour", {}, "change the colour of your livery", 0, 31, cur_ctint_colour, 1,
                                function(index)
                                    if livery[weapon_hash] == nil then
                                        util.toast("There's no livery on your weapon")
                                    else
                                        WEAPON.SET_PED_WEAPON_COMPONENT_TINT_INDEX(player, weapon_hash, livery[weapon_hash], index)
                                    end
                                end
                        )
                    end

                    if livery_action_divider[weapon_hash] == nil then
                        livery_action_divider[weapon_hash] = cosmetics_list[weapon_hash]:divider("Liveries")
                    end
                    --- livery equip actions
                    for livery_hash, label in liveries_dict do
                        if WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, livery_hash) and livery_actions[weapon_hash..livery_hash] == nil then
                            livery_actions[weapon_hash .. livery_hash] = cosmetics_list[weapon_hash]:action(util.get_label_text(label), {}, "",
                                    function()
                                        livery[weapon_hash] = livery_hash
                                        equip_comp(category, weapon_name, weapon_hash, livery_hash)
                                        WEAPON.SET_PED_WEAPON_COMPONENT_TINT_INDEX(player, weapon_hash, livery[weapon_hash], livery_colour_slider[weapon_hash].value)
                                    end
                            )
                        end
                    end
                end
            end
    )
end

function generate_attachments(category, weapon_name, weapon_hash)
    if weapon_deletes[weapon_name] == nil then
        weapon_deletes[weapon_name] = weapons_action[weapon_hash]:action("Delete " .. weapon_name, {}, "",
                function()
                    WEAPON.REMOVE_WEAPON_FROM_PED(players.user_ped(), weapon_hash)
                    cosmetics_list[weapon_hash]:delete()
                    cosmetics_list[weapon_hash] = nil
                    livery_action_divider[weapon_hash] = nil
                    weapons_action[weapon_hash]:delete()

                    util.toast(weapon_name .. " has been deleted")
                    weapons_action[weapon_hash] = categories[category]:action(weapon_name .. " (not equipped)", {}, "Equip " .. weapon_name,
                            function()
                                for a_key, _ in attachments_action do
                                    if string.find(a_key, weapon_hash) ~= nil then
                                        attachments_action[a_key] = nil
                                    end
                                end
                                menu.delete(weapons_action[weapon_hash])
                                equip_weapon(category, weapon_name, weapon_hash)
                                weapon_deletes[weapon_name] = nil
                            end
                    )
                    weapons_action[weapon_hash]:focus()
                end
        )
    end

    local has_attachments = false
    for livery_hash, _ in attachments_dict do
        if WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, livery_hash) then
            has_attachments = true
            break
        end
    end

    if cosmetics_list[weapon_hash] == nil then
        generate_cosmetics(weapon_hash, weapon_name)
        if has_attachments then
            weapons_action[weapon_hash]:divider("Attachments")
        end
    end

    for attachment_hash, attachment_label in attachments_dict do
        local attachment_name = util.get_label_text(attachment_label)
        if (WEAPON.DOES_WEAPON_TAKE_WEAPON_COMPONENT(weapon_hash, attachment_hash)) then
            if (attachments_action[weapon_hash .. " " .. attachment_hash] ~= nil) then attachments_action[weapon_hash .. " " .. attachment_hash]:delete() end
            attachments_action[weapon_hash .. " " .. attachment_hash] = weapons_action[weapon_hash]:action(attachment_name, {}, "Equip " .. attachment_name .. " on your " .. weapon_name,
                    function()
                        equip_comp(category, weapon_name, weapon_hash, attachment_hash)
                        if (string.find(attachment_label, "CLIP") ~= nil or string.find(attachment_label, "SHELL") ~= nil) and WEAPON.HAS_PED_GOT_WEAPON_COMPONENT(players.user_ped(), weapon_hash, attachment_hash) then --last condition could be unnecessary
                            --- if the type of rounds is changed, the player needs some bullets of the new type to be able to use them
                            WEAPON.ADD_AMMO_TO_PED(players.user_ped(), weapon_hash, 10)
                            --util.toast("gave " .. weapon_name .. " some rounds because an ammo type was equipped")
                        end
                    end
            )
        end
    end
end








categories = {}
weapons_action = {}
attachments_action = {}
weapon_deletes = {}
cosmetics_list = {}
tints_slider = {}
livery_action_divider = {}
livery_actions = {}
livery_colour_slider = {}
livery = {}
for _, weapon in weapons_table do
    local category = weapon.category
    if categories[category] == nil then
        categories[category] = root:list(category, {}, "Edit weapons of the " .. category .. " category")
    end
end
regen_menu()

util.yield(1000)--testing has shown: needs a small delay.. ok then, but that should finally work for people directly loading into online
if do_autoload then
    load_loadout:trigger()
end

while true do
    if NETWORK.NETWORK_IS_IN_SESSION() == false then
        while NETWORK.NETWORK_IS_IN_SESSION() == false or util.is_session_transition_active() do
            util.yield(1000)
        end
        util.yield(1000)
        -- people didn't like the long loading time, but weapons/attachments don't seem to properly get deleted and loaded directly on spawn. So we'll just wait for them to do their first step
		spawnpos = players.get_position(players.user())
        repeat
            local pos = players.get_position(players.user())
            util.yield(500)
        until spawnpos.x ~= pos.x and spawnpos.y ~= pos.y
        if do_autoload then
            load_loadout:trigger()
        else
            regen_menu()
        end
    end
    util.yield(100)
end
