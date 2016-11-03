package com.babylonhx.materials.lib.grid;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */
class GridMaterialDefines extends MaterialDefines {
	
	public static inline var TRANSPARENT:Int = 0;
	public static inline var FOG:Int = 1;
	

	public function new() {
		super();
		
		this._keys = Vector.fromArrayCopy(["TRANSPARENT", "FOG"]);
		
		defines = new Vector(this._keys.length);
		for (i in 0...this._keys.length) {
			defines[i] = false;
		}
	}
	
}
