local Translations = {
    error = {
        no_deposit = '$%{value} Deposition krävs',
        cancelled = 'Avbruten',
        vehicle_not_correct = 'Detta är inte ett kommersiellt fordon!',
        no_driver = 'Du måste vara föraren för att göra det här..',
        no_work_done = 'Du har inte gjort något arbete än..',
        backdoors_not_open = 'The backdoors of the vehicle aren\'t open',
        get_out_vehicle = 'You need to step out of the vehicle to perform this action',
        too_far_from_trunk = 'You need to grab the boxes from the trunk of your vehicle',
        too_far_from_delivery = 'You need to be closer to the delivery point'
    },
    success = {
        paid_with_cash = '$%{value} Deposition betalad med kontanter',
        paid_with_bank = '$%{value} Deposition betalad från banken',
        refund_to_cash = '$%{value} Deposition återbetalad med kontanter',
        you_earned = 'Du tjänade $%{value}',
        payslip_time = 'Du har åkt till alla butiker.. Dags att inkassera!',
    },
    menu = {
        header = 'Tillgängliga fordon',
        close_menu = '⬅ Stäng',
    },
    mission = {
        store_reached = 'Butik nådd, ta en låda i bagageutrymmet med [E] och leverera till markör',
        take_box = 'Ta en låda',
        deliver_box = 'Leverera',
        another_box = 'Ta en till låda',
        goto_next_point = 'Du har levererat alla lådor, åk till nästa ställe',
        return_to_station = 'You Have Delivered All Products, Return to Station',
        job_completed = 'You Have Completed Your Route, Please Collect Your Pay Cheque'
    },
    info = {
        pickup_paycheck = '[E] - Pick up paycheck',
        store_vehicle = '[E] - Store the Vehicle',
        vehicles = '[E] - Vehicles',
        deliver_to_store = 'Deliver the box to the store'
    }
}

if GetConvar('qb_locale', 'en') == 'sv' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
