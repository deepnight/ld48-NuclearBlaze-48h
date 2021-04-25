package gm.en.bu;

class WaterDrop extends Bullet {
	var lastTailX = 0.;
	var lastTailY = 0.;
	var elapsedDist = 0.;

	public function new(xx:Float, yy:Float, ang:Float) {
		super(xx,yy);

		gravityMul = 0.8;
		frictX = 0.99;
		frictY = 0.93;
		collides = false;

		lastTailX = sprX;
		lastTailY = sprY;

		final spd = 0.7 * rnd(0.9,1.1);
		dx = Math.cos(ang)*spd;
		dy = Math.sin(ang)*spd;

		spr.set(dict.empty);
		spr.setCenterRatio(0.5,0.5);
		spr.colorize(0x35e7e0);
		spr.alpha = rnd(0.3,0.7);
	}

	function getElapsedFactor() {
		return elapsedDist/180;
	}

	override function postUpdate() {
		super.postUpdate();
		spr.rotation = Math.atan2(dy,dx);
		if( !cd.hasSetS("tail",0.03) ) {
			fx.waterTail(lastTailX, lastTailY, sprX, sprY, getElapsedFactor());
			lastTailX = sprX;
			lastTailY = sprY;
		}
	}

	override function onHitCollision() {
		super.onHitCollision();
		fx.waterTail(lastTailX, lastTailY, M.lerp(lastTailX,sprX,0.8), M.lerp(lastTailY,sprY,0.8), getElapsedFactor());
		fx.wallSplash(lastFixedUpdateX, lastFixedUpdateY);
	}

	override function fixedUpdate() {
		var lastX = centerX;
		var lastY = centerY;

		super.fixedUpdate();

		elapsedDist += M.dist(lastX, lastY, centerX, centerY);
		if( getElapsedFactor()>=1 ) {
			fx.waterTail(lastTailX, lastTailY, sprX, sprY, getElapsedFactor());
			fx.waterVanish(centerX, centerY);
			destroy();
			return;
		}


		// Reduce fire
		if( !cd.has("limit") ) {
			var x = cx;
			for(y in cy-1...cy+2) {
				var fs = level.getFireState(x,y);
				if( fs==null )
					continue;

				if( fs.isBurning() ) {
					var before = fs.level;
					fs.decrease( Const.db.WaterFireDecrease_1 );
					if( fs.level<=0 ) {
						// if( level.hasCollision(x,y+1) && x%3==0 )
						// 	fs.setToMin();
						// else
							fs.clear();
						if( before>0 )
							fx.fireVanish(x,y);
					}

					if( fs.level>=1 ) {
						fx.fireSplash(sprX, sprY);
						cd.setS("limit", Const.INFINITE);
						// fx.waterTail(lastTailX, lastTailY, sprX, sprY);
						// destroy();
					}
				}
				fs.underControlS = Const.db.ControlDuration_1;
				if( fs.quickFire )
					fs.underControlS*=0.25;
			}
		}
	}
}