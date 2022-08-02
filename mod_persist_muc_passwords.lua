local store = module:open_store("persistent_muc_passwds", "map");
if not store then
    module:log("error","Failed to open storage.");
    return nil;
end

module:hook("muc-room-destroyed", function (event)
    local room = event.room;
    local password = room:get_password(room);

    if password then
        module:log("debug", "Room %s with pass %s about to be destroyed", room, password);
        if not store then
                module:log("debug","failed to open store on destroy");
            return nil;
        end
        
        local now = os.time();
        store:set(room.jid, "last_used", now);
        store:set(room.jid, "password" , password);
        module:log("debug", "Stored %s, %s for room %s", password, now, room);
    elseif store:get(room.jid, "password") then
	    -- moderator removed old password from restored room, delete stored entry
        store:set(room.jid, "last_used", nil);
        store:set(room.jid, "password" , nil);
        module:log("debug", "Deleted stored entries for room %s", room);
    end

    return nil; -- can be removed
end, 0);

module:hook("muc-room-created", function (event)    
    local room = event.room;
    module:log("debug","hooked room create for %s", room);

    local old_pass = store:get(room.jid, "password");
    if not old_pass then
        module:log("debug", "No password to restore for room %s", room);
	return nil;
    end

    module:log("debug", "Loaded old password '%s' for room %s", old_pass, room);
    local last_used = store:get(room.jid, "last_used");
    if not last_used then
        module:log("debug", "No stored timestamp found for room %s. Removing stored entry.", room, err);
        store:set(room.jid, "last_used", nil);
        store:set(room.jid, "password" , nil);
	return nil;
    end

    if is_room_stale(last_used) then
        -- delete entry
        store:set(room.jid, "last_used", nil);
        store:set(room.jid, "password" , nil);
	module:log("debug", "deleted password for stale room %s", room); 
	return nil;
    end

    -- restore old pass for the mucroom
    local success = room:set_password(old_pass);
    if not success then 
        module:log("warn", "Failed to set old password %s for restored room %s.", old_pass, room);
    end
    
    module:log("debug", "Set password '%s' for restored room %s.", old_pass, room);
    return nil;
end, 0);

function is_room_stale(last_used)
    local days = module:get_option_number("days_to_persist_muc_passwds", 30);
    module:log("debug", "Function is_stale() called with '%s', days is set to %s", last_used, days);
    local daysfrom = os.difftime(os.time(), last_used) / (24 * 60 * 60); 
    local roomage = math.floor(daysfrom) ;
    module:log("debug", "roomage is %s days", roomage);
    if roomage then
        return roomage > days; 
    end
    return false;
end
