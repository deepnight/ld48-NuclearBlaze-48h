enum Affect {
	Stun;
}

enum LevelMark {
	WallEdge;
	DoorZone;
}

enum abstract ControlActions(Int) to Int {
	var MoveX;
	var MoveY;
	var Jump;
	var Water;

	var Pause;
	var Restart;
	var Cancel;
	var Exit;
}