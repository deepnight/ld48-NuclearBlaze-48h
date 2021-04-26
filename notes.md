# LD 48 dev notes

These are notes taken during Ludum Dare for future improvements & bug fixes.

 - CDB builder: filter out unused values (ie. value2, value3 etc)
 - CDB builder: use "desc" to add "value" completion doc
 - move macros to src/game/tools/macros
 - automate ALL arrays creation using build macro
 - Entity.hit "from" should be optional?
 - Macro to automate color conversion (eg. `"#ffcc00".int()`)
 - Add helper methods to Fx to create random variations on values (eg. `vary(v,0.1)`)
	- rnd rotation
 - Entity.sightCheck
 - missing isAlive() checks in isChargingAction/chargeAction
 - Add Screenshot mode
 - Move key controls from Boot to App?

# LDtk
 - aseprite hot reloading crash
 - API: add abstract for IntGrid values?