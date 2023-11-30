return {
    useTarget = GetConvar('UseTarget', 'false') == 'true',
    maxDrops = 10, -- amount of locations before being forced to return to station to reload
    vehicles = {
        [`rumpo`] = 'Dumbo Delivery',
    }
}