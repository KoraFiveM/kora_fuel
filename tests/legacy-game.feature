# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_fuel — game tests

  @kora_fuel @legacy:fuel-starts-clean @target:1 @needs:admin @manual
  Scenario: Resource starts cleanly
    """
    Needs a Mod.
    1. Restart the server (or ensure kora_fuel) and watch the server console.
    2. Join, open F8 and scroll through the client console.
    Expect: no kora_fuel errors or red text, and no yellow "[kora_fuel] Skipping EV charging station" warning. No "charger prop ... was not spawned" line when you drive near a charging station.
    """
    When I manually: restart the kora_fuel resource (or ensure it) and watch the server console
    And I manually: join the server, open F8 and scroll through the client console
    And I manually: drive near a charging station
    And the F8 console should show no errors
    Then I confirm: there are no kora_fuel errors or red text in the server console
    And I confirm: there is no yellow "[kora_fuel] Skipping EV charging station" warning
    And I confirm: there is no "charger prop ... was not spawned" line when I drive near a charging station

  @kora_fuel @legacy:fuel-gas-blips @target:2 @checklist @checklist:kora_fuel:fuel-blips @cat:vehicles @manual
  Scenario: Gas station blips on the map
    """
    1. Open the pause map and look around Los Santos, Sandy Shores, Grapeseed and the Route 68 area.
    Expect: every gas station has a red fuel-can blip named "Gas Station". A forecourt shows one blip, not two stacked on top of each other. On the minimap, blips only show when you are close. Note any gas station with no blip.
    Also checklist kora_fuel:fuel-blips (Gas Station map blips): Open the map: Gas Station blips appear at petrol stations, nearby ones merged into one blip.
    """
    When I manually: open the pause map and look around Los Santos, Sandy Shores, Grapeseed and the Route 68 area
    Then I confirm: every gas station has a red fuel-can blip named "Gas Station"
    And I confirm: each forecourt shows one blip, not two stacked on top of each other
    And I confirm: on the minimap, blips only show when I am close
    And I confirm: I have noted any gas station with no blip

  @kora_fuel @legacy:fuel-ev-blips @target:2 @manual
  Scenario: EV charging station blips
    """
    1. Open the pause map.
    2. Find the EV charger blips (lightning bolt icon) and hover/click a few.
    Expect: 13 of them, each named "EV Charging Station - <place>", e.g. "EV Charging Station - Little Seoul", "- Paleto Bay", "- Grapeseed". Each sits on a gas station. They are listed under the Fuel category on the pause map and only show on the minimap when you are nearby.
    """
    When I manually: open the pause map
    And I manually: find the EV charger blips (lightning bolt icon) and hover or click a few
    Then I confirm: there are 13 EV charger blips, each named "EV Charging Station - <place>", e.g. "EV Charging Station - Little Seoul", "- Paleto Bay", "- Grapeseed"
    And I confirm: each EV charger blip sits on a gas station
    And I confirm: they are listed under the Fuel category on the pause map
    And I confirm: they only show on the minimap when I am nearby

  @kora_fuel @legacy:fuel-blips-toggle @target:1
  Scenario: Hide fuel blips with /blips
    """
    1. Type /blips in chat.
    2. Hide the Fuel category, then check the pause map.
    3. Show it again.
    Expect: both the EV Charging Station and the red Gas Station blips disappear, and come back when you show the category again.
    """
    When I run the command "/blips"
    And I manually: hide the Fuel category, then check the pause map
    Then I confirm: both the EV Charging Station and the red Gas Station blips disappear
    When I manually: show the Fuel category again
    Then I confirm: both the EV Charging Station and the Gas Station blips come back

  @kora_fuel @legacy:fuel-pump-option @target:2 @checklist @checklist:kora_fuel:pump-refuel-target @cat:vehicles
  Scenario: Pump shows Service nearby vehicle
    """
    1. Park any petrol car next to a pump at a gas station and get out.
    2. Hold Alt and aim at the pump from close by (about 2 m).
    Expect: the option "Service nearby vehicle" appears. Step back a few metres and it goes away. It works on every pump at the station, including the old-style pumps at Grapeseed.
    Also checklist kora_fuel:pump-refuel-target (Refuel at a petrol pump): Park next to a gas pump (prop_gas_pump), hold Alt to target it and choose 'Refuel vehicle' / 'Service nearby vehicle'.
    """
    Given I am at "petrol_station"
    And I am in the driver seat of a "test_car"
    When I get out of the vehicle
    And I manually: hold Alt and aim at the pump from about 2 m away
    Then I confirm: the option "Service nearby vehicle" appears
    When I manually: step back a few metres
    Then I confirm: the option "Service nearby vehicle" goes away
    When I manually: try the same on other pumps at the station, including the old-style pumps at Grapeseed
    Then I confirm: the option works on every pump at the station

  @kora_fuel @legacy:fuel-pump-menu @target:2
  Scenario: Refuel menu shows level and price
    """
    1. Drive a petrol car for a minute so it is not full, park at a pump, turn the engine off (G) and get out.
    2. Alt + aim at the pump, pick "Service nearby vehicle".
    Expect: a "Refuel vehicle" panel, "Petrol pump", with a Fuel level bar (e.g. 87 / 100), "Price per unit $2.00", a Total Price for the missing amount, an "Amount to add" slider, a "Pay with" choice of Cash or Bank and a "Fill up" button. The bar is red at 15 or lower.
    """
    Given I am at "petrol_station"
    And I am in the driver seat of a "test_car"
    And the vehicle has 60% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt and aim at the pump
    And I select the "Service nearby vehicle" target option
    Then the "qbfuel:pump" app opens
    And I confirm: the panel is titled "Refuel vehicle" and "Petrol pump"
    And I confirm: it shows a Fuel level bar (e.g. 87 / 100) and "Price per unit $2.00"
    And I confirm: it shows a Total Price for the missing amount and an "Amount to add" slider
    And I confirm: it shows a "Pay with" choice of Cash or Bank and a "Fill up" button
    And I confirm: the Fuel level bar is red at 15 or lower

  @kora_fuel @legacy:fuel-refuel-full @target:2 @checklist @checklist:kora_fuel:refuel-progress @cat:vehicles
  Scenario: Full refuel with cash
    """
    1. With a petrol car that is not full, open the refuel menu at a pump.
    2. Leave the slider at max, Pay with Cash, press Fill up.
    Expect: your character turns to the car and does a pouring animation holding a fuel nozzle for a few seconds while a "Refuelling vehicle" bar runs. Then a Fuel toast "Vehicle refuelled for $X." X matches the Total Price ($2 per unit), your cash drops by X and the fuel gauge reads 100.
    Also checklist kora_fuel:refuel-progress (Refuelling progress bar and result): After Confirm a 'Refuelling vehicle' progress runs, then fuel level rises, payment is taken and a Fuel notification appears.
    """
    Given I am at "petrol_station"
    And my cash balance is at least 500
    And I am in the driver seat of a "test_car"
    And the vehicle has 40% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt, aim at the pump and pick "Service nearby vehicle" to open the refuel menu
    And I manually: leave the slider at max, choose Pay with Cash and press Fill up
    Then I confirm: my character turns to the car and does a pouring animation holding a fuel nozzle for a few seconds
    And a progress bar labelled "Refuelling vehicle" should run
    And I should see a notification containing "Vehicle refuelled for $"
    And I confirm: the amount X in the toast matches the Total Price ($2 per unit)
    And I confirm: my cash dropped by X
    And the vehicle fuel should be 100%

  @kora_fuel @legacy:fuel-refuel-bank @target:2
  Scenario: Partial refuel paid by bank
    """
    1. Open the refuel menu with a car that is missing at least 10 units.
    2. Move the slider to 5 units and watch Total Price (should be $10).
    3. Pay with Bank, press Fill up.
    Expect: the toast says "Vehicle refuelled for $10.", only your bank goes down by $10 (cash unchanged) and the gauge goes up by 5 only.
    """
    Given I am at "petrol_station"
    And my cash balance is 500
    And my bank balance is at least 1000
    And I am in the driver seat of a "test_car"
    And the vehicle has 50% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt, aim at the pump and pick "Service nearby vehicle" to open the refuel menu
    And I manually: move the slider to 5 units
    Then I confirm: Total Price shows $10
    When I manually: choose Pay with Bank and press Fill up
    Then I should see a notification containing "Vehicle refuelled for $10."
    And my bank balance should have changed by -10
    And my cash balance should have changed by 0
    And I confirm: the fuel gauge goes up by 5 only

  @kora_fuel @legacy:fuel-no-money @target:2 @needs:admin @checklist @checklist:kora_fuel:insufficient-funds @cat:vehicles
  Scenario: Not enough money to refuel
    """
    Needs a Mod if you can't get one account below the price.
    1. Make sure your Cash (or Bank) is less than the Total Price shown.
    2. Open the refuel menu, pick that account, press Fill up.
    Expect: a red Fuel toast "Insufficient funds." No money is taken and the fuel level does not change. Paying with the other account (if it has enough) works.
    Also checklist kora_fuel:insufficient-funds (Not enough money refused): Try to buy fuel with too little cash/bank: server refuses and no fuel is added.
    """
    Given I am at "petrol_station"
    And my cash balance is 0
    And I am in the driver seat of a "test_car"
    And the vehicle has 40% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt, aim at the pump and pick "Service nearby vehicle" to open the refuel menu
    And I manually: choose Pay with Cash and press Fill up
    Then I should see an error notification
    And I should see a notification containing "Insufficient funds."
    And my cash balance should be 0
    And I confirm: the fuel level does not change
    When I manually: pay with the other account (if it has enough) and press Fill up
    Then I confirm: paying with the other account works

  @kora_fuel @legacy:fuel-tank-full @target:2
  Scenario: Already full tank
    """
    1. Park a car with the gauge at 100 (a fresh Mod-spawned car or one you just filled) at a pump, engine off.
    2. Alt + aim at the pump, pick "Service nearby vehicle".
    Expect: no menu opens, you get a Fuel toast "Vehicle is already full." No money is taken.
    """
    Given I am at "petrol_station"
    And my cash balance is at least 100
    And I am in the driver seat of a "test_car"
    And the vehicle has 100% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt and aim at the pump
    And I select the "Service nearby vehicle" target option
    Then I confirm: no menu opens
    And I should see a notification containing "Vehicle is already full."
    And my cash balance should have changed by 0

  @kora_fuel @legacy:fuel-engine-on @target:2 @checklist @checklist:kora_fuel:engine-off-required @cat:vehicles
  Scenario: Engine running blocks refuelling
    """
    1. Park at a pump and get out leaving the engine running (hold the exit key so it stays on).
    2. Alt + aim at the pump, pick "Service nearby vehicle".
    Expect: red toast "Switch the engine off before servicing the vehicle." and no menu. Turn the engine off (get in, press G, get out) and it opens normally.
    Also checklist kora_fuel:engine-off-required (Engine must be off to refuel): Try to refuel/charge with the engine running: error shown; turn the engine off and it works.
    """
    Given I am at "petrol_station"
    And I am in the driver seat of a "test_car"
    And the vehicle has 40% fuel
    And the vehicle engine is running
    When I manually: hold the exit key so the engine stays running and get out at the pump
    And I manually: hold Alt and aim at the pump
    And I select the "Service nearby vehicle" target option
    Then I should see an error notification
    And I should see a notification containing "Switch the engine off before servicing the vehicle."
    And I confirm: no menu opens
    When I get in the vehicle
    And I turn the engine off
    And I get out of the vehicle
    And I manually: hold Alt, aim at the pump and pick "Service nearby vehicle"
    Then the "qbfuel:pump" app opens

  @kora_fuel @legacy:fuel-no-vehicle @target:2
  Scenario: Pump with no car nearby
    """
    1. Walk to a pump on foot with no vehicle within about 6 m.
    2. Alt + aim at the pump, pick "Service nearby vehicle".
    Expect: red toast "Park a vehicle next to the pump or charger." Then park a car about 10 m away and try again: same message (the car must be close).
    """
    Given I am at "petrol_station"
    When I manually: walk to a pump on foot with no vehicle within about 6 m
    And I manually: hold Alt and aim at the pump
    And I select the "Service nearby vehicle" target option
    Then I should see an error notification
    And I should see a notification containing "Park a vehicle next to the pump or charger."
    When I manually: park a car about 10 m away from the pump
    And I manually: hold Alt, aim at the pump and pick "Service nearby vehicle" again
    Then I should see a notification containing "Park a vehicle next to the pump or charger."

  @kora_fuel @legacy:fuel-cancel-refuel @target:2
  Scenario: Cancel refuelling mid-way
    """
    1. With a car missing 50+ units, start a full refuel (Fill up).
    2. While "Refuelling vehicle" runs, press X (or Backspace/Esc).
    Expect: the animation and nozzle stop, a toast "Refuelling vehicle cancelled." No money is taken and the fuel level is unchanged. You can't walk away during the bar (movement is locked) until you cancel.
    """
    Given I am at "petrol_station"
    And my cash balance is at least 500
    And I am in the driver seat of a "test_car"
    And the vehicle has 30% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt, aim at the pump, pick "Service nearby vehicle" and press Fill up for a full refuel
    Then a progress bar labelled "Refuelling vehicle" should run
    When I manually: while the bar runs, try to walk away
    Then I confirm: my movement is locked during the bar
    When I cancel the progress bar
    Then I confirm: the animation and nozzle stop
    And I should see a notification containing "Refuelling vehicle cancelled."
    And my cash balance should have changed by 0
    And I confirm: the fuel level is unchanged

  @kora_fuel @legacy:fuel-refuel-time @target:1
  Scenario: Refuel time scales with amount
    """
    1. Refuel just 1 unit and time the bar.
    2. Refuel about 40 units and time it.
    Expect: 1 unit takes about 1.5 s (minimum), 40 units about 5 s, a nearly empty tank (100 units) about 12-13 s. Report times that are very different.
    """
    Given I am at "petrol_station"
    And my cash balance is at least 500
    And I am in the driver seat of a "test_car"
    And the vehicle has 5% fuel
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: open the refuel menu at the pump, refuel just 1 unit and time the bar
    Then I confirm: 1 unit takes about 1.5 s (minimum)
    When I manually: refuel about 40 units and time the bar
    Then I confirm: 40 units take about 5 s
    And I confirm: a nearly empty tank (100 units) takes about 12-13 s, and I report times that are very different

  @kora_fuel @legacy:fuel-all-stations @target:2
  Scenario: Pumps work at every gas station
    """
    1. Try "Service nearby vehicle" with a not-full petrol car at as many stations as you can. Be sure to try Pacific Bluffs (Xero by the beach), Morningwood/Del Perro, Richman Glen, Route 68 near Fort Zancudo and both Paleto Bay stations.
    Expect: the refuel menu opens at every one and each has a Gas Station blip. Report the station name if you get "Move to a fuel station or charging point first." or it has no blip.
    """
    Given I am in the driver seat of a "test_car"
    And the vehicle has 40% fuel
    When I manually: go to a gas station such as Pacific Bluffs (Xero by the beach), Morningwood/Del Perro, Richman Glen, Route 68 near Fort Zancudo or either Paleto Bay station
    And I manually: try "Service nearby vehicle" at the pump with a not-full petrol car
    Then the "qbfuel:pump" app opens
    And I confirm: the refuel menu opens at every station I try
    And I confirm: each station has a Gas Station blip
    And I confirm: I have noted the station name of any "Move to a fuel station or charging point first." message or missing blip

  @kora_fuel @legacy:fuel-ev-at-pump @target:2 @needs:admin @checklist @checklist:kora_fuel:ev-at-pump @cat:vehicles
  Scenario: EV at a petrol pump gets GPS to charger
    """
    Needs a Mod (spawn an electric car, e.g. a Surge, Voltic or Neon).
    1. Park the EV at a petrol pump in the city, engine off, get out.
    2. Alt + aim at the pump, pick "Service nearby vehicle".
    Expect: no menu. A Charging toast "Electric vehicles cannot use petrol pumps. Use an EV charging station. Nearest: <place> (<distance> m). A GPS waypoint has been set to it." The map waypoint is on that charging station and the distance looks right.
    Also checklist kora_fuel:ev-at-pump (EV refused at petrol pump): Use a petrol pump with an EV: message says use an EV charging station, GPS waypoint set to the nearest station.
    """
    Given I am at "petrol_station"
    And I am in the driver seat of a "voltic"
    And the vehicle engine is off
    When I get out of the vehicle
    And I manually: hold Alt and aim at the pump
    And I select the "Service nearby vehicle" target option
    Then I confirm: no menu opens
    And I should see a notification containing "Electric vehicles cannot use petrol pumps. Use an EV charging station."
    And I confirm: the toast reads "Nearest: <place> (<distance> m). A GPS waypoint has been set to it."
    And I confirm: the map waypoint is on that charging station and the distance looks right

  @kora_fuel @legacy:fuel-ev-gps-km @target:1 @needs:admin
  Scenario: EV pump message far from a charger
    """
    Needs a Mod (electric car).
    1. Take the EV to the gas station on the highway east of Paleto Bay (near Mount Chiliad) and use a pump.
    Expect: the message names the nearest station with a distance in km (likely "Grapeseed (1.5 km)" or similar) and the waypoint points to it. Check the named station really is the closest charger blip.
    """
    When I go to "petrol_station"
    And I manually: ask a Mod to give me an electric car and get in it
    And I manually: use a petrol pump at the gas station
    Then I should see a notification containing "Nearest:"
    And I confirm: the message names the nearest station with a distance in km
    And I confirm: my map waypoint points to that station
    And I confirm: the named station is the closest charger blip

  @kora_fuel @legacy:fuel-charger-prop @target:2 @checklist @checklist:kora_fuel:charger-props @cat:vehicles
  Scenario: Charger machine appears at stations
    """
    1. Drive to a gas station with an EV Charging Station blip (e.g. Little Seoul).
    Expect: a pay-and-display style machine stands on the forecourt where the air pump would be, upright on the ground (not floating or sunk) and not overlapping the air pump, which is hidden. Drive far away (100 m+) and come back: it reappears in the same spot.
    Also checklist kora_fuel:charger-props (Charger prop streams in): Approach an EV station within 75m: a charger prop spawns and the forecourt air pump is hidden; it despawns when you leave.
    """
    When I go to "ev_charger"
    Then I confirm: a pay-and-display style machine stands on the forecourt where the air pump would be
    And I confirm: the machine is upright on the ground, not floating or sunk
    And I confirm: the machine does not overlap the air pump, which is hidden
    When I manually: drive 100 m or more away and come back
    Then I confirm: the machine reappears in the same spot

  @kora_fuel @legacy:fuel-charge-ev @target:2 @needs:admin @checklist @checklist:kora_fuel:ev-charging-station @cat:vehicles
  Scenario: Charge an EV at a charger
    """
    Needs a Mod (electric car).
    1. Drive the EV a bit so it isn't 100, park by the charger machine, engine off (G).
    2. Hold Alt, aim at the machine, pick "Charge vehicle".
    Expect: a "Charge vehicle" panel, "Battery charge - <station>", a Charge level bar, "$1.25 per unit ... Totals are whole dollars." and a "Charge" button. Pay: the bar says "Charging vehicle", then "Vehicle charged for $X." in a Charging toast and the HUD Charge goes up.
    Also checklist kora_fuel:ev-charging-station (Charge an EV at a charging station): Park a Voltic/Neon etc. by a charger prop (e.g. Murrieta Heights), Alt-target it and choose 'Charge vehicle'; pay and charge.
    """
    Given I am at "ev_charger"
    When I manually: ask a Mod to give me an electric car and drive it a bit so it is not at 100 charge
    And I manually: park by the charger machine
    And I turn the engine off
    And I manually: hold Alt, aim at the machine and pick "Charge vehicle"
    Then the "qbfuel:pump" app opens
    And I confirm: the panel shows "Battery charge - <station>", a Charge level bar, "$1.25 per unit" with "Totals are whole dollars." and a "Charge" button
    When I manually: pay by pressing the Charge button
    Then a progress bar labelled "Charging vehicle" should run
    And I should see a notification containing "Vehicle charged for"
    And I should see a notification titled "Charging"
    And I confirm: my HUD Charge goes up

  @kora_fuel @legacy:fuel-charge-rounding @target:2 @needs:admin
  Scenario: Charging total rounds up to whole dollars
    """
    Needs a Mod (electric car at 96 or lower).
    1. Open the Charge vehicle menu at a charger.
    2. Set the slider to 1, then 3, then 4 units and read Total Price each time.
    Expect: 1 unit = $2 "1 unit ($1.25 rounded up)", 3 units = $4 "($3.75 rounded up)", 4 units = $5 with no rounding note. Charge 3 units: you pay exactly $4.
    """
    Given I am at "ev_charger"
    When I manually: ask a Mod to give me an electric car at 96 charge or lower
    And I manually: open the Charge vehicle menu at the charger
    Then the "qbfuel:pump" app opens
    When I manually: set the slider to 1 unit and read Total Price
    Then I confirm: 1 unit shows $2 with "1 unit ($1.25 rounded up)"
    When I manually: set the slider to 3 units and read Total Price
    Then I confirm: 3 units shows $4 with "($3.75 rounded up)"
    When I manually: set the slider to 4 units and read Total Price
    Then I confirm: 4 units shows $5 with no rounding note
    When I manually: set the slider to 3 units and charge
    Then I confirm: I pay exactly $4

  @kora_fuel @legacy:fuel-charger-petrol @target:2 @checklist @checklist:kora_fuel:charge-option-hidden @cat:vehicles
  Scenario: Charger ignores petrol cars and full EVs
    """
    1. Park a petrol car next to a charger machine, engine off. Hold Alt and aim at the machine.
    2. (Needs a Mod) Do the same with an EV at 100 charge, e.g. straight after charging it.
    Expect: no "Charge vehicle" option in either case. Only a not-full electric car brings up the option.
    Also checklist kora_fuel:charge-option-hidden (Charge option hidden when not applicable): At a charger with a petrol vehicle or a fully charged EV the 'Charge vehicle' option does not appear.
    """
    Given I am at "ev_charger"
    And a "sultan" is spawned in front of me
    And the vehicle engine is off
    When I manually: park the petrol car next to the charger machine
    And I manually: hold Alt and aim at the machine
    Then I confirm: there is no "Charge vehicle" option
    When I manually: ask a Mod to give me an electric car at 100 charge and park it next to the charger with the engine off
    And I manually: hold Alt and aim at the machine
    Then I confirm: there is no "Charge vehicle" option

  @kora_fuel @legacy:fuel-charge-in-car @target:1 @needs:admin
  Scenario: Charge while sitting in the EV
    """
    Needs a Mod (electric car, not full).
    1. Park right next to a charger and stay in the driver seat with the engine off (G).
    2. Hold Alt and aim at the charger from inside.
    Expect: "Charge vehicle" appears and charging works. Try with the engine on: you get "Switch the engine off before servicing the vehicle."
    """
    Given I am at "ev_charger"
    When I manually: ask a Mod to give me an electric car that is not full
    And I manually: park right next to the charger and stay in the driver seat
    And I turn the engine off
    And I manually: hold Alt and aim at the charger from inside
    Then I confirm: "Charge vehicle" appears and charging works
    When I turn the engine on
    And I manually: try to charge again
    Then I should see a notification containing "Switch the engine off before servicing the vehicle."

  @kora_fuel @legacy:fuel-consumption @target:2 @checklist @checklist:kora_fuel:fuel-consumption @cat:vehicles
  Scenario: Fuel use depends on speed and car
    """
    1. Note the gauge, idle with the engine on for 2 minutes: it should barely move (under 1).
    2. Drive a normal car on the highway at about 160 km/h for 2 minutes: it drops roughly 2-4.
    3. Do the same on a motorbike and in a supercar.
    Expect: bikes use the least, supercars the most (several times a bike). Engine off: no drop at all.
    Also checklist kora_fuel:fuel-consumption (Fuel drains while driving): Drive a vehicle and watch the HUD fuel gauge: it drops faster at speed and by vehicle class, and slowly when idling.
    """
    Given I am in the driver seat of a "sultan"
    When I manually: drive the vehicle and watch the HUD fuel gauge
    Then I confirm: the fuel gauge drops faster at speed and by vehicle class
    When I manually: idle with the engine on and watch the HUD fuel gauge
    Then I confirm: the fuel gauge drops slowly when idling

  @kora_fuel @legacy:fuel-empty-tank @target:1 @checklist @checklist:kora_fuel:empty-tank @cat:vehicles
  Scenario: Running out of fuel stops the engine
    """
    Niche, takes a while.
    1. Drive a thirsty car (supercar or truck) fast until the gauge reaches 0.
    Expect: the engine cuts out at 0 and the car won't drive. Push/tow it to a pump (or refuel where it stopped if in range): after refuelling the engine starts again with G.
    Also checklist kora_fuel:empty-tank (Vehicle stops with empty tank): Drive until fuel reaches 0 (or SetFuel to 0): the engine cuts out and cannot be driven.
    """
    Given I am in the driver seat of a "sultan"
    When I manually: drive fast until the fuel gauge reaches 0
    Then the vehicle fuel should be 0%
    And the vehicle engine should be off
    And I confirm: the car won't drive
    When I manually: push or tow the car to a pump, or refuel where it stopped if in range, then refuel
    And I turn the engine on
    Then the vehicle engine should be running

  @kora_fuel @legacy:fuel-persist-leave @target:2
  Scenario: Fuel level stays after leaving the car
    """
    1. Note the exact gauge, turn the engine off and walk 20 m away for a minute.
    2. Get back in.
    3. Now drive another car 1 km+ away, come back to the first one and get in.
    Expect: both times the gauge shows the same level as before (no reset to 100 or a random value).
    """
    Given I am in the driver seat of a "sultan"
    When I manually: note the exact fuel gauge
    And I turn the engine off
    And I get out of the vehicle
    And I manually: walk 20 m away
    And I wait 60 seconds
    And I get in the vehicle
    Then I confirm: the gauge shows the same level as before
    When I manually: drive another car 1 km or more away, come back to the first car and get in
    Then I confirm: the gauge shows the same level as before, with no reset to 100 or a random value

  @kora_fuel @legacy:fuel-passenger-sync @target:2 @needs:players:2 @manual
  Scenario: Passenger sees the same fuel level
    """
    Needs 2 testers.
    1. Driver takes a car that isn't full, passenger gets in. Compare the HUD fuel numbers.
    2. Drive fast for 3 minutes, compare again.
    3. Refuel at a pump, both get back in and compare.
    Expect: driver and passenger see the same value every time (within 1). Report the numbers if they drift apart.
    """
    When I manually: as the driver take a car that isn't full while a second player gets in as passenger
    And I manually: compare the HUD fuel numbers with the second player
    Then I confirm: driver and passenger see the same value (within 1)
    When I manually: drive fast for 3 minutes and compare the HUD fuel numbers again
    Then I confirm: driver and passenger see the same value (within 1)
    When I manually: refuel at a pump, both get back in and compare the HUD fuel numbers
    Then I confirm: driver and passenger see the same value (within 1)

  @kora_fuel @legacy:fuel-refuel-other @target:2 @needs:players:2
  Scenario: Refuel someone else's car
    """
    Needs 2 testers.
    1. Tester A parks a car that's not full at a pump, engine off, and gets out.
    2. Tester B opens "Service nearby vehicle" and fills it.
    3. A gets back in and drives.
    Expect: B pays, gets "Vehicle refuelled for $X.", and A's gauge shows the new level and keeps it while driving (no jump back to the old level).
    """
    Given I am at "petrol_station"
    When I manually: as Tester A, park a car that's not full at a pump with the engine off and get out
    And I manually: ask a second player (Tester B) to open "Service nearby vehicle" and fill it
    Then I confirm: the other player pays and gets "Vehicle refuelled for $X."
    When I manually: as Tester A, get back in the car and drive
    Then I confirm: my gauge shows the new level and keeps it while driving, with no jump back to the old level

  @kora_fuel @legacy:fuel-engine-mid @target:1 @needs:players:2
  Scenario: Engine started during refuel
    """
    Needs 2 testers.
    1. A sits in the driver seat with the engine off at a pump. B starts a big refuel on that car.
    2. While B's bar runs, A starts the engine (G) or drives off.
    Expect: when B's bar ends B gets a red toast ("Switch the engine off before servicing." or "Move closer to the service point and vehicle."), B is not charged and the fuel doesn't go up.
    """
    Given I am at "petrol_station"
    When I manually: sit in the driver seat of a car at a pump with the engine off
    And I manually: ask a second player to start a big refuel on the car
    And I manually: while their bar runs, start the engine with G or drive off
    Then I confirm: when the bar ends the other player gets a red toast "Switch the engine off before servicing." or "Move closer to the service point and vehicle."
    And I confirm: the other player is not charged and the fuel doesn't go up

  @kora_fuel @legacy:fuel-restart @target:1 @needs:admin
  Scenario: Resource restart
    """
    Do this when few players are on. kora_hud depends on kora_fuel, so a restart can stop them; if anything stays broken, a full server restart fixes it.
    Needs a Mod (restart kora_fuel).
    1. Stand near a charger while the Mod restarts kora_fuel; sit in a half-full car.
    Expect: blips and the charger machine vanish and come back (the air pump shows while it's gone), the car keeps its fuel level, the HUD still shows Fuel/Charge correctly, pumps and chargers work after, and no errors appear in F8.
    """
    Given I am at "ev_charger"
    And I am in the driver seat of a "sultan"
    And the vehicle has 50% fuel
    When I manually: ask a Mod to restart kora_fuel while I stay near the charger sitting in the car
    Then I confirm: the blips and the charger machine vanish and come back, and the air pump shows while it's gone
    And the vehicle fuel should be 50%
    And I confirm: my HUD still shows Fuel/Charge correctly
    And I confirm: pumps and chargers work after the restart
    When the F8 console should show no errors

  @kora_fuel @legacy:fuel-resmon @target:1 @manual
  Scenario: Low resource usage (resmon)
    """
    1. Open F8 and type resmon 1.
    2. Watch kora_fuel on foot, then while driving, then standing by a charger.
    Expect: kora_fuel stays very low, around 0.00-0.02 ms. Report the number if it goes above 0.05 ms or keeps climbing.
    """
    When I manually: open F8 and type resmon 1
    And I manually: watch kora_fuel on foot, then while driving, then standing by a charger
    Then I confirm: kora_fuel stays very low, around 0.00-0.02 ms, and does not go above 0.05 ms or keep climbing
