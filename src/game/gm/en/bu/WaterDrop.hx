package gm.en.bu;

class WaterDrop extends Bullet {
	public function new(xx:Float, yy:Float, ang:Float) {
		super(xx,yy);

		gravityMul = 0.8;
		frictX = 0.99;
		frictY = 0.93;
		collides = false;

		final spd = 0.7 * rnd(0.9,1.1);
		dx = Math.cos(ang)*spd;
		dy = Math.sin(ang)*spd;
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		// Reduce fire
		var x = cx;
		for(y in cy-1...cy+2) {
			var fs = level.getFireState(x,y);
			if( fs==null )
				continue;

			if( fs.isBurning() ) {
				var before = fs.level;
				fs.decrease( Const.db.WaterFireDecrease_1 );
				if( fs.level<=0 ) {
					if( level.hasCollision(x,y+1) && x%3==0 )
						fs.setToMin();
					else
						fs.clear();
					if( before>0 )
						fx.fireVanish(x,y);
				}
			}
			fs.underControlS = Const.db.ControlDuration_1;
			if( fs.level>=1 )
				destroy();
		}
	}
}