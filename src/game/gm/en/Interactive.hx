package gm.en;

class Interactive extends Entity {
	public function new(x,y) {
		super(x,y);
	}

	public function canBeTriggered(by:Entity) {
		return isAlive() && by!=null && by.isAlive() && by.distCase(this)<=1 && sightCheck(by);
	}

	public function trigger() {}
}