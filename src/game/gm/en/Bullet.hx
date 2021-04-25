package gm.en;

class Bullet extends Entity {
	public function new(xx:Float, yy:Float) {
		super(0,0);
		setPosPixel(xx,yy);
		gravityMul = 0;
		wid = hei = 4;
		frict = 1;
		collides = false;
	}

	function onHitCollision() {}


	override function onPreStepX() {
		super.onPreStepX();
		if( level.hasCollision(cx,cy) ) {
			onHitCollision();
			destroy();
		}
	}

	override function onPreStepY() {
		super.onPreStepY();
		if( !destroyed && level.hasCollision(cx,cy) ) {
			onHitCollision();
			destroy();
		}
	}
}