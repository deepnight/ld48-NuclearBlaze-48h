package gm.en;

class Say extends Entity {
	var data : Entity_Say;
	public function new(d:Entity_Say) {
		super(0,0);
		data = d;
		setPosPixel(d.pixelX, d.pixelY);
		gravityMul = 0;
		collides = false;
		spr.set("empty");
	}

	override function dispose() {
		super.dispose();
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		if( distCase(hero)<=data.f_triggerDist ) {
			hero.say(data.f_text, data.f_color_int);
			destroy();
			game.addSlowMo("say",1, 0.8);
		}
	}
}