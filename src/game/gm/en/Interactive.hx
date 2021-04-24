package gm.en;

class Interactive extends Entity {
	public static var ALL : Array<Interactive> = [];

	public var interactDist = 2;

	public function new(x,y) {
		super(x,y);
		ALL.push(this);
	}

	override function dispose() {
		super.dispose();
		ALL.remove(this);
	}

	public function canBeTriggered(by:Entity) {
		return isAlive() && by!=null && by.isAlive() && by.distCase(this)<=interactDist && sightCheck(by);
	}

	public static function anyAvailable(by:Entity) : Bool {
		for(e in ALL )
			if( e.canBeTriggered(by) )
				return true;
		return false;
	}
	public static function getCurrent(by:Entity) : Null<Interactive> {
		if( !anyAvailable(by) )
			return null;

		var dh = new dn.DecisionHelper( ALL.filter( e->e.canBeTriggered(by) ) );
		dh.score( (e)->-e.distCase(by) );
		return dh.getBest();
	}

	public function tryToTrigger() {
		onTrigger();
	}

	function onTrigger() {}

	override function fixedUpdate() {
		super.fixedUpdate();

		// if( canBeTriggered(hero) && !hero.controlsLocked() )
		// 	fx.markerEntity(this,true);
	}
}