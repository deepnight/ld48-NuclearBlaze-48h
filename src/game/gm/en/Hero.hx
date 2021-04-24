package gm.en;

enum CtrlCommand {
	Jump;
	Use;
}

class Hero extends gm.Entity {
	var data : Entity_Hero;
	var ca : ControllerAccess;
	var walkSpeed = 0.;
	var cmdQueue : Map<CtrlCommand,Float> = new Map();
	var waterAng = 0.;

	public function new() {
		data = level.data.l_Entities.all_Hero[0];

		super(data.cx, data.cy);

		ca = App.ME.controller.createAccess("hero");
		ca.setLeftDeadZone(0.3);

		initLife(data.f_startHP);

		camera.trackEntity(this, true);
		spr.set(dict.doggie);
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
		setSquashY(0.5);
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
		if( ca.xPressed() )
			queueCommand(Use);

		if( ca.aPressed() )
			queueCommand(Jump);

		// Dir control
		if( ca.leftDist()>0 )
			dir = M.radDistance(0,ca.leftAngle()) <= M.PIHALF ? 1 : -1;

		if( !controlsLocked() && !isWatering() ) {

			// Walk
			if( ca.leftDist()>0 ) {
				walkSpeed = Math.cos(ca.leftAngle()) * ca.leftDist();
				dir = M.radDistance(0,ca.leftAngle()) <= M.PIHALF ? 1 : -1;
			}

			// Jump
			if( recentlyOnGround && ifQueuedRemove(Jump) ) {
				dy = -Const.db.HeroJump_1;
				setSquashX(0.6);
				// fx.dotsExplosionExample(centerX, centerY, 0xffcc00);
				clearRecentlyOnGround();
			}

			// Activate interactive
			if( ifQueuedRemove(Use) ) {
				// var e = Interactive.getCurrent(this);
				// if( e!=null )
				// 	e.tryToTrigger();
				// else
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
			if( ca.xDown() )
				cd.setS("watering",0.2);
			camera.shakeS(0.1, 0.1);

			// if( ca.leftDist()>0 )
				// waterAng += M.sign(M.radSubstract(ca.leftAngle(), waterAng)) * 0.1;

			// waterAng += M.radSubstract(dirToAng(), waterAng) * 0.2;
			waterAng = dirToAng();

			var horizontalBeam = ca.leftDist()==0 || M.radDistance(ca.leftAngle(),-M.PIHALF) > M.PIHALF*0.65;

			if( !cd.has("bullet") ) {
				var ang = dirToAng();
				if( horizontalBeam ) {
					var b = new gm.en.bu.WaterDrop(centerX, centerY, ang-dir*0.2 + rnd(0, 0.15, true));
					b.dx *= 1.1;
					cd.setS("bullet",0.03);
				}
				else {
					var n = 4;
					for(i in 0...3)
						new gm.en.bu.WaterDrop(centerX, centerY, ang - dir*M.PIHALF*0.65 + i/(n-1) * 0.4  + rnd(0, 0.15, true));
					// new gm.en.bu.WaterDrop(centerX, centerY, ang - dir*M.PIHALF*0.5 - Math.cos(ftime*0.2)*0.6);
					cd.setS("bullet",0.1);
				}
			}

			dn.Bresenham.iterateDisc(cx,cy,2, (x,y)->{
				if( level.isBurning(cx,cy) )
					level.getFireState(cx,cy).decrease(Const.db.WaterFireDecrease_1);
			});

			// var range = 8;
			// var pts = [];
			// dn.Bresenham.iterateDisc(cx,cy, range, (x,y)->{
			// 	if( level.hasCollision(x,y) || !level.isBurning(x,y) || !sightCheck(x,y) )
			// 		return;

			// 	var a = Math.atan2(y-cy, x-cx);
			// 	if( M.radDistance(a,waterAng) > M.PIHALF*0.4 )
			// 		return;

			// 	pts.push({ a:a, x:x, y:y });
			// });
			// if( pts.length>0 ) {
			// 	var dh = new dn.DecisionHelper(pts);
			// 	dh.score( pt->-M.radDistance(pt.a, waterAng)*5 );
			// 	dh.score( pt->level.getFireState(pt.x,pt.y).level*0.6 );
			// 	dh.score( pt->-distCase(pt.x,pt.y)*0.2 );
			// 	var pt = dh.getBest();
			// 	var r = 1;
			// 	for(y in pt.y-r...pt.y+r+1)
			// 	for(x in pt.x-r...pt.x+r+1) {
			// 		fx.markerCase(x,y, 0.1, 0x4ad8f1);
			// 		var fs = level.getFireState(x, y);
			// 		if( fs==null )
			// 			continue;

			// 		fs.underControlS = Const.db.ControlDuration_1;
			// 		if( fs.level>0 )
			// 			fs.decrease(Const.db.WaterFireDecrease_1);

			// 		if( fs.level==0 )
			// 			fs.setToMin();
			// 	}
			// }
		}

		// Walk movement
		if( walkSpeed!=0 ) {
			dx += walkSpeed*0.05;
		}

		if( level.getFireLevel(cx,cy)>=1 ) {
			cd.setS("burning",2);
			if( level.getFireLevel(cx,cy)>=2 && !cd.has("shield") )
				hit(1);
		}
	}
}