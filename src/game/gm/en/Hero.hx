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
	var verticalAiming = 0;
	var inventory : Array<Enum_Items> = [];
	var bubble : Null<h2d.Bitmap>;

	public function new() {
		data = level.data.l_Entities.all_Hero[0];

		super(data.cx, data.cy);

		ca = App.ME.controller.createAccess("hero");
		ca.setLeftDeadZone(0.3);
		dir = data.f_lookRight ? 1 : -1;

		initLife(data.f_startHP);

		camera.trackEntity(this, true);

		spr.filter = new dn.heaps.filter.PixelOutline(0x330000, 0.4);
		spr.set(Assets.hero);
		spr.anim.registerStateAnim(anims.kickCharge, 8, ()->isChargingAction("kickDoor") );
		spr.anim.registerStateAnim(anims.jumpUp, 7, ()->!onGround && dy<0.1 );
		spr.anim.registerStateAnim(anims.jumpDown, 6, ()->!onGround );
		spr.anim.registerStateAnim(anims.run, 5, 1.3, ()->onGround && M.fabs(dxTotal)>0.05 );
		spr.anim.registerStateAnim(anims.shootUp, 3, ()->isWatering() && verticalAiming<0 );
		spr.anim.registerStateAnim(anims.idleCrouch, 3, ()->isWatering() && verticalAiming>0 );
		spr.anim.registerStateAnim(anims.shoot, 3, ()->isWatering() && verticalAiming==0 );
		spr.anim.registerStateAnim(anims.shootCharge, 2, ()->isChargingAction("water") );
		spr.anim.registerStateAnim(anims.idleCrouch, 1, ()->!cd.has("recentMove"));
		spr.anim.registerStateAnim(anims.idle, 0);

		clearInventory();
	}

	public function hasItem(k:Enum_Items) {
		for(e in inventory)
			if( e==k )
				return true;
		return false;
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

		clearBubble();

		ca.dispose();
		ca = null;
	}

	public function controlsLocked() {
		return ca.locked() || Console.ME.isActive() || isChargingAction();
	}


	override function onLand(cHei:Float) {
		super.onLand(cHei);
		if( cHei>=4 )
			setSquashY(0.6);
		else if( cHei>=2 )
			setSquashY(0.8);
		spr.anim.play(anims.land);
	}

	public function say(str:String, c=0xffffff) {
		hud.notify('"$str"', c);
	}

	function clearBubble() {
		if( bubble!=null ) {
			bubble.remove();
			bubble = null;
		}
	}

	public function sayBubble(e:h2d.Object, ?extraEmote:String) {
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
		f.y = -bubble.tile.height + 9;

		f.addChild(e);
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

		if( onGround && !controlsLocked() && !cd.has("doorKickLimit") ) {
			var d = gm.en.int.Door.getAt(cx+wallDir,cy);
			if( d!=null && d.closed ) {
				if( d.requiredItem!=null && !hasItem(d.requiredItem) ) {
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
							d.open(wallDir);
							d.setSquashX(0.8);
							bump(-wallDir*0.2, -0.1);
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

		if( cd.has("shield") && !cd.hasSetS("shieldBlink",0.2) )
			blink(0xffffff);

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
	}

	function isChargingDirLockAction() {
		return isChargingAction("kickDoor") ||
			isChargingAction("openDoor");
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
			cancelAction("kickDoor");
			cancelAction("openDoor");
			queueCommand(Use);
		}

		if( ca.aPressed() )
			queueCommand(Jump);

		// Dir control
		if( ca.leftDist()>0 && !isChargingDirLockAction())
			dir = M.radDistance(0,ca.leftAngle()) <= M.PIHALF ? 1 : -1;

		// Vertical aiming control
		verticalAiming = 0;
		if( ca.leftDist()>0 && M.radDistance(ca.leftAngle(),-M.PIHALF) <= M.PIHALF*0.65 )
			verticalAiming = -1;
		else if( ca.isKeyboardDown(K.UP) || ca.isKeyboardDown(K.Z) || ca.isKeyboardDown(K.W) )
			verticalAiming = -1;

		if( ca.leftDist()>0 && M.radDistance(ca.leftAngle(),M.PIHALF) <= M.PIHALF*0.65 )
			verticalAiming = 1;
		else if( ca.isKeyboardDown(K.DOWN) || ca.isKeyboardDown(K.S) )
			verticalAiming = 1;

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
				if( verticalAiming==0 ) {
					var b = new gm.en.bu.WaterDrop(shootX, shootY, ang-dir*0.2 + rnd(0, 0.05, true));
					var b = new gm.en.bu.WaterDrop(shootX, shootY, ang-dir*0.1 + rnd(0, 0.05, true));
					b.dx*=0.8;
					cd.setS("bullet",0.02);
				}
				else if( verticalAiming<0 ) {
					shootY-=2;
					var n = 5;
					for(i in 0...n) {
						var b = new gm.en.bu.WaterDrop(shootX, shootY, ang - dir*M.PIHALF*0.85 + i/(n-1)*dir*0.6  + rnd(0, 0.05, true));
						b.gravityMul*=0.85;
					}
					cd.setS("bullet",0.16);
				}
				else {
					var r = 20;
					var n = 5;
					for(i in 0...n) {
						var b = new gm.en.bu.WaterDrop(centerX-r + r*2*i/(n-1), top-10, M.PIHALF + rnd(0, 0.15, true));
						b.gravityMul*=0.7;
					}
				}
			}

			// // Turn off nearby fires
			// dn.Bresenham.iterateDisc(cx,cy,2, (x,y)->{
			// 	if( level.isBurning(cx,cy) )
			// 		level.getFireState(cx,cy).decrease(Const.db.WaterFireDecrease_1);
			// });
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
		dn.Bresenham.iterateDisc(cx,cy,0, (x,y)->{
			if( level.getFireLevel(x,y)>=1 ) {
				cd.setS("burning",2);
				if( level.getFireLevel(x,y)>=2 && !cd.has("shield") )
					hit(1);
			}
		});
	}
}