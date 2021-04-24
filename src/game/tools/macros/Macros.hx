package tools.macros;

import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.Tools;

class Macros {

	// TODO not finished yet
	public static function addAllArray() {
		var pos = Context.currentPos();
		var rawMod = Context.getLocalModule();
		var pack = rawMod.split(".");
		var modName = pack.pop();
		var fields = Context.getBuildFields();

		// Add "ALL" static array
		var typePath = TPath({pack:pack, name:modName });
		var allField : Field = {
			name: "ALL",
			access: [ APublic, AStatic ],
			pos: pos,
			kind: FVar(macro:Array<$typePath>, macro []),
		}

		fields.push(allField);
		return fields;
	}
}
