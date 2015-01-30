package com.babylonhx.sprites;

import com.babylonhx.math.Color4;
import com.babylonhx.math.Vector3;
import com.babylonhx.animations.Animation;


/**
 * ...
 * @author Krtolica Vujadin
 */

class Sprite {
	
	public var name:String;
	public var position:Vector3;
	public var color:Color4 = new Color4(1.0, 1.0, 1.0, 1.0);
	public var size:Float = 1.0;
	public var angle:Float = 0;
	public var cellIndex:Int = 0;
	public var invertU:Bool = false;
	public var invertV:Bool = false;
	public var disposeWhenFinishedAnimating:Bool;
	public var animations:Array<Animation> = [];

	private var _animationStarted:Bool = false;
	private var _loopAnimation:Bool = false;
	private var _fromIndex:Int = 0;
	private var _toIndex:Int = 0;
	private var _delay:Float = 0;
	private var _direction:Int = 1;
	private var _frameCount:Int = 0;
	private var _manager:SpriteManager;
	private var _time:Float = 0;
	

	public function new(name:String, manager:SpriteManager) {
	this.name = name;
		this._manager = manager;

		this._manager.sprites.push(this);

		this.position = Vector3.Zero();
	}

	public function playAnimation(from:Int, to:Int, loop:Bool, delay:Float):Void {
		this._fromIndex = from;
		this._toIndex = to;
		this._loopAnimation = loop;
		this._delay = delay;
		this._animationStarted = true;

		this._direction = from < to ? 1 : -1;

		this.cellIndex = from;
		this._time = 0;
	}

	public function stopAnimation():Void {
		this._animationStarted = false;
	}

	public function _animate(deltaTime:Float):Void {
		if (!this._animationStarted)
			return;

		this._time += deltaTime;
		if (this._time > this._delay) {
			this._time = this._time % this._delay;
			this.cellIndex += this._direction;
			if (this.cellIndex == this._toIndex) {
				if (this._loopAnimation) {
					this.cellIndex = this._fromIndex;
				} else {
					this._animationStarted = false;
					if (this.disposeWhenFinishedAnimating) {
						this.dispose();
					}
				}
			}
		}
	}

	public function dispose():Void {
		for (i in 0...this._manager.sprites.length) {
			if (this._manager.sprites[i] == this) {
				this._manager.sprites.splice(i, 1);
			}
		}
	}
	
}
