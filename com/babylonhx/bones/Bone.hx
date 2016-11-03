package com.babylonhx.bones;

import com.babylonhx.animations.IAnimatable;
import com.babylonhx.math.Matrix;
import com.babylonhx.math.Quaternion;
import com.babylonhx.math.Vector3;
import com.babylonhx.animations.Animation;
import com.babylonhx.animations.AnimationRange;

/**
* ...
* @author Krtolica Vujadin
*/

@:expose('BABYLON.Bone') class Bone extends Node implements IAnimatable {
	
	public var children:Array<Bone> = [];
	public var length:Int = -1;

	private var _skeleton:Skeleton;
	private var _matrix:Matrix;
	private var _restPose:Matrix;
	private var _baseMatrix:Matrix;
	private var _worldTransform:Matrix = new Matrix();
	private var _absoluteTransform:Matrix = new Matrix();
	private var _invertedAbsoluteTransform:Matrix = new Matrix();
	private var _parent:Bone;

	
	public function new(name:String, skeleton:Skeleton, parentBone:Bone = null, matrix:Matrix, ?restPose:Matrix) {
		super(name, skeleton.getScene());
		
		this._skeleton = skeleton;
		this._matrix = matrix;
		this._baseMatrix = matrix;
		this._restPose = restPose != null ? restPose : matrix.clone();
		
		skeleton.bones.push(this);
		
		if (parentBone != null) {
			this._parent = parentBone;
			parentBone.children.push(this);
		} 
		else {
			this._parent = null;
		}
		
		this._updateDifferenceMatrix();
	}

	// Members
	inline public function getParent():Bone {
		return this._parent;
	}

	inline public function getLocalMatrix():Matrix {
		return this._matrix;
	}

	inline public function getBaseMatrix():Matrix {
		return this._baseMatrix;
	}
	
	inline public function getRestPose():Matrix {
		return this._restPose;
	}
	
	inline public function returnToRest() {
		this.updateMatrix(this._restPose.clone());
	}

	override public function getWorldMatrix():Matrix {
		return this._worldTransform;
	}	
	
	inline public function getInvertedAbsoluteTransform():Matrix {
		return this._invertedAbsoluteTransform;
	}
	
	inline public function getAbsoluteTransform():Matrix {
		return this._absoluteTransform;
	}

	// Methods
	inline public function updateMatrix(matrix:Matrix, updateDifferenceMatrix:Bool = true) {
		this._baseMatrix = matrix.clone();
		this._matrix = matrix.clone();
		
		this._skeleton._markAsDirty();
		
		if (updateDifferenceMatrix) {
			this._updateDifferenceMatrix();
		}
	}

	@:allow(com.babylonhx.bones.Skeleton)
	inline private function _updateDifferenceMatrix(?rootMatrix:Matrix) {
		if (rootMatrix == null) {
			rootMatrix = this._baseMatrix;
		}
		
		if (this._parent != null) {
			rootMatrix.multiplyToRef(this._parent._absoluteTransform, this._absoluteTransform);
		} 
		else {
			this._absoluteTransform.copyFrom(rootMatrix);
		}
		
		this._absoluteTransform.invertToRef(this._invertedAbsoluteTransform);
		
		for (index in 0...this.children.length) {
			this.children[index]._updateDifferenceMatrix();
		}
	}

	inline public function markAsDirty() {
		this._currentRenderId++;
		this._skeleton._markAsDirty();
	}
	
	public function copyAnimationRange(source:Bone, rangeName:String, frameOffset:Int, rescaleAsRequired:Bool = false, skelDimensionsRatio:Vector3 = null):Bool {
		// all animation may be coming from a library skeleton, so may need to create animation
		if (this.animations.length == 0){
			this.animations.push(new Animation(this.name, "_matrix", source.animations[0].framePerSecond, Animation.ANIMATIONTYPE_MATRIX, 0)); 
			this.animations[0].setKeys([{ frame: 0, value: 0 }]);
		}
		
		// get animation info / verify there is such a range from the source bone
		var sourceRange:AnimationRange = source.animations[0].getRange(rangeName);
		if (sourceRange == null) {
			return false;
		}
		
		var from = sourceRange.from;
		var to = sourceRange.to;
		var sourceKeys = source.animations[0].getKeys();
		
		// rescaling prep
		var sourceBoneLength = source.length;
		var sourceParent = source.getParent();
		var parent = this.getParent();
		var parentScalingReqd = rescaleAsRequired && sourceParent != null && sourceBoneLength > 0 && this.length > 0 && sourceBoneLength != this.length;
		var parentRatio = parentScalingReqd ? parent.length / sourceParent.length : null;
		
		var dimensionsScalingReqd = rescaleAsRequired && parent == null && skelDimensionsRatio != null && (skelDimensionsRatio.x != 1 || skelDimensionsRatio.y != 1 || skelDimensionsRatio.z != 1);           
		
		var destKeys = this.animations[0].getKeys();
		
		// loop vars declaration
		var orig:BabylonFrame = null;
		var origTranslation:Vector3;
		var mat:Matrix = null;
		
		for (key in 0...sourceKeys.length) {
			orig = sourceKeys[key];
			if (orig.frame >= from  && orig.frame <= to) {
				if (rescaleAsRequired) {
					mat = orig.value.clone();
					
					// scale based on parent ratio, when bone has parent
					if (parentScalingReqd) {
						origTranslation = mat.getTranslation();
						mat.setTranslation(origTranslation.scaleInPlace(parentRatio));					
					} // scale based on skeleton dimension ratio when root bone, and value is passed
					else if (dimensionsScalingReqd) {
						origTranslation = mat.getTranslation();
						mat.setTranslation(origTranslation.multiplyInPlace(skelDimensionsRatio)); 
					} // use original when root bone, and no data for skelDimensionsRatio
					else {
						mat = orig.value;                            
					}
				}
				else {
					mat = orig.value;
				}
				
				destKeys.push( { frame: orig.frame + frameOffset, value: mat } );
			}
		}
		this.animations[0].createRange(rangeName, from + frameOffset, to + frameOffset);
		
		return true;
	}
	
}
