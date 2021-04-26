package gm.en;

class Title extends Entity {
	public function new(data:Entity_Title) {
		super(0,0);
		setPosPixel(data.pixelX, data.pixelY);
		gravityMul = 0;
		collides = false;
		spr.set("empty");

		var tf = new h2d.Text(data.f_small ? Assets.fontPixel : Assets.fontMedium, spr);
		tf.text = data.f_title;
		tf.textColor = data.f_color_int;
		tf.x = Std.int(-tf.textWidth*0.5);
		tf.y = Std.int(-tf.textHeight*0.5);
	}

	override function dispose() {
		super.dispose();
	}

	override function postUpdate() {
		super.postUpdate();
	}
}