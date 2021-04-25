package gm.en;

class Item extends Entity {
	public var data : Entity_Item;
	public function new(d:Entity_Item) {
		data = d;
		super(d.cx, d.cy);

		spr.set("item"+data.f_type.getName());
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		if( distCase(hero)<=1 ) {
			fx.itemPickUp(centerX, centerY, Assets.worldData.getEnumColor(data.f_type) );
			hero.addItem(data.f_type);
			destroy();
			return;
		}

		if( onGround && !cd.hasSetS("jump",1) )
			dy = -0.1;
	}
}