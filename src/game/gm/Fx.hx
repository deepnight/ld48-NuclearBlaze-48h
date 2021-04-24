package gm;

import h2d.Sprite;
import dn.heaps.HParticle;


class Fx extends dn.Process {
	var game(get,never) : Game; inline function get_game() return Game.ME;
	var level(get,never) : Level; inline function get_level() return Game.ME.level;

	final dict = Assets.tilesDict;

	var pool : ParticlePool;
	var windX = 0.;

	public var bgAddSb    : h2d.SpriteBatch;
	public var bgNormalSb    : h2d.SpriteBatch;
	public var topAddSb       : h2d.SpriteBatch;
	public var topNormalSb    : h2d.SpriteBatch;

	public function new() {
		super(Game.ME);

		pool = new ParticlePool(Assets.tiles.tile, 2048, Const.FPS);

		bgAddSb = new h2d.SpriteBatch(Assets.tiles.tile);
		game.scroller.add(bgAddSb, Const.DP_FX_BG);
		bgAddSb.blendMode = Add;
		bgAddSb.hasRotationScale = true;

		bgNormalSb = new h2d.SpriteBatch(Assets.tiles.tile);
		game.scroller.add(bgNormalSb, Const.DP_FX_BG);
		bgNormalSb.hasRotationScale = true;

		topNormalSb = new h2d.SpriteBatch(Assets.tiles.tile);
		game.scroller.add(topNormalSb, Const.DP_FX_FRONT);
		topNormalSb.hasRotationScale = true;

		topAddSb = new h2d.SpriteBatch(Assets.tiles.tile);
		game.scroller.add(topAddSb, Const.DP_FX_FRONT);
		topAddSb.blendMode = Add;
		topAddSb.hasRotationScale = true;
	}

	override public function onDispose() {
		super.onDispose();

		pool.dispose();
		bgAddSb.remove();
		bgNormalSb.remove();
		topAddSb.remove();
		topNormalSb.remove();
	}

	/** Clear all particles **/
	public function clear() {
		pool.killAll();
	}

	/** Create a HParticle instance in the TOP layer, using Additive blendmode **/
	public inline function allocTopAdd(t:h2d.Tile, x:Float, y:Float) : HParticle {
		return pool.alloc(topAddSb, t, x, y);
	}

	/** Create a HParticle instance in the TOP layer, using default blendmode **/
	public inline function allocTopNormal(t:h2d.Tile, x:Float, y:Float) : HParticle {
		return pool.alloc(topNormalSb, t,x,y);
	}

	/** Create a HParticle instance in the BG layer, using Additive blendmode **/
	public inline function allocBgAdd(t:h2d.Tile, x:Float, y:Float) : HParticle {
		return pool.alloc(bgAddSb, t,x,y);
	}

	/** Create a HParticle instance in the BG layer, using default blendmode **/
	public inline function allocBgNormal(t:h2d.Tile, x:Float, y:Float) : HParticle {
		return pool.alloc(bgNormalSb, t,x,y);
	}

	/** Gets a random tile variation from the atlas **/
	public inline function getTile(id:String) : h2d.Tile {
		return Assets.tiles.getTileRandom(id);
	}

	public function markerEntity(e:Entity, ?c=0xFF00FF, ?short=false) {
		#if debug
		if( e==null )
			return;

		markerCase(e.cx, e.cy, short?0.03:3, c);
		#end
	}

	public function markerCase(cx:Int, cy:Int, ?sec=3.0, ?c=0xFF00FF) {
		#if debug
		var p = allocTopAdd(getTile(dict.fxCircle15), (cx+0.5)*Const.GRID, (cy+0.5)*Const.GRID);
		p.setFadeS(1, 0, 0.06);
		p.colorize(c);
		p.lifeS = sec;

		var p = allocTopAdd(getTile(dict.pixel), (cx+0.5)*Const.GRID, (cy+0.5)*Const.GRID);
		p.setFadeS(1, 0, 0.06);
		p.colorize(c);
		p.setScale(2);
		p.lifeS = sec;
		#end
	}

	public function markerFree(x:Float, y:Float, ?sec=3.0, ?c=0xFF00FF) {
		#if debug
		var p = allocTopAdd(getTile(dict.fxDot), x,y);
		p.setCenterRatio(0.5,0.5);
		p.setFadeS(1, 0, 0.06);
		p.colorize(c);
		p.setScale(3);
		p.lifeS = sec;
		#end
	}

	public function markerText(cx:Int, cy:Int, txt:String, ?t=1.0) {
		#if debug
		var tf = new h2d.Text(Assets.fontTiny, topNormalSb);
		tf.text = txt;

		var p = allocTopAdd(getTile(dict.fxCircle15), (cx+0.5)*Const.GRID, (cy+0.5)*Const.GRID);
		p.colorize(0x0080FF);
		p.alpha = 0.6;
		p.lifeS = 0.3;
		p.fadeOutSpeed = 0.4;
		p.onKill = tf.remove;

		tf.setPosition(p.x-tf.textWidth*0.5, p.y-tf.textHeight*0.5);
		#end
	}

	inline function collides(p:HParticle, offX=0., offY=0.) {
		return level.hasCollision( Std.int((p.x+offX)/Const.GRID), Std.int((p.y+offY)/Const.GRID) );
	}

	public function flashBangS(c:UInt, a:Float, ?t=0.1) {
		var e = new h2d.Bitmap(h2d.Tile.fromColor(c,1,1,a));
		game.root.add(e, Const.DP_FX_FRONT);
		e.scaleX = game.w();
		e.scaleY = game.h();
		e.blendMode = Add;
		game.tw.createS(e.alpha, 0, t).end( function() {
			e.remove();
		});
	}


	/**
		A small sample to demonstrate how basic particles work. This example produces a small explosion of yellow dots that will fall and slowly fade to purple.

		USAGE: fx.dotsExplosionExample(50,50, 0xffcc00)
	**/
	public function dotsExplosionExample(x:Float, y:Float, color:UInt) {
		for(i in 0...80) {
			var p = allocTopAdd( getTile(dict.fxDot), x+rnd(0,3,true), y+rnd(0,3,true) );
			p.alpha = rnd(0.4,1);
			p.colorAnimS(color, 0x762087, rnd(0.6, 3)); // fade particle color from given color to some purple
			p.moveAwayFrom(x,y, rnd(1,3)); // move away from source
			p.frict = rnd(0.8, 0.9); // friction applied to velocities
			p.gy = rnd(0, 0.02); // gravity Y (added on each frame)
			p.lifeS = rnd(2,3); // life time in seconds
		}
	}


	inline function compressUp(ratio:Float, range:Float) return (1-range) + range*ratio;

	public inline function levelFireSmoke(cx:Int,cy:Int, fs:FireState) {
		var pow = fs.getPowerRatio(true);

		var p = allocTopNormal( getTile(dict.fxSmoke), getFlameX(cx,cy), getFlameY(cx,cy) );
		p.setFadeS(rnd(0.4, 0.6)*compressUp(pow,0.7), rnd(0.3,0.5), rnd(0.4,1));
		p.colorAnimS(0xc14132, 0x57546f, rnd(0.4, 1.2));
		p.setScale(rnd(1,2,true));
		p.rotation = rnd(0,M.PI2);
		p.dr = rnd(0,0.03,true);
		p.ds = rnd(0.002, 0.004);
		p.gx = windX*rnd(0.01,0.02);
		p.dy = -rnd(0.3, 0.8) * compressUp(pow,0.8);
		p.frict = rnd(0.99,1);
		p.lifeS = rnd(0.3,0.6);
		p.delayS = rnd(0,0.4);
	}

	public inline function levelFireSparks(cx:Int, cy:Int, fs:FireState) {
		var pow = fs.getPowerRatio(true);

		if( level.hasCollision(cx,cy+1) )
		for(i in 0...M.round(1+pow)) {
			var p = allocTopAdd( getTile(dict.pixel), getFlameX(cx,cy), getFlameY(cx,cy) );
			p.colorAnimS(0xff8800, 0xff0044, rnd(0.3,1));
			p.setFadeS(rnd(0.7,1), 0.1, 0.3);
			p.alphaFlicker = 0.6;
			p.dx = rnd(-0.8,0.4) * compressUp(pow,0.5);
			p.dy = -rnd(0.6, 5) * compressUp(pow,0.5);
			p.gx = rnd(0,0.05,true);
			p.frict = rnd(0.8, 0.96);
			p.lifeS = rnd(0.2,0.3);
			p.delayS = rnd(0, 0.5);
		}
	}

	inline function getFlameX(cx:Int,cy:Int) {
		return Const.GRID * (
			level.hasCollision(cx-1,cy) ? rnd(cx-0.2,cx+0.1) :
			level.hasCollision(cx+1,cy) ? rnd(cx+0.9,cx+1.2) :
			rnd(cx-0.1,cx+1.1)
		);
	}
	inline function getFlameY(cx:Int,cy:Int) {
		return Const.GRID * (
			level.hasCollision(cx,cy-1) ? rnd(cy,cy+0.3) :
			level.hasCollision(cx,cy+1) ? rnd(cy+1,cy+1.4) :
			rnd(cy-0.2,cy+1.2)
		);
	}

	public inline function levelFlames(cx:Int,cy:Int, fs:FireState) {
		var pow = fs.getPowerRatio(true);

		for( i in 0...Std.int(1+pow*3) ) {
			var p = allocTopAdd( getTile(dict.fxFlame), getFlameX(cx,cy), getFlameY(cx,cy) );
			p.setFadeS(rnd(0.7,0.8), rnd(0.2,0.4), 0.3);
			p.colorAnimS( C.interpolateInt(0xff0000, 0xffcc00, rnd(0,1)), 0xb71919, rnd(0.2,0.4) );
			p.setScale(rnd(0.9,2) * compressUp(pow,0.7));
			p.scaleX *= rnd(0.7,1.2,true);
			p.rotation = -rnd(0.1,0.2);
			p.scaleMul = rnd(0.94,0.96);
			p.dsY = rnd(0.01,0.02);
			p.dsFrict = 0.92;
			p.dx = rnd(0,0.2,true) + windX*0.2;
			p.dy = i==0
				? -rnd(0.4, 0.6) * compressUp(pow,0.7)
				: -rnd(0.2, 1.4) * compressUp(pow,0.5);
			p.frict = rnd(0.94, 0.98);
			p.lifeS = rnd(0.3,0.5);
			p.delayS = rnd(0,0.4);
		}

	}


	public function flame(x:Float,y:Float) {
		for(i in 0...4) {
			var p = allocTopAdd( getTile(dict.fxFlame), x+rnd(0,3,true), y+rnd(0,7,true) );
			p.setFadeS(rnd(0.3,0.5), 0.1, 0.2);
			p.colorAnimS( C.interpolateInt(0xff5500, 0xffcc00, rnd(0,1)), 0x9e62f1, rnd(0.2,0.4) );
			p.setScale(rnd(0.4,0.8));
			p.scaleX*=rndSign();
			p.rotation = -rnd(0.1,0.2);
			p.dx = -rnd(0.1,0.3);
			p.scaleMul = rnd(0.98,0.99);
			p.dy = -rnd(0.4, 1.3);
			p.frict = rnd(0.94, 0.96);
			p.lifeS = rnd(0.2,0.3);
			p.delayS = i==0 ? 0 : rnd(0,0.1);
		}

	}


	override function update() {
		super.update();

		windX = Math.cos(ftime*0.01);
		pool.update(game.tmod);
	}
}