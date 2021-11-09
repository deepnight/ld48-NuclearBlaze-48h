package gm.en;

enum CtrlCommand {
	Jump;
	Use;
}

class Hero extends gm.Entity {
	var anims = dn.heaps.assets.Aseprite.getDict( hxd.Res.atlas.hero );

	var data : Entity_Hero;
	var ca : ControllerAccess<ControlActions>;
	var walkSpeed = 0.;
	var climbSpeed = 0.;
	var cmdQueue : Map<CtrlCommand,Float> = new Map();
	var waterAng = 0.;
	var verticalAiming = 0;
	var inventory : Array<Enum_Items> = [];
	var bubble : Null<h2d.Bitmap>;
	var saying : Null<h2d.Flow>;

	public function new() {
		data = level.data.l_Entities.all_Hero[0];

		super(data.cx, data.cy);

		ca = App.ME.controller.createAccess();
		// ca.setLeftDeadZone(0.3);
		dir = data.f_lookRight ? 1 : -1;

		initLife( Std.int(Const.db.HeroHP_1) );
		if( Console.ME.hasFlag("god") )
			initLife(9999);

		camera.trackEntity(this, true);

		spr.filter = new dn.heaps.filter.PixelOutline(0x330000, 0.4);
		spr.set(Assets.hero);
		spr.anim.registerStateAnim(anims.cineFall, 99, ()->cd.has("cineFalling") && !onGround );
		spr.anim.registerStateAnim(anims.deathJump, 99, ()->life<=0 && !onGround );
		spr.anim.registerStateAnim(anims.deathLand, 99, ()->life<=0 && onGround);
		spr.anim.registerStateAnim(anims.kickCharge, 8, ()->isChargingAction("kickDoor") );
		spr.anim.registerStateAnim(anims.climbMove, 8, ()->climbing && climbSpeed!=0 );
		spr.anim.registerStateAnim(anims.climbIdle, 8, ()->climbing && climbSpeed==0 );
		spr.anim.registerStateAnim(anims.jumpUp, 7, ()->!onGround && dy<0.1 );
		spr.anim.registerStateAnim(anims.jumpDown, 6, ()->!onGround );
		spr.anim.registerStateAnim(anims.run, 5, 1.3, ()->onGround && M.fabs(dxTotal)>0.05 );
		spr.anim.registerStateAnim(anims.shootUp, 3, ()->isWatering() && verticalAiming<0 );
		spr.anim.registerStateAnim(anims.shootDown, 3, ()->isWatering() && verticalAiming>0 );
		spr.anim.registerStateAnim(anims.shoot, 3, ()->isWatering() && verticalAiming==0 );
		spr.anim.registerStateAnim(anims.shootCharge, 2, ()->isChargingAction("water") );
		spr.anim.registerStateAnim(anims.idleCrouch, 1, ()->!cd.has("recentMove"));
		spr.anim.registerStateAnim(anims.idle, 0);

		if( level.data.f_cinematicFall )
			cd.setS("cineFalling",Const.INFINITE);

		clearInventory();
	}

	override function getGravity():Float {
		return super.getGravity() * ( cd.has("cineFalling") ? 1.5 : 1 );
	}

	public function hasItem(k:Enum_Items) {
		for(e in inventory)
			if( e==k )
				return true;
		return false;
	}

	override function onDie() {
		hud.notify(L.t._("Press R (or GamePad-Select) to restart"));
		stopClimbing();
		cancelAction();
		cancelVelocities();
		clearBubble();
		clearSaying();
		cd.unset("watering");
		clearCommandQueue();

		setSquashX(0.8);
		camera.shakeS(2, 0.3);
		// collides = false;
		gravityMul = 0.6;
		bump(-dir*0.4, -0.15);
		game.addSlowMo("death", 1, 0.3);
		game.stopFrame();

		game.delayer.addS("deathMsg", say.bind(L.t._("Ouch."), 0x8093AA), 2);
	}

	public function addItem(k:Enum_Items) {
		inventory.push(k);
		hud.setInventory(inventory);
	}

	public function useItem(k:Enum_Items) {
		if( inventory.remove(k) ) {
			hud.setInventory(inventory);
			return true;
		}
		else
			return false;
	}

	public function clearInventory() {
		inventory = [];
		hud.setInventory(inventory);
	}

	override function onDamage(dmg:Int, from:Entity) {
		super.onDamage(dmg, from);
		fx.flashBangS(0xff0000, 0.3, 1);
		cd.setS("shield",Const.db.HeroHitShield_1);
	}

	inline function queueCommand(c:CtrlCommand, durationS=0.15) {
		if( isAlive() )
			cmdQueue.set(c, durationS);
	}

	inline function clearCommandQueue(?c:CtrlCommand) {
		if( c==null )
			cmdQueue = new Map();
		else
			cmdQueue.remove(c);
	}

	inline function isQueued(c:CtrlCommand) {
		return isAlive() && cmdQueue.exists(c);
	}

	inline function ifQueuedRemove(c:CtrlCommand) {
		return isQueued(c) ? { cmdQueue.remove(c); true; } : false;
	}

	override function dispose() {
		super.dispose();

		clearBubble();
		clearSaying();

		ca.dispose();
		ca = null;
	}

	public function controlsLocked() {
		return life<=0 || ca.lockCondition() || Console.ME.isActive() || isChargingAction() || cd.has("cineFalling") || cd.has("lockControls");
	}


	override function onLand(cHei:Float) {
		super.onLand(cHei);
		if( cHei>=4 )
			setSquashY(0.6);
		else if( cHei>=2 )
			setSquashY(0.8);

		if( isAlive() )
			spr.anim.play(anims.land);

		if( cd.has("cineFalling") )  {
			cd.unset("cineFalling");
			spr.anim.play(anims.cineFallLand);
			cd.setS("lockControls", 1);
			camera.shakeS(2,0.4);
			cd.unset("recentMove");
		}
	}

	public function say(str:String, c=0xffffff) {
		clearSaying();

		saying = new h2d.Flow();
		game.scroller.add(saying, Const.DP_UI);
		cd.setS("keepSaying",2.5 + str.length*0.05);
		saying.scaleX = 2;
		saying.scaleY = 0;
		saying.layout = Vertical;
		saying.horizontalAlign = Middle;
		saying.verticalSpacing = 3;

		var tf = new h2d.Text(Assets.fontPixel, saying);
		tf.maxWidth = 120;
		tf.text = str;
		tf.textColor = c;

		var s = Assets.tiles.h_get( Assets.tilesDict.sayLine, saying );
		s.colorize(c);
	}

	function clearBubble() {
		if( bubble!=null ) {
			bubble.remove();
			bubble = null;
		}
	}


	function clearSaying() {
		if( saying!=null ) {
			saying.remove();
			saying = null;
		}
	}

	public function sayBubble(e:h2d.Object, ?extraEmote:String, outlineIcon=true) {
		clearBubble();

		bubble = Assets.tiles.getBitmap(Assets.tilesDict.bubble);
		bubble.tile.setCenterRatio(0.5,1);
		bubble.scaleY = 0;
		bubble.scaleX = 1.5;

		var f = new h2d.Flow(bubble);
		f.layout = Horizontal;
		f.minWidth = Std.int( bubble.tile.width );
		f.verticalAlign = Middle;
		f.horizontalAlign = Middle;
		f.horizontalSpacing = 3;
		f.x = -bubble.tile.width*0.5;
		f.y = -bubble.tile.height + 7;

		f.addChild(e);
		if( outlineIcon )
			e.filter = new dn.heaps.filter.PixelOutline();
		if( extraEmote!=null ) {
			var icon = Assets.tiles.getBitmap(extraEmote);
			icon.filter = new dn.heaps.filter.PixelOutline();
			f.addChild(icon);
		}
		game.scroller.add(bubble, Const.DP_UI);
		cd.setS("keepBubble",1.5);
	}

	override function onTouchWall(wallDir:Int) {
		super.onTouchWall(wallDir);
		dx*=0.66;

		if( !isAlive() ) {
			camera.bump(wallDir*3, 0);
			dx = M.fabs(dx)*-wallDir;
			bdx = M.fabs(bdx)*-wallDir;
			setSquashX(0.8);
		}

		if( isAlive() && onGround && !controlsLocked() && !cd.has("doorKickLimit") ) {
			var d = gm.en.int.Door.getAt(cx+wallDir,cy);
			if( d!=null && d.closed ) {
				if( d.data.f_requireLevelComplete && !game.levelComplete() ) {
					if( !cd.hasSetS("tryToOpen",1) ) {
						spr.anim.play(anims.useStart);
						xr = dirTo(d)==1 ? 0.3 : 0.7;
						chargeAction("openDoor", 0.3, ()->{
							spr.anim.play(anims.useEnd);
							sayBubble( Assets.tiles.getBitmap(dict.emoteFire), Assets.tilesDict.emoteBad, false );
							camera.shakeS(0.1,0.2);
						});
					}
				}
				else if( d.requiredItem!=null && !hasItem(d.requiredItem) ) {
					if( !cd.hasSetS("tryToOpen",1) ) {
						spr.anim.play(anims.useStart);
						xr = dirTo(d)==1 ? 0.3 : 0.7;
						chargeAction("openDoor", 0.3, ()->{
							spr.anim.play(anims.useEnd);
							sayBubble( new h2d.Bitmap(Assets.getItem(d.requiredItem)), Assets.tilesDict.emoteQuestion);
							camera.shakeS(0.1,0.2);
						});
					}
				}
				else if( d.kicks==0 ) {
					spr.anim.play(anims.useStart);
					xr = dirTo(d)==1 ? 0.3 : 0.7;
					chargeAction("openDoor", 0.5, ()->{
						spr.anim.play(anims.useEnd);
						d.open(wallDir);
						d.setSquashX(0.8);
					});
				}
				else
					chargeAction("kickDoor", 0.25, ()->{
						spr.anim.play(anims.kick);
						if( --d.kicks<=0 ) {
							camera.bump(wallDir, 10);
							camera.shakeS(1, 0.3);
							if( !d.open(wallDir) )
								bump(wallDir*0.3, -0.1);
							d.setSquashX(0.8);
							fx.brokenDoor(d.centerX, d.centerY, wallDir);
							game.stopFrame();
						}
						else {
							camera.shakeS(1, 0.1);
							camera.bump(wallDir, 3);
							cd.setS("doorKickLimit",0.3);
							d.setSquashX(0.5);
							sayBubble( Assets.tiles.getBitmap("emoteNumber"+d.kicks), Assets.tilesDict.emoteShield);
						}
					});
			}
		}
	}

	override function postUpdate() {
		super.postUpdate();
		if( cd.has("burning") && !cd.hasSetS("flame",0.2) )
			fx.flame(centerX, centerY);

		if( isAlive() && cd.has("shield") && !cd.hasSetS("shieldBlink",0.2) )
			blink(0xffffff);

		if( !isAlive() && !onGround && !cd.hasSetS("deathBlink",0.15) )
			blink(0xffaa00);

		if( bubble!=null ) {
			bubble.x = sprX;
			bubble.y = top;
			bubble.scaleX += (1-bubble.scaleX) * M.fmin(1, 0.3*tmod);
			bubble.scaleY += (1-bubble.scaleY) * M.fmin(1, 0.3*tmod);
			if( !cd.has("keepBubble") ) {
				bubble.alpha-=0.03*tmod;
				if( bubble.alpha<=0 )
					clearBubble();
			}
		}
		if( saying!=null ) {
			saying.scaleX += (1-saying.scaleX) * M.fmin(1, 0.3*tmod);
			saying.scaleY += (1-saying.scaleY) * M.fmin(1, 0.3*tmod);
			saying.x = Std.int( sprX - saying.outerWidth*0.5*saying.scaleX );
			saying.y = Std.int( top - saying.outerHeight*saying.scaleY );
			if( bubble!=null )
				bubble.y-=saying.outerHeight;
			if( !cd.has("keepSaying") ) {
				saying.alpha-=0.03*tmod;
				if( saying.alpha<=0 )
					clearSaying();
			}
		}
	}

	function isChargingDirLockAction() {
		return isChargingAction("kickDoor") ||
			isChargingAction("openDoor");
	}

	inline function isWatering() return cd.has("watering");

	var climbInsistS = 0.;
	override function preUpdate() {
		super.preUpdate();

		walkSpeed = 0;
		climbSpeed = 0;

		// Command input queue management
		for( k in cmdQueue.keys() ) {
			cmdQueue.set(k, cmdQueue.get(k) - 1/Const.FPS*tmod);
			if( cmdQueue.get(k)<=0 )
				cmdQueue.remove(k);
		}

		// Control queueing
		if( ca.isDown(Water) && !isWatering() ) {
			cancelAction("jump");
			cancelAction("kickDoor");
			cancelAction("openDoor");
			stopClimbing();
			queueCommand(Use);
		}
		if( ca.isPressed(Jump) ) {
			queueCommand(Jump);
			if( climbing && ( ca.isKeyboardDown(K.UP) || ca.isKeyboardDown(K.Z) || ca.isKeyboardDown(K.W) ) )
				clearCommandQueue(Jump);
		}


		// Dir control
		if( isAlive() && ca.getAnalogDist(MoveX,MoveY)>0 && !isChargingDirLockAction())
			dir = M.radDistance(0,ca.getAnalogAngle(MoveX,MoveY)) <= M.PIHALF ? 1 : -1;


		// Vertical aiming control
		verticalAiming = 0;
		if( ca.getAnalogDist(MoveX,MoveY)>0 && M.radDistance(ca.getAnalogAngle(MoveX,MoveY),-M.PIHALF) <= M.PIHALF*0.65 )
			verticalAiming = -1;
		else if( ca.isKeyboardDown(K.UP) || ca.isKeyboardDown(K.Z) || ca.isKeyboardDown(K.W) )
			verticalAiming = -1;

		if( ca.getAnalogDist(MoveX,MoveY)>0 && M.radDistance(ca.getAnalogAngle(MoveX,MoveY),M.PIHALF) <= M.PIHALF*0.65 )
			verticalAiming = 1;
		else if( ca.isKeyboardDown(K.DOWN) || ca.isKeyboardDown(K.S) )
			verticalAiming = 1;


		// Climb start management (complicated stuff to avoid confusions with "aiming up/down")
		var tryToClimbUp = false;
		var tryToClimbDown = false;
		if( isAlive() && !climbing && !ca.isDown(Water) && !isWatering() && !cd.has("climbLock") ) {
			// Up
			if( level.hasLadder(cx,cy) && verticalAiming==-1 )
				tryToClimbUp = true;

			// Down
			if( level.hasLadder(cx,cy) && !level.hasAnyCollision(cx,cy+1) || level.hasLadder(cx,cy+1) || level.hasLadder(cx,cy+2) )
				if( verticalAiming==1 )
					tryToClimbDown = true;
		}
		if( tryToClimbUp || tryToClimbDown )
			clearCommandQueue(Jump);
		else
			climbInsistS = 0;

		if( climbing )
			climbInsistS = 0;


		if( !controlsLocked() && !isWatering() ) {
			// Start climbing up/down
			if( tryToClimbUp || tryToClimbDown ) {
				climbInsistS += 1/Const.FPS * tmod;
				if( climbInsistS>=0.12 ) {
					startClimbing();
					if( tryToClimbUp )
						dy = -0.1;
					else {
						if( onGround ) {
							cy++;
							yr = 0;
						}
						dy = 0.1;
					}
				}
			}

			// Walk
			if( ca.getAnalogDist(MoveX,MoveY)>0 && !climbing ) {
				walkSpeed = Math.cos(ca.getAnalogAngle(MoveX,MoveY)) * ca.getAnalogDist(MoveX,MoveY);
				dir = M.radDistance(0,ca.getAnalogAngle(MoveX,MoveY)) <= M.PIHALF ? 1 : -1;
			}

			// Jump
			if( ( climbing || recentlyOnGround ) && ifQueuedRemove(Jump) ) {
				chargeAction("jump", 0.08, ()->{
					if( climbing && verticalAiming==1 ) {
						dy = 0.4;
						cd.setS("oneWayLock",0.35);
					}
					else if( climbing && verticalAiming==0 )
						dy = -Const.db.HeroJump_1 * 0.4;
					else
						dy = -Const.db.HeroJump_1;
					stopClimbing();
					cd.setS("climbLock",0.35);
					setSquashX(0.6);
					clearRecentlyOnGround();
				});
			}

			// Climbing
			if( climbing ) {
				if( verticalAiming==-1 )
					climbSpeed = -1;
				else if( verticalAiming==1 )
					climbSpeed = 1;
			}

			// Activate interactive
			if( onGround && ifQueuedRemove(Use) ) {
				dx = 0;
				chargeAction("water", 0.1, ()->{
					cd.setS("watering",0.2);
					if( ca.getAnalogDist(MoveX,MoveY)>0 )
						waterAng = ca.getAnalogAngle(MoveX,MoveY);
					else
						waterAng = dirToAng();
				});
			}
		}
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		// Climb one ways
		if( level.hasOneWay(cx,cy-1) && dy>0 && yr<=0.3 && !climbing && !cd.has("oneWayLock") ) {
			setSquashX(0.6);
			yr = M.fmin(0.1,yr);
			bdy = 0;
			dy = -0.55;
		}

		// Lost ladder
		if( climbing && !level.hasLadder(cx,cy) && !level.hasLadder(cx,cy+1) )
			stopClimbing();

		// Reach ladder top
		if( climbing && climbSpeed<0 && !level.hasLadder(cx,cy-1) && !level.hasAnyCollision(cx,cy-1) ) {
			stopClimbing();
			dy = -0.5;
		}

		// Reach ladder bottom
		if( climbing && climbSpeed>0 && level.hasAnyCollision(cx,cy+1) ) {
			stopClimbing();
			dy = 0.2;
		}

		// Recenter on ladder
		if( climbing )
			xr+= (0.5-dir*0.2 - xr)*0.5;

		// Walk movement
		if( walkSpeed!=0 ) {
			dx += walkSpeed*0.03;
			cd.setS("recentMove",0.3);
		}
		else if( !isChargingAction("jump") )
			dx*=0.6;


		// Climb movement
		if( climbing )
			if( climbSpeed!=0 && !cd.hasSetS("climbStep",0.3) ) {
				dy+=climbSpeed * 0.2;
				setSquashY(0.8);
			}
			else if( climbSpeed==0 )
				dy*=0.5;

		if( !onGround )
			cd.setS("recentMove",0.6);

		// Fire damage
		if( isAlive() )
			dn.Bresenham.iterateDisc(cx,cy,0, (x,y)->{
				if( level.getFireLevel(x,y)>=1 ) {
					cd.setS("burning",2);
					if( level.getFireLevel(x,y)>=2 && !cd.has("shield") )
						hit(1);
				}
			});


		// Shooting water
		if( isWatering() ) {
			dx*=0.5;

			if( ca.isDown(Water) )
				cd.setS("watering",0.2);
			camera.shakeS(0.1, 0.1);

			// if( ca.getAnalogDist(MoveX,MoveY)>0 )
				// waterAng += M.sign(M.radSubstract(ca.getAnalogAngle(MoveX,MoveY), waterAng)) * 0.1;

			// waterAng += M.radSubstract(dirToAng(), waterAng) * 0.2;
			waterAng = dirToAng();

			if( !cd.has("bullet") ) {
				var ang = dirToAng();
				var shootX = centerX+dir*5;
				var shootY = centerY+3;
				if( verticalAiming==0 ) {
					// Horizontal
					var b = new gm.en.bu.WaterDrop(shootX, shootY, ang-dir*0.2 + rnd(0, 0.05, true));
					var b = new gm.en.bu.WaterDrop(shootX, shootY, ang-dir*0.1 + rnd(0, 0.05, true));
					b.dx*=0.8;
					b.cd.setS("lock",0.03);
					cd.setS("bullet",0.02);
				}
				else if( verticalAiming<0 ) {
					// UP
					shootY-=2;
					var n = 5;
					for(i in 0...n) {
						var b = new gm.en.bu.WaterDrop(shootX, shootY, ang - dir*M.PIHALF*0.85 + i/(n-1)*dir*0.6  + rnd(0, 0.05, true));
						b.gravityMul*=0.8;
					}
					cd.setS("bullet",0.16);
				}
				else {
					// Self
					var n = 6;
					var ang = 0.25;
					for(i in 0...n) {
						var b = new gm.en.bu.WaterDrop(centerX, centerY, -M.PIHALF - ang + ang*2*i/(n-1) );
						b.frictY = 0.85;
						b.gravityMul = 2.4;
						b.power = 2;
					}
					cd.setS("bullet",0.16);
				}
			}

		}

	}
}