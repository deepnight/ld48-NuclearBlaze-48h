package gm.en;

class Bullet extends Entity {
	public function new(xx:Float, yy:Float) {
		super(0,0);
		setPosPixel(xx,yy);
		gravityMul = 0;
		frict = 1;
		collides = false;
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		if( level.hasCollision(cx,cy) )
			destroy();
	}
}