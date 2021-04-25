package gm.en;

enum CtrlCommand {
	Jump;
	Use;
}

class Hero extends gm.Entity {
	var anims = dn.heaps.assets.Aseprite.getDict( hxd.Res.atlas.hero );

	var data : Entity_Hero;
	var ca : ControllerAccess;
	var walkSpeed = 0.;
	var cmdQueue : Map<CtrlCommand,Float> = new Map();
	var waterAng = 0.;
	var aimingUp = false;

	public function new() {
		data = level.data.l_Entities.all_Hero[0];

		super(data.cx, data.cy);

		ca = App.ME.controller.createAccess("hero");
		ca.setLeftDeadZone(0.3);

		initLife(data.f_startHP);

		camera.trackEntity(this, true);

		spr.filter = new dn.heaps.filter.PixelOutline(0x330000, 0.4);
		spr.set(Assets.hero);
		spr.anim.registerStateAnim(anims.jumpUp, 7, ()->!onGround && dy<0.1 );
		spr.anim.registerStateAnim(anims.jumpDown, 6, ()->!onGround );
		spr.anim.registerStateAnim(anims.run, 5, 1.3, ()->onGround && M.fabs(dxTotal)>0.05 );
		spr.anim.registerStateAnim(anims.shootUp, 4, ()->isWatering() && aimingUp );
		spr.anim.registerStateAnim(anims.shoot, 3, ()->isWatering() && !aimingUp );
		spr.anim.registerStateAnim(anims.shootCharge, 2, ()->isChargingAction("water") );
		spr.anim.registerStateAnim(anims.idleCrouch, 1, ()->!cd.has("recentMove"));
		spr.anim.registerStateAnim(anims.idle, 0);
	}

	override function onDamage(dmg:Int, from:Entity) {
		super.onDamage(dmg, from);
		fx.flashBangS(0xff0000, 0.3, 1);
		cd.setS("shield",Const.db.HeroHitShield_1);
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

	public function controlsLocked() {
		return ca.locked() || Console.ME.isActive() || isChargingAction();
	}


	override function onLand(cHei:Float) {
		super.onLand(cHei);
		setSquashY(0.8);
		spr.anim.play(anims.land);
	}

	override function onTouchWall(wallDir:Int) {
		super.onTouchWall(wallDir);
		dx*=0.66;

		if( !controlsLocked() ) {
			var d = gm.en.int.Door.getAt(cx+wallDir,cy);
			if( d!=null && d.closed )
				chargeAction("door", 0.25, ()->{
					camera.shakeS(1, 0.3);
					camera.bump(wallDir, 10);
					d.open(wallDir);
					d.setSquashX(0.8);
				});
		}
	}

	override function postUpdate() {
		super.postUpdate();
		if( cd.has("burning") && !cd.hasSetS("flame",0.2) )
			fx.flame(centerX, centerY);

		if( cd.has("shield") && !cd.hasSetS("shieldBlink",0.2) )
			blink(0xffffff);
	}

	inline function isWatering() return cd.has("watering");

	override function preUpdate() {
		super.preUpdate();

		walkSpeed = 0;

		// Command input queue management
		for( k in cmdQueue.keys() ) {
			cmdQueue.set(k, cmdQueue.get(k) - 1/Const.FPS*tmod);
			if( cmdQueue.get(k)<=0 )
				cmdQueue.remove(k);
		}


		// Control queueing
		if( ca.xDown() && !isWatering() ) {
			cancelAction("jump");
			queueCommand(Use);
		}

		if( ca.aPressed() )
			queueCommand(Jump);

		// Dir control
		if( ca.leftDist()>0 )
			dir = M.radDistance(0,ca.leftAngle()) <= M.PIHALF ? 1 : -1;

		// Vertical aiming control
		aimingUp = ca.leftDist()>0 && M.radDistance(ca.leftAngle(),-M.PIHALF) <= M.PIHALF*0.65;
		if( ca.isKeyboardDown(K.UP) || ca.isKeyboardDown(K.Z) || ca.isKeyboardDown(K.W) )
			aimingUp = true;

		if( !controlsLocked() && !isWatering() ) {

			// Walk
			if( ca.leftDist()>0 ) {
				walkSpeed = Math.cos(ca.leftAngle()) * ca.leftDist();
				dir = M.radDistance(0,ca.leftAngle()) <= M.PIHALF ? 1 : -1;
			}

			// Jump
			if( recentlyOnGround && ifQueuedRemove(Jump) ) {
				chargeAction("jump", 0.08, ()->{
					dy = -Const.db.HeroJump_1;
					setSquashX(0.6);
					clearRecentlyOnGround();
				});
			}

			// Activate interactive
			if( onGround && ifQueuedRemove(Use) ) {
				dx = 0;
				chargeAction("water", 0.2, ()->{
					cd.setS("watering",0.2);
					if( ca.leftDist()>0 )
						waterAng = ca.leftAngle();
					else
						waterAng = dirToAng();
				});
			}
		}
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		if( isWatering() ) {
			dx*=0.5;

			if( ca.xDown() )
				cd.setS("watering",0.2);
			camera.shakeS(0.1, 0.1);

			// if( ca.leftDist()>0 )
				// waterAng += M.sign(M.radSubstract(ca.leftAngle(), waterAng)) * 0.1;

			// waterAng += M.radSubstract(dirToAng(), waterAng) * 0.2;
			waterAng = dirToAng();

			if( !cd.has("bullet") ) {
				var ang = dirToAng();
				var shootX = centerX+dir*5;
				var shootY = centerY+3;
				if( !aimingUp ) {
					var b = new gm.en.bu.WaterDrop(shootX, shootY, ang-dir*0.2 + rnd(0, 0.05, true));
					var b = new gm.en.bu.WaterDrop(shootX, shootY, ang-dir*0.1 + rnd(0, 0.05, true));
					b.dx*=0.8;
					cd.setS("bullet",0.02);
				}
				else {
					shootY-=2;
					var n = 4;
					for(i in 0...3) {
						var b = new gm.en.bu.WaterDrop(shootX, shootY, ang - dir*M.PIHALF*0.85 + i/(n-1)*dir*0.7  + rnd(0, 0.05, true));
						b.gravityMul*=0.85;
					}
					cd.setS("bullet",0.13);
				}
			}

			// Turn off nearby fires
			dn.Bresenham.iterateDisc(cx,cy,2, (x,y)->{
				if( level.isBurning(cx,cy) )
					level.getFireState(cx,cy).decrease(Const.db.WaterFireDecrease_1);
			});
		}


		// Walk movement
		if( walkSpeed!=0 ) {
			dx += walkSpeed*0.03;
			cd.setS("recentMove",0.3);
		}
		else if( !isChargingAction("jump") )
			dx*=0.6;

		if( !onGround )
			cd.setS("recentMove",0.6);


		// Fire damage
		dn.Bresenham.iterateDisc(cx,cy,1, (x,y)->{
			if( level.getFireLevel(x,y)>=1 ) {
				cd.setS("burning",2);
				if( level.getFireLevel(x,y)>=2 && !cd.has("shield") )
					hit(1);
			}
		});
	}
}