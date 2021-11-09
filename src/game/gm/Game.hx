package gm;

import dn.Process;

class Game extends Process {
	public static var ME : Game;

	public var app(get,never) : App; inline function get_app() return App.ME;

	/** Game controller (pad or keyboard) **/
	public var ca : ControllerAccess<ControlActions>;

	/** Particles **/
	public var fx : Fx;

	/** Basic viewport control **/
	public var camera : Camera;

	/** Container of all visual game objects. Ths wrapper is moved around by Camera. **/
	public var scroller : h2d.Layers;

	/** Level data **/
	public var level : Level;

	/** UI **/
	public var hud : ui.Hud;

	/** Slow mo internal values**/
	var curGameSpeed = 1.0;
	var slowMos : Map<String, { id:String, t:Float, f:Float }> = new Map();


	public var hero : Hero;
	// public var masks : Array<HSprite> = [];

	public var curLevelIdx = 0;


	public function new() {
		super(App.ME);

		ME = this;
		ca = App.ME.controller.createAccess();
		// ca.setLeftDeadZone(0.2);
		// ca.setRightDeadZone(0.2);
		createRootInLayers(App.ME.root, Const.DP_BG);

		scroller = new h2d.Layers();
		root.add(scroller, Const.DP_BG);
		scroller.filter = new h2d.filter.Nothing(); // force rendering for pixel perfect

		fx = new Fx();
		hud = new ui.Hud();
		camera = new Camera();

		// for(i in 0...2) {
		// 	var mask = Assets.tiles.h_get(Assets.tilesDict.mask,0, 0.5,0.5);
		// 	root.add(mask, Const.DP_TOP);
		// 	masks.push(mask);
		// 	mask.colorize(0x0);
		// }

		#if debug
		// curLevelIdx = Assets.worldData.all_levels.Lab.arrayIndex;
		#end
		startCurrentLevel();


		#if debug
		Console.ME.enableStats();
		var tf : h2d.Text = null;
		Console.ME.stats.addComponent( (f)->{
			if( tf==null )
				tf = new h2d.Text(Assets.fontSmall, f);
			tf.text = Std.string( @:privateAccess fx.pool.count() + " fx" );
		});
		#end
	}

	public function startCurrentLevel() {
		startLevel(Assets.worldData.levels[curLevelIdx]);
	}

	public function nextLevel() {
		level.destroy();
		curLevelIdx++;
		startCurrentLevel();
	}


	public static inline function exists() {
		return ME!=null && !ME.destroyed;
	}


	/** Load a level **/
	function startLevel(l:World.World_Level) {
		if( level!=null )
			level.destroy();
		fx.clear();
		for(e in Entity.ALL) // <---- Replace this with more adapted entity destruction (eg. keep the player alive)
			e.destroy();
		garbageCollectEntities();
		delayer.cancelById("deathMsg");
		hud.clearNotifications();

		cd.unset("successMsg");

		level = new Level(l);
		hero = new gm.en.Hero();

		for(d in level.data.l_Entities.all_Door)
			new gm.en.int.Door(d);

		for(d in level.data.l_Entities.all_Item)
			new gm.en.Item(d);

		for(d in level.data.l_Entities.all_Say)
			new gm.en.Say(d);

		for(d in level.data.l_Entities.all_Tutorial)
			new gm.en.Tutorial(d);

		for(d in level.data.l_Entities.all_Exit)
			new gm.en.Exit(d);

		for(d in level.data.l_Entities.all_Title)
			new gm.en.Title(d);

		for(d in level.data.l_Entities.all_WallText)
			new gm.en.WallText(d);

		for(d in level.data.l_Entities.all_Smoker)
			dn.Bresenham.iterateDisc(d.cx, d.cy, d.f_radius, (x,y)->{
				if( level.hasFireState(x,y) )
					level.getFireState(x,y).extinguished = true;
			});


		for(e in level.data.l_Entities.all_FireStarter)
			dn.Bresenham.iterateDisc(
				e.cx, e.cy, e.f_range,
				(x,y)->level.ignite(x,y, e.f_startFireLevel)
			);

		camera.centerOnTarget();
		hud.onLevelStart();
		Process.resizeAll();
	}



	/** Called when either CastleDB or `const.json` changes on disk **/
	@:allow(assets.Assets)
	function onDbReload() {
		hud.notify("DB reloaded");
	}


	/** Called when LDtk file changes on disk **/
	@:allow(assets.Assets)
	function onLdtkReload() {
		hud.notify("LDtk reloaded");
		if( level!=null )
			startLevel( Assets.worldData.getLevel(level.data.uid) );
	}

	/** Window/app resize event **/
	override function onResize() {
		super.onResize();
	}


	/** Garbage collect any Entity marked for destruction. This is normally done at the end of the frame, but you can call it manually if you want to make sure marked entities are disposed right away, and removed from lists. **/
	public function garbageCollectEntities() {
		if( Entity.GC==null || Entity.GC.length==0 )
			return;

		for(e in Entity.GC)
			e.dispose();
		Entity.GC = [];
	}

	/** Called if game is destroyed, but only at the end of the frame **/
	override function onDispose() {
		super.onDispose();

		fx.destroy();
		for(e in Entity.ALL)
			e.destroy();
		garbageCollectEntities();
	}


	/**
		Start a cumulative slow-motion effect that will affect `tmod` value in this Process
		and all its children.

		@param sec Realtime second duration of this slowmo
		@param speedFactor Cumulative multiplier to the Process `tmod`
	**/
	public function addSlowMo(id:String, sec:Float, speedFactor=0.3) {
		if( slowMos.exists(id) ) {
			var s = slowMos.get(id);
			s.f = speedFactor;
			s.t = M.fmax(s.t, sec);
		}
		else
			slowMos.set(id, { id:id, t:sec, f:speedFactor });
	}


	/** The loop that updates slow-mos **/
	final function updateSlowMos() {
		// Timeout active slow-mos
		for(s in slowMos) {
			s.t -= utmod * 1/Const.FPS;
			if( s.t<=0 )
				slowMos.remove(s.id);
		}

		// Update game speed
		var targetGameSpeed = 1.0;
		for(s in slowMos)
			targetGameSpeed*=s.f;
		curGameSpeed += (targetGameSpeed-curGameSpeed) * (targetGameSpeed>curGameSpeed ? 0.2 : 0.6);

		if( M.fabs(curGameSpeed-targetGameSpeed)<=0.001 )
			curGameSpeed = targetGameSpeed;
	}


	/**
		Pause briefly the game for 1 frame: very useful for impactful moments,
		like when hitting an opponent in Street Fighter ;)
	**/
	public inline function stopFrame() {
		ucd.setS("stopFrame", 0.2);
	}


	/** Loop that happens at the beginning of the frame **/
	override function preUpdate() {
		super.preUpdate();

		for(e in Entity.ALL) if( !e.destroyed ) e.preUpdate();
	}

	/** Loop that happens at the end of the frame **/
	override function postUpdate() {
		super.postUpdate();

		// Update slow-motions
		updateSlowMos();
		baseTimeMul = ( 0.2 + 0.8*curGameSpeed ) * ( ucd.has("stopFrame") ? 0.3 : 1 );
		Assets.tiles.tmod = tmod;

		// Entities post-updates
		for(e in Entity.ALL) if( !e.destroyed ) e.postUpdate();

		// Entities final updates
		for(e in Entity.ALL) if( !e.destroyed ) e.finalUpdate();

		// Dispose entities marked as "destroyed"
		garbageCollectEntities();

		// Masks
		// var i = 0;
		// for(mask in masks) {
		// 	mask.x = w()*0.5;
		// 	mask.y = h()*0.5;
		// 	mask.scaleX = w()/mask.tile.width;
		// 	mask.scaleY = h()/mask.tile.height;
		// 	mask.alpha = 0.8;
		// 	switch i {
		// 		case 0:

		// 		case 1:
		// 			mask.scaleX*=-1.1;
		// 			mask.scaleY*=-1.1;
		// 	}
		// 	i++;
		// }
	}


	/** Main loop but limited to 30 fps (so it might not be called during some frames) **/
	override function fixedUpdate() {
		super.fixedUpdate();

		// Entities "30 fps" loop
		for(e in Entity.ALL) if( !e.destroyed ) e.fixedUpdate();
	}

	public function levelComplete() {
		return level.fireCount==0 && successTimerS>=1 || level.data.f_ignoreFires;
	}


	public function setScreenshotMode(active:Bool) {
		if( active ) {
			scroller.add(hero.spr, Const.DP_FX_FRONT);
			cd.setS("screenshot", Const.INFINITE);
			hud.clearNotifications();
			for(e in Entity.ALL) {
				e.disableDebugBounds();
				e.debug();
			}
			for(e in gm.en.Tutorial.ALL)
				e.dispose();
			Console.ME.disableStats();
			hero.clearBlink();
			hero.postUpdate();
		}
		else {
			cd.unset("screenshot");
			scroller.add(hero.spr, Const.DP_MAIN);
		}
	}

	override function resume() {
		super.resume();
		cd.setS("exitLock",0.1);
		cd.unset("exitWarn");
	}

	/** Main loop **/
	var successTimerS = 0.;
	override function update() {
		super.update();

		// Entities main loop
		for(e in Entity.ALL) if( !e.destroyed ) e.update();

		// Victory
		if( level.fireCount==0 ) {
			successTimerS+=1/Const.FPS * tmod;
			if( successTimerS>=0.3 && !cd.hasSetS("successMsg",Const.INFINITE) && !level.data.f_disableCompleteAnnounce )
				hero.say(L.t._("Clear! Proceeding deeper..."), 0xccff00);
			// if( successTimerS>=3 )
			// 	nextLevel();
		}
		else
			successTimerS = 0;


		// Global key shortcuts
		if( !App.ME.anyInputHasFocus() && !ui.Modal.hasAny() && !ca.lockCondition() ) {

			// Exit by pressing ESC twice
			#if hl
			if( ca.isPressed(Exit) && !cd.has("exitLock") )
				if( !cd.hasSetS("exitWarn",3) )
					hud.notify(Lang.t._("Press again to EXIT the game."), 0xff0000);
				else
					App.ME.exit();
			#end

			// Attach debug drone (CTRL-SHIFT-D)
			#if debug
			if( ca.isKeyboardPressed(K.D) && ca.isKeyboardDown(K.CTRL) && ca.isKeyboardDown(K.SHIFT) )
				new DebugDrone(); // <-- HERE: provide an Entity as argument to attach Drone near it

			// Next level
			if( ca.isKeyboardPressed(K.N) )
				nextLevel();

			// Fog
			if( ca.isKeyboardPressed(K.F) )
				level.fogRender.visible = !level.fogRender.visible;
			#end

			// Restart
			if( ca.isPressed(Restart) ) {
				if( !cd.hasSetS("restartWarn",3) )
					hud.notify(Lang.t._("Press again to restart."));
				else
					startCurrentLevel();
			}
		}
	}
}

