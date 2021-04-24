package gm.en;

enum CtrlCommand {
	Jump;
}

class Hero extends gm.Entity {
	var data : Entity_Hero;
	var ca : ControllerAccess;
	var walkSpeed = 0.;
	var cmdQueue : Map<CtrlCommand,Float> = new Map();

	public function new() {
		data = level.data.l_Entities.all_Hero[0];

		super(data.cx, data.cy);

		ca = App.ME.controller.createAccess("hero");
		ca.setLeftDeadZone(0.3);

		camera.trackEntity(this, true);
	}

	inline function queueCommand(c:CtrlCommand, durationS=0.15) {
		cmdQueue.set(c, durationS);
	}

	inline function clearCommandQueue(?c:CtrlCommand) {
		if( c==null )
			cmdQueue = new Map();
		else
			cmdQueue.remove(c);
	}

	inline function isQueued(c:CtrlCommand) {
		return cmdQueue.exists(c);
	}

	inline function ifQueuedRemove(c:CtrlCommand) {
		return isQueued(c) ? { cmdQueue.remove(c); true; } : false;
	}

	override function dispose() {
		super.dispose();

		ca.dispose();
		ca = null;
	}

	function controlsLocked() {
		return ca.locked() || Console.ME.isActive();
	}

	override function onTouchWall(wallDir:Int) {
		super.onTouchWall(wallDir);
		dx*=0.66;
	}

	override function preUpdate() {
		super.preUpdate();

		// Command input queue management
		for( k in cmdQueue.keys() ) {
			cmdQueue.set(k, cmdQueue.get(k) - 1/Const.FPS*tmod);
			if( cmdQueue.get(k)<=0 )
				cmdQueue.remove(k);
		}

		walkSpeed = 0;
		if( !controlsLocked() ) {

			// Walk
			if( ca.leftDist()>0 ) {
				walkSpeed = Math.cos(ca.leftAngle()) * ca.leftDist();
				dir = M.radDistance(0,ca.leftAngle()) <= M.PIHALF ? 1 : -1;
			}

			// Jump
			if( ca.aPressed() )
				queueCommand(Jump);

			if( recentlyOnGround && ifQueuedRemove(Jump) ) {
				dy = -Const.db.HeroJump_1;
				setSquashX(0.6);
				fx.dotsExplosionExample(centerX, centerY, 0xffcc00);
				clearRecentlyOnGround();
			}

			// Jump
			if( ca.aPressed() && onGround ) {
				dy = -0.3;
			}

		}
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		// Walk movement
		if( walkSpeed!=0 ) {
			dx += walkSpeed*0.05;
		}
	}
}