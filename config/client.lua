return {
    useTarget = GetConvar('UseTarget', 'false') == 'true',
    vehicles = {
        [`rumpo`] = 'Dumbo Delivery',
    },
    ---Default behaviour: Plays an emote using scully_emotemenu by command name
    ---Change to the export your emote menu is using if not using scully_emotemenu
    ---@param emote string The emote command to play
    ---@return nil
    playEmoteByCommand = function (emote)
        return exports.scully_emotemenu:playEmoteByCommand(emote)
    end,
    ---Default behaviour: Cancels current emote using scully_emotemenu
    ---Change to the export your emote menu is using if not using scully_emotemenu
    ---@return nil
    cancelEmote = function ()
        return exports.scully_emotemenu:cancelEmote()
    end
}
