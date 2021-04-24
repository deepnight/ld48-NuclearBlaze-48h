package gm;

class FireState {
	static final MAX = 2;

	public var level(default,null) = 0;
	public var lr(default,null) = 0.; // level ratio

	public inline function new() {}

	@:keep
	public function toString() {
		return 'FS:${Std.int((level+lr)*10)/10}';
	}

	public inline function reset() {
		level = 0;
		lr = 0;
	}

	public inline function increase(ratio:Float) {
		lr+=ratio;
		while( lr>=1 )
			if( level>=MAX )
				lr = 0.99;
			else {
				level++;
				lr--;
			}
	}

	public inline function decrease(ratio:Float) {
		lr-=ratio;
		while( lr<0 )
			if( level<=0 )
				lr = 0;
			else {
				level--;
				lr++;
			}
	}

	public function dispose() {}
}