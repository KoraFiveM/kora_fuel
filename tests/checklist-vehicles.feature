# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_fuel — Vehicles

  @kora_fuel @checklist @checklist:kora_fuel:service-menu @cat:vehicles
  Scenario: Amount and payment menu
    """
    Checklist test: In the service panel pick amount to add and Pay with cash or bank; price per unit and total are shown, then Confirm.
    """
    Given I am at "petrol_station"
    And my cash balance is at least 500
    And a "test_car" is spawned in front of me
    When I manually: hold Alt, target the pump and choose 'Service nearby vehicle'
    Then the "kora_fuel:pump" app should be open
    When I manually: pick an amount to add and choose to pay with cash or bank
    Then I confirm: the price per unit and the total are shown
    When I manually: press Confirm

  @kora_fuel @checklist @checklist:kora_fuel:price-rounding @cat:vehicles
  Scenario: Whole-dollar price rounding
    """
    Checklist test: Buy a small fuel amount: the menu shows total rounded up to whole dollars and the exact amount it was rounded from.
    """
    Given I am at "petrol_station"
    And my cash balance is at least 500
    And a "test_car" is spawned in front of me
    When I manually: open the pump service panel and pick a small fuel amount
    Then the "kora_fuel:pump" app should be open
    And I confirm: the menu shows the total rounded up to whole dollars
    And I confirm: the menu shows the exact amount it was rounded from

  @kora_fuel @checklist @checklist:kora_fuel:service-radius @cat:vehicles
  Scenario: Server distance and rate limit
    """
    Checklist test: Spam purchase requests or try from far from a station: server rate-limits (5 per 10s) and refuses outside the station area.
    """
    Given my cash balance is at least 500
    And a "test_car" is spawned in front of me
    When I go to "petrol_station"
    And I manually: spam purchase requests at the pump quickly (more than 5 within 10 seconds)
    Then I confirm: purchases are rate-limited to 5 per 10 seconds
    When I manually: go far from any station and try to send a purchase request
    Then I confirm: the purchase is refused outside the station area

  @kora_fuel @checklist @checklist:kora_fuel:hud-ev-charge @cat:vehicles
  Scenario: HUD shows Charge for EVs
    """
    Checklist test: Sit in an electric vehicle: HUD shows Charge instead of Fuel (via isElectricVehicle export).
    """
    Given I am in the driver seat of a "voltic"
    When the HUD should show "Charge"
    Then I confirm: my HUD shows Charge instead of Fuel

  @kora_fuel @checklist @checklist:kora_fuel:fuel-exports @cat:vehicles @needs:admin
  Scenario: GetFuel/SetFuel exports
    """
    Checklist test: Call exports.kora_fuel:GetFuel/SetFuel (or LegacyFuel/qb-fuel/ps-fuel/cdn-fuel aliases) on a vehicle and see the level change.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: as an admin, use /runcode to run a Lua line that prints exports.kora_fuel:GetFuel(GetVehiclePedIsIn(PlayerPedId(), false))
    And I manually: as an admin, use /runcode to run exports.kora_fuel:SetFuel(GetVehiclePedIsIn(PlayerPedId(), false), 50.0)
    And I manually: repeat the GetFuel and SetFuel calls through the LegacyFuel, qb-fuel, ps-fuel and cdn-fuel exports
    Then I confirm: the fuel level read back by GetFuel changes to the value set with SetFuel for every export alias
    When the F8 console should show no errors

  @kora_fuel @checklist @checklist:kora_fuel:fuel-persist @cat:vehicles
  Scenario: Fuel persists via garages
    """
    Checklist test: Store a vehicle with partial fuel in a garage and take it out: the same fuel level is restored.
    """
    Given I am in the driver seat of a "test_car"
    And the vehicle has 50% fuel
    When I manually: store the vehicle in a garage
    And I manually: take the vehicle out of the garage again
    And I get in the vehicle
    Then the vehicle fuel should be 50%
