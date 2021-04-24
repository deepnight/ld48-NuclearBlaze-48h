package gm;

class FireState {
	static final MAX = 2;

	public var level(default,null) = 0;
	public var lr(default,null) = 0.; // level ratio

	public var propgationCdS = 0.;

	public inline function new() {}

	@:keep
	public function toString() {
		return 'FS:$level>${Std.int(lr*100)}%';
	}

	public inline function getPowerRatio(step=false) {
		return step
			? level/MAX
			: ( level + M.fmin(lr,0.99) ) / MAX;
	}

	public inline function isBurning() {
		return level>0 || lr>0;
	}

	public inline function isMaxed() {
		return level>=MAX;
	}

	public function ignite(startLevel=0) {
		if( !isBurning() || level<startLevel) {
			level = startLevel;
			lr = 0.01;
		}
	}

	public inline function reset() {
		level = 0;
		lr = 0;
	}

	public inline function increase(ratio:Float) {
		lr+=ratio;
		while( lr>=1 )
			if( level>=MAX ) {
				lr = 1;
				break;
			}
			else {
				level++;
				lr--;
			}
	}

	public inline function decrease(ratio:Float) {
		lr-=ratio;
		while( lr<0 )
			if( level<=0 ) {
				lr = 0;
				break;
			}
			else {
				level--;
				lr++;
			}
	}

	public function dispose() {}
}