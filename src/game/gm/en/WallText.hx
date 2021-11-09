package gm.en;

class WallText extends Entity {
	public function new(data:Entity_WallText) {
		super(0,0);
		setPosPixel(data.pixelX, data.pixelY);
		gravityMul = 0;
		collides = false;
		spr.set("empty");

		var tf = new h2d.Text(Assets.fontPixel, spr);
		tf.text = data.f_lines;
		tf.maxWidth = data.width;
		tf.textColor = data.f_color_int;
	}

	override function dispose() {
		super.dispose();
	}

	override function postUpdate() {
		super.postUpdate();
	}
}