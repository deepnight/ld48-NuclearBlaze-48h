package gm.en.int;

class Door extends Interactive {
	public static var ALL : Array<Door> = [];
	public var closed(default,null) = true;
	var cHei = 0;

	public var kicks = 0;
	public var requiredItem : Null<Enum_Items>;
	public var data : Entity_Door;

	public function new(d:Entity_Door) {
		super(d.cx,d.cy);
		data = d;
		ALL.push(this);
		Game.ME.scroller.add(spr, Const.DP_BG);
		requiredItem = d.f_requiredItem;

		kicks = d.f_requireLevelComplete ? 0 : d.f_kicks;
		cHei = M.round(d.height / Const.GRID);
		hei = cHei*Const.GRID;
		closed = !d.f_opened;
		updateCollisions();
		for(y in cy-cHei+1...cy+1)
			level.setMark(DoorZone, cx,y);
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
			if( data.f_requireLevelComplete )
				spr.set( closed ? dict.exitClosed : dict.exitOpened);
			else
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
		level.clearFogUpdateDelay();
		updateCollisions();

		if( requiredItem!=null ) {
			hero.sayBubble( new h2d.Bitmap(Assets.getItem(requiredItem)), Assets.tilesDict.emoteOk);
			hero.useItem(requiredItem);
		}


		// Check if there are fires behind
		var bigFires = 0;
		dn.Bresenham.iterateDisc(cx,cy,4, (x,y)->{
			if( openDir==1 && x<=cx || openDir==-1 && x>=cx )
				return;
			if( level.getFireLevel(x,y)==2 && sightCheck(x,y) )
				bigFires++;
		});

		// Explodes!
		if( bigFires>=2 ) {
			game.addSlowMo("doorExplosion", 1, 0.2);
			game.stopFrame();
			fx.doorExplosion(centerX, centerY, -openDir);
			hero.bump(dirTo(hero)*0.2, -0.1);
			dn.Bresenham.iterateDisc(cx,cy,6, (x,y)->{
				if( level.hasFireState(x,y) && !level.isBurning(x,y) && sightCheck(x,y) ) {
					var fs = level.getFireState(x,y);
					fs.underControlS = 0;
					level.ignite(x,y, 1, 0.7);
				}
			});
			return true;
		}
		else
			return false;
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