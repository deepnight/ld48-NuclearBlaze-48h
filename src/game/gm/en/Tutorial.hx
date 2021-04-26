package gm.en;

class Tutorial extends Entity {
	public static var ALL : Array<Tutorial> = [];

	var data : Entity_Tutorial;
	var tf : h2d.Text;
	var bg : h2d.ScaleGrid;

	public function new(d:Entity_Tutorial) {
		super(0,0);
		ALL.push(this);
		data = d;
		setPosPixel(d.pixelX, d.pixelY);
		gravityMul = 0;
		collides = false;
		spr.set("empty");
		wid = data.width;
		hei = data.height;

		tf = new h2d.Text(Assets.fontSmall);
		game.root.add(tf, Const.DP_MAIN);
		tf.text = data.f_text;
		tf.textColor = data.f_color_int;
		tf.maxWidth = data.width - data.f_padding*2;

		bg = new h2d.ScaleGrid( Assets.tiles.getTile(dict.tutorial),4,4, tf);
		bg.color.setColor( C.addAlphaF(data.f_color_int) );
		bg.alpha = 0.4;

		entityVisible = false;
		updatePos();
	}

	public function updatePos() {
		var p : Float = data.f_padding;

		tf.visible = entityVisible && !game.cd.has("screenshot");

		tf.setScale( M.imax(1,Std.int(Const.SCALE*0.5)) );
		tf.x = Std.int( sprX*Const.SCALE + game.scroller.x + p*Const.SCALE );
		tf.y = Std.int( sprY*Const.SCALE + game.scroller.y + p*Const.SCALE );
		tf.maxWidth = ( data.width - data.f_padding*2 ) * Const.SCALE / tf.scaleX;

		p*=0.5;
		bg.x = Std.int( -p );
		bg.y = Std.int( -p );
		bg.width = Std.int( tf.textWidth + p*2 );
		bg.height = Std.int( tf.textHeight + p*2 );
	}

	override function dispose() {
		super.dispose();
		ALL.remove(this);

		tf.remove();
		tf = null;
		bg = null;
	}

	override function postUpdate() {
		super.postUpdate();
		entityVisible = level.isFogRevealed( Std.int(centerX/Const.GRID), Std.int(centerY/Const.GRID) );
	}
}