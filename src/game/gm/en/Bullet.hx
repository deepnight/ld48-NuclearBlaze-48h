package gm.en;

class Bullet extends Entity {
	public function new(xx:Float, yy:Float) {
		super(0,0);
		setPosPixel(xx,yy);
		// gravityMul = 0.6;
		frictX = 0.99;
		frictY = 0.93;
		collides = false;
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		var x = cx;
		for(y in cy...cy+2)
			if( level.isBurning(x,y) ) {
				var fs = level.getFireState(x,y);
				fs.decrease( Const.db.WaterFireDecrease_1 );
				if( fs.level==0 )
					fs.setToMin();
				fs.underControlS = Const.db.ControlDuration_1;
				if( fs.level>1 )
					destroy();
			}

		if( level.hasCollision(cx,cy) )
			destroy();
	}
}