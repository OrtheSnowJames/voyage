-- the variables that live in the persistent state (see serialize.load_persistent); they outlive saves and wipes.
-- To add a new one, put it here with its starting value. Values must be numbers, strings, booleans or tables of those.
return {
    times_beaten = 0,
    save_slot = 1,
}
