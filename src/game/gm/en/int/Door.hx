package gm.en.int;

class Door extends Interactive {
	public static var ALL : Array<Door> = [];
	public var closed(default,null) = true;
	var cHei = 0;

	public function new(d:Entity_Door) {
		super(d.cx,d.cy);
		ALL.push(this);
		cHei = M.round(d.height / Const.GRID);
		closed = !d.f_opened;
		updateCollisions();
	}

	public static function getAt(cx,cy) {
		for(e in ALL)
			if( e.isAlive() && cx==e.cx && cy>e.cy-e.cHei && cy<=e.cy )
				return e;
		return null;
	}

	override function dispose() {
		super.dispose();
		ALL.remove(this);
		updateCollisions();
	}

	function updateCollisions() {
		if( isAlive() ) {
			spr.set( closed ? dict.doorClosed : dict.doorOpened );
			spr.setCenterRatio(closed ? 0.5 : 0, 1);
		}

		if( level==null || level.destroyed )
			return;

		var set = isAlive() && closed;
		for(i in 0...cHei)
			level.setCollisionOverride(cx, cy-i, set);
	}

	public function open(openDir=1) {
		closed = false;
		dir = openDir;
		updateCollisions();
	}

	public function close() {
		closed = true;
		updateCollisions();

		for(e in Entity.ALL) {
			if( e==this || !e.isAlive() )
				continue;

			if( e.cx==cx && e.cy>cy-cHei && e.cy<=cy ) {
				if( e.xr<0.5 ) {
					e.cx--;
					e.xr = 0.9;
				}
				else {
					e.cx++;
					e.xr = 0.1;
				}
				e.onPosManuallyChanged();
			}
		}
	}

	override function onTrigger() {
		super.onTrigger();
		if( closed )
			open();
		else
			close();
	}
}