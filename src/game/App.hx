/**
	"App" class takes care of all the top-level stuff in the whole application. Any other Process, including Game instance, should be a child of App.
**/

class App extends dn.Process {
	public static var ME : App;

	/** 2D scene **/
	public var scene(default,null) : h2d.Scene;

	/** Used to create "ControllerAccess" instances that will grant controller usage (keyboard or gamepad) **/
	public var controller : Controller<ControlActions>;

	/** Controller Access created for Main & Boot **/
	public var ca : ControllerAccess<ControlActions>;

	public function new(s:h2d.Scene) {
		super();
		ME = this;
		scene = s;
        createRoot(scene);

		initEngine();
		initAssets();
		initController();

		// Create console (open with [²] key)
		new ui.Console(Assets.fontTiny, scene); // init debug console

		// Optional screen that shows a "Click to start/continue" message when the game client looses focus
		#if js
		new dn.heaps.GameFocusHelper(scene, Assets.fontLarge, hxd.Res.thumb.toTile());
		#end

		startGame();
	}



	/** Start game process **/
	public function startGame() {
		if( Console.ME.stats!=null )
			Console.ME.stats.removeAllComponents();

		if( Game.exists() ) {
			// Kill previous game instance first
			Game.ME.destroy();
			dn.Process.updateAll(1); // ensure all garbage collection is done
			_createGameInstance();
			hxd.Timer.skip();
		}
		else {
			// Fresh start
			delayer.addF( ()->{
				_createGameInstance();
				hxd.Timer.skip();
			}, 1 );
		}
	}

	final function _createGameInstance() {
		new Game();
	}


	public function anyInputHasFocus() {
		return Console.ME.isActive();
	}


	/**
		Initialize low level stuff, before anything else
	**/
	function initEngine() {
		// Engine settings
		engine.backgroundColor = 0xff<<24 | 0x111133;
		#if hl
        engine.fullScreen = true;
        #end

		// Heaps resource management
		#if( hl && debug )
			hxd.Res.initLocal();
			hxd.res.Resource.LIVE_UPDATE = true;
        #else
      		hxd.Res.initEmbed();
        #end

		// Sound manager (force manager init on startup to avoid a freeze on first sound playback)
		hxd.snd.Manager.get();
		hxd.Timer.skip(); // needed to ignore heavy Sound manager init frame

		// Framerate
		hxd.Timer.smoothFactor = 0.4;
		hxd.Timer.wantedFPS = Const.FPS;
		dn.Process.FIXED_UPDATE_FPS = Const.FIXED_UPDATE_FPS;
	}


	/** Init app assets **/
	function initAssets() {
		// Init game assets
		Assets.init();

		// Init lang data
		Lang.init("en");
	}


	/** Init game controller and default key bindings **/
	function initController() {
		controller = new Controller(ControlActions);
		controller.setGlobalAxisDeadZone(0.4);

		// Keyboard
		controller.bindKeyboardAsStick(MoveX, MoveY, K.UP, K.LEFT, K.DOWN, K.RIGHT);
		controller.bindKeyboardAsStick(MoveX, MoveY, K.W, K.A, K.S, K.D);
		controller.bindKeyboardAsStick(MoveX, MoveY, K.Z, K.Q, K.S, K.D);
		controller.bindKeyboard(Water, [K.F, K.E, K.X, K.SHIFT, K.CTRL, K.ENTER, K.NUMPAD_ENTER]);
		controller.bindKeyboard(Jump, [K.SPACE]);
		controller.bindKeyboard(Restart, [K.R]);
		controller.bindKeyboard(Cancel, [K.ESCAPE]);
		controller.bindKeyboard(Exit, [K.ESCAPE]);
		controller.bindKeyboard(Pause, [K.PAUSE_BREAK,K.P]);

		controller.bindPadLStick(MoveX, MoveY);
		controller.bindPadButtonsAsStick(MoveX, MoveY, DPAD_UP, DPAD_LEFT, DPAD_DOWN, DPAD_RIGHT);
		controller.bindPad(Jump, A);
		controller.bindPad(Water, [X,Y]);
		controller.bindPad(Pause, START);
		controller.bindPad(Restart, SELECT);


		// controller.bind(X, K.SPACE, K.F, K.E);
		// controller.bind(A, K.UP, K.Z, K.W);
		// controller.bind(B, K.ENTER, K.NUMPAD_ENTER);
		// controller.bind(SELECT, K.R);
		// controller.bind(START, K.N);

		ca = controller.createAccess();
	}


	/** Return TRUE if an App instance exists **/
	public static inline function exists() return ME!=null && !ME.destroyed;

	/** Close the app **/
	public function exit() {
		destroy();
	}

	override function onDispose() {
		super.onDispose();

		#if hl
		hxd.System.exit();
		#end
	}


    override function update() {
		Assets.update(tmod);
        super.update();


		if( Game.ME!=null ) {
			// Screenshot pause
			if( ca.isKeyboardPressed(K.BACKSPACE) && Game.exists() ) {
				Game.ME.togglePause();
				Game.ME.setScreenshotMode( Game.ME.isPaused() );
			}

			// Game pause
			if( ca.isPressed(Pause) )
				Game.ME.togglePause();
			else if( Game.ME.isPaused() && ca.isPressed(Cancel) )
				Game.ME.resume();
		}
    }
}