package gm;

class Level extends dn.Process {
	var game(get,never) : Game; inline function get_game() return Game.ME;
	var fx(get,never) : Fx; inline function get_fx() return Game.ME.fx;

	/** Level grid-based width**/
	public var cWid(get,never) : Int; inline function get_cWid() return data.l_Collisions.cWid;

	/** Level grid-based height **/
	public var cHei(get,never) : Int; inline function get_cHei() return data.l_Collisions.cHei;

	/** Level pixel width**/
	public var pxWid(get,never) : Int; inline function get_pxWid() return cWid*Const.GRID;

	/** Level pixel height**/
	public var pxHei(get,never) : Int; inline function get_pxHei() return cHei*Const.GRID;

	public var data : World_Level;
	var tilesetSource : h2d.Tile;

	var collOverride : Map<Int,Bool> = new Map();
	var marks : Map< LevelMark, Map<Int,Bool> > = new Map();
	public var fireStates : Map<Int,FireState> = new Map();
	var invalidated = true;

	public function new(ldtkLevel:World.World_Level) {
		super(Game.ME);

		createRootInLayers(Game.ME.scroller, Const.DP_BG);
		data = ldtkLevel;
		tilesetSource = hxd.Res.atlas.world.toAseprite().toTile();

		// Init fire spots
		for(cy in 0...data.l_Collisions.cHei)
		for(cx in 0...data.l_Collisions.cWid) {
			if( hasCollision(cx,cy) )
				continue;

			if( cx<=0 || cy<=0 || cx>=cWid-1 || cy>=cHei-1 )
				continue;

			if( hasCollision(cx,cy+1) )
				fireStates.set( coordId(cx,cy), new FireState() );
			else if( hasCollision(cx,cy-1) )
				fireStates.set( coordId(cx,cy), new FireState() );
			else if( ( hasCollision(cx-1,cy) || hasCollision(cx+1,cy) ) && cy%2==0 )
				fireStates.set( coordId(cx,cy), new FireState() );
		}
	}

	override function onDispose() {
		super.onDispose();

		for(fs in fireStates)
			fs.dispose();
		fireStates = null;

		data = null;
		tilesetSource = null;
		marks = null;
	}

	/** TRUE if given coords are in level bounds **/
	public inline function isValid(cx,cy) return cx>=0 && cx<cWid && cy>=0 && cy<cHei;

	/** Gets the integer ID of a given level grid coord **/
	public inline function coordId(cx,cy) return cx + cy*cWid;

	/** Ask for a level render that will only happen at the end of the current frame. **/
	public inline function invalidate() {
		invalidated = true;
	}

	/** Return TRUE if mark is present at coordinates **/
	public inline function hasMark(mark:LevelMark, cx:Int, cy:Int) {
		return !isValid(cx,cy) || !marks.exists(mark) ? false : marks.get(mark).exists( coordId(cx,cy) );
	}

	/** Enable mark at coordinates **/
	public function setMark(mark:LevelMark, cx:Int, cy:Int) {
		if( isValid(cx,cy) && !hasMark(mark,cx,cy) ) {
			if( !marks.exists(mark) )
				marks.set(mark, new Map());
			marks.get(mark).set( coordId(cx,cy), true );
		}
	}

	/** Remove mark at coordinates **/
	public function removeMark(mark:LevelMark, cx:Int, cy:Int) {
		if( isValid(cx,cy) && hasMark(mark,cx,cy) )
			marks.get(mark).remove( coordId(cx,cy) );
	}

	public function setCollisionOverride(cx,cy, coll:Null<Bool>) {
		if( isValid(cx,cy) )
			if( coll!=null )
				collOverride.set( coordId(cx,cy), coll );
			else
				collOverride.remove( coordId(cx,cy) );
	}

	/** Return TRUE if "Collisions" layer contains a collision value **/
	public inline function hasCollision(cx,cy) : Bool {
		return !isValid(cx,cy)
			? true
			: collOverride.exists(coordId(cx,cy))
				? collOverride.get(coordId(cx,cy))
				: data.l_Collisions.getInt(cx,cy)==1;
	}

	/** Render current level**/
	function render() {
		root.removeChildren();

		var layer = data.l_Collisions;

		// var g = new h2d.Graphics(root);
		// for(cy in 0...layer.cHei)
		// for(cx in 0...layer.cWid) {
		// 	if( !layer.hasValue(cx,cy) )
		// 		continue;
		// 	g.beginFill(0xffffff);
		// 	g.drawRect( layer.gridSize*cx, layer.gridSize*cy, layer.gridSize, layer.gridSize);
		// }

		var tg = new h2d.TileGroup(tilesetSource, root);
		for( autoTile in layer.autoTiles ) {
			var tile = layer.tileset.getAutoLayerTile(autoTile);
			tg.add(autoTile.renderX, autoTile.renderY, tile);
		}
	}

	public inline function hasFireState(cx,cy) {
		return isValid(cx,cy) && fireStates.exists( coordId(cx,cy) );
	}

	public inline function getFireState(cx,cy) : Null<FireState> {
		return hasFireState(cx,cy) ? fireStates.get( coordId(cx,cy) ) : null;
	}

	public inline function isBurning(cx,cy) {
		return hasFireState(cx,cy) && fireStates.get( coordId(cx,cy) ).isBurning();
	}

	public inline function getFireLevel(cx,cy) {
		return isBurning(cx,cy) ? getFireState(cx,cy).level : 0;
	}

	public inline function ignite(cx,cy, startLevel=0) {
		if( hasFireState(cx,cy) && !hasCollision(cx,cy) )
			getFireState(cx,cy).ignite(startLevel);
	}

	override function postUpdate() {
		super.postUpdate();

		// Level render
		if( invalidated ) {
			invalidated = false;
			render();
		}

		// Fire fx
		if( !cd.hasSetS("flames",0.4) ) {
			var smoke = !cd.hasSetS("flamesSmoke",0.4);
			var fs : FireState = null;
			for(cy in 0...data.l_Collisions.cHei)
			for(cx in 0...data.l_Collisions.cWid)
				if( Game.ME.camera.isOnScreenCase(cx,cy,64) && isBurning(cx,cy) ) {
					fs = getFireState(cx,cy);
					fx.levelFlames(cx, cy, fs);
					if( !hasCollision(cx,cy-1) )
						fx.levelFireSparks(cx, cy, fs);

					if( smoke && hasCollision(cx,cy+1) )
						fx.levelFireSmoke(cx, cy, fs);
				}
		}
	}

	function canSeeThrough(cx,cy) {
		return isValid(cx,cy) && !hasCollision(cx,cy);
	}
	inline function sighCheck(x1,y1,x2,y2) {
		return dn.Bresenham.checkThinLine(x1,y1, x2,y2, canSeeThrough);
	}

	function updateFire() {
		var fs : FireState = null;
		var range = Std.int(Const.db.FirePropagationRange_1);

		for(cy in 0...data.l_Collisions.cHei)
		for(cx in 0...data.l_Collisions.cWid) {
			if( hasFireState(cx,cy) ) {
				fs = getFireState(cx,cy);

				// Increase
				if( fs.isBurning() && !fs.isUnderControl() )
					fs.increase( Const.db.FireIncPerTick_1);

				// Update cooldown
				if( fs.propgationCdS>0 )
					fs.propgationCdS -= Const.db.FireTick_1;

				// Update underControlness
				if( fs.underControlS>0 )
					fs.underControlS -= Const.db.FireTick_1;

				// Try to propagate
				if( !fs.isUnderControl() && fs.isMaxed() && fs.propgationCdS<=0 && Std.random(100) < Const.db.FirePropagation_1*100 ) {
					fs.propgationCdS = Const.db.FirePropagation_2;
					for(y in cy-range...cy+range+1)
					for(x in cx-range...cx+range+1)
						if( sighCheck(cx,cy, x,y) )
							ignite(x,y);
				}
			}
		}
	}

	override function update() {
		super.update();

		// Fire update
		if( !cd.hasSetS("fireTick",Const.db.FireTick_1) )
			updateFire();
	}
}