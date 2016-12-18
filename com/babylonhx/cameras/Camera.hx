package com.babylonhx.cameras;

import com.babylonhx.math.Matrix;
import com.babylonhx.math.Plane;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Viewport;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.postprocess.PostProcess;
import com.babylonhx.tools.SmartArray;
import com.babylonhx.math.Tools;
import com.babylonhx.tools.Tags;
import com.babylonhx.postprocess.AnaglyphPostProcess;
import com.babylonhx.postprocess.StereoscopicInterlacePostProcess;
import com.babylonhx.postprocess.VRDistortionCorrectionPostProcess;
import com.babylonhx.postprocess.PassPostProcess;
import com.babylonhx.materials.Effect;
import com.babylonhx.animations.IAnimatable;
import com.babylonhx.animations.Animation;

/**
* ...
* @author Krtolica Vujadin
*/

@:expose('BABYLON.Camera') class Camera extends Node implements IAnimatable {
	
	// Statics
	public static inline var PERSPECTIVE_CAMERA:Int = 0;
	public static inline var ORTHOGRAPHIC_CAMERA:Int = 1;
	
	public static inline var FOVMODE_VERTICAL_FIXED:Int = 0;
	public static inline var FOVMODE_HORIZONTAL_FIXED:Int = 1;
	
	public static inline var RIG_MODE_NONE:Int = 0;
	public static inline var RIG_MODE_STEREOSCOPIC_ANAGLYPH:Int = 10;
	public static inline var RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_PARALLEL:Int = 11;
	public static inline var RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_CROSSEYED:Int = 12;
	public static inline var RIG_MODE_STEREOSCOPIC_OVERUNDER:Int = 13;
	public static inline var RIG_MODE_VR:Int = 20;
	public static inline var _RIG_MODE_WEBVR:Int = 21;

	// Members
	@serializeAsVector3()
	public var position:Vector3 = Vector3.Zero();
	
	@serializeAsVector3()
	public var upVector:Vector3 = Vector3.Up();
	
	@serialize()
	public var orthoLeft:Null<Float> = null;
	
	@serialize()
    public var orthoRight:Null<Float> = null;
	
	@serialize()
    public var orthoBottom:Null<Float> = null;
	
	@serialize()
    public var orthoTop:Null<Float> = null;
	
	@serialize()
	public var fov:Float = 0.8;
	
	@serialize()
	public var minZ:Float = 1.0;
	
	@serialize()
	public var maxZ:Float = 10000.0;
	
	@serialize()
	public var inertia:Float = 0.9;
	
	@serialize()
	public var mode:Int = Camera.PERSPECTIVE_CAMERA;
	
	public var isIntermediate:Bool = false;
	
	public var viewport:Viewport = new Viewport(0, 0, 1, 1);
	
	public var subCameras:Array<Camera> = [];
	
	@serialize()
	public var layerMask:Int = 0xFFFFFFFF;
	
	@serialize()
	public var fovMode:Int = Camera.FOVMODE_VERTICAL_FIXED;
	
	// Camera rig members
	@serialize()
	public var cameraRigMode:Int = Camera.RIG_MODE_NONE;
	
	@serialize()
	public var interaxialDistance:Float;
	
	@serialize()
	public var isStereoscopicSideBySide:Bool;
	
	public var _cameraRigParams:Dynamic;
	public var _rigCameras:Array<Camera> = [];
	public var _rigPostProcess:PostProcess;

	// Cache
	private var _computedViewMatrix:Matrix = Matrix.Identity();
	public var _projectionMatrix:Matrix = new Matrix();
	private var _doNotComputeProjectionMatrix:Bool = false;
	private var _worldMatrix:Matrix;
	public var _postProcesses:Array<PostProcess> = [];
	private var _transformMatrix:Matrix = Matrix.Zero();
	private var _webvrViewMatrix:Matrix = Matrix.Identity();
	
	public var _activeMeshes:SmartArray<AbstractMesh> = new SmartArray<AbstractMesh>(256);
	
	private var _globalPosition:Vector3 = Vector3.Zero();
	public var globalPosition(get, never):Vector3;
	private var _frustumPlanes:Array<Plane> = [];
	private var _refreshFrustumPlanes:Bool = true;
	
	// VK: do not delete these !!!
	public var _getViewMatrix:Void->Matrix;
	public var getProjectionMatrix:Null<Bool>->Matrix;
	
	public var __serializableMembers:Dynamic;
	
	
	#if purejs
	private var eventPrefix:String = "mouse";
	#end
	

	public function new(name:String, position:Vector3, scene:Scene) {
		super(name, scene);
		
		scene.addCamera(this);
		
		if (scene.activeCamera == null) {
			scene.activeCamera = this;
		}
		
		this.getProjectionMatrix = getProjectionMatrix_default;
		this._getViewMatrix = _getViewMatrix_default;
		
		#if purejs
		eventPrefix = com.babylonhx.tools.Tools.GetPointerPrefix();
		#end
		
		this.position = position;
	}
	
	private function get_globalPosition():Vector3 {
		return this._globalPosition;
	}
	
	public function getActiveMeshes():SmartArray<AbstractMesh> {
        return this._activeMeshes;
    }

    public function isActiveMesh(mesh:Mesh):Bool {
        return (this._activeMeshes.indexOf(mesh) != -1);
    }

	//Cache
	override public function _initCache() {
		super._initCache();
		
		this._cache.position = new Vector3(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		this._cache.upVector = new Vector3(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		
		this._cache.mode = null;
		this._cache.minZ = null;
		this._cache.maxZ = null;
		
		this._cache.fov = null;
		this._cache.fovMode = null;
		this._cache.aspectRatio = null;
		
		this._cache.orthoLeft = null;
		this._cache.orthoRight = null;
		this._cache.orthoBottom = null;
		this._cache.orthoTop = null;
		this._cache.renderWidth = null;
		this._cache.renderHeight = null;
	}

	override public function _updateCache(ignoreParentClass:Bool = false) {
		if (!ignoreParentClass) {
			super._updateCache();
		}
		
		var engine = this.getEngine();
		
		this._cache.position.copyFrom(this.position);
		this._cache.upVector.copyFrom(this.upVector);
		
		this._cache.mode = this.mode;
		this._cache.minZ = this.minZ;
		this._cache.maxZ = this.maxZ;
		
		this._cache.fov = this.fov;
		this._cache.fovMode = this.fovMode;
		this._cache.aspectRatio = engine.getAspectRatio(this);
		
		this._cache.orthoLeft = this.orthoLeft;
		this._cache.orthoRight = this.orthoRight;
		this._cache.orthoBottom = this.orthoBottom;
		this._cache.orthoTop = this.orthoTop;
		this._cache.renderWidth = engine.getRenderWidth();
		this._cache.renderHeight = engine.getRenderHeight();
	}

	public function _updateFromScene() {
		this.updateCache();
		this._update();
	}

	// Synchronized	
	override public function _isSynchronized():Bool {
		return this._isSynchronizedViewMatrix() && this._isSynchronizedProjectionMatrix();
	}

	public function _isSynchronizedViewMatrix():Bool {
		if (!super._isSynchronized()) {
			return false;
		}
			
		return this._cache.position.equals(this.position)
			&& this._cache.upVector.equals(this.upVector)
			&& this.isSynchronizedWithParent();
	}

	public function _isSynchronizedProjectionMatrix():Bool {
		var check:Bool = this._cache.mode == this.mode
			&& this._cache.minZ == this.minZ
			&& this._cache.maxZ == this.maxZ;
			
		if (!check) {
			return false;
		}
		
		var engine = this.getEngine();
		
		if (this.mode == Camera.PERSPECTIVE_CAMERA) {
			check = this._cache.fov == this.fov
			&& this._cache.fovMode == this.fovMode
			&& this._cache.aspectRatio == engine.getAspectRatio(this);
		}
		else {
			check = this._cache.orthoLeft == this.orthoLeft
			&& this._cache.orthoRight == this.orthoRight
			&& this._cache.orthoBottom == this.orthoBottom
			&& this._cache.orthoTop == this.orthoTop
			&& this._cache.renderWidth == engine.getRenderWidth()
			&& this._cache.renderHeight == engine.getRenderHeight();
		}
		
		return check;
	}

	// Controls
	public function attachControl(?element:Dynamic, noPreventDefault:Bool = false, useCtrlForPanning:Bool = true, enableKeyboard:Bool = true) {
		
	}

	public function detachControl(?element:Dynamic) {
		
	}

	public function _update() {
		if (this.cameraRigMode != Camera.RIG_MODE_NONE) {
			this._updateRigCameras();
		}
		this._checkInputs();
	}
	
	public function _checkInputs() {
    
	}
	
	private function _cascadePostProcessesToRigCams() {
		// invalidate framebuffer
		if (this._postProcesses.length > 0){
			this._postProcesses[0].markTextureDirty();
		}
		
		// glue the rigPostProcess to the end of the user postprocesses & assign to each sub-camera
		for (i in 0...this._rigCameras.length) {
			var cam = this._rigCameras[i];
			var rigPostProcess = cam._rigPostProcess;
			
			// for VR rig, there does not have to be a post process 
			if (rigPostProcess != null) {
				var isPass = Std.is(rigPostProcess, PassPostProcess);
				if (isPass) {
					// any rig which has a PassPostProcess for rig[0], cannot be isIntermediate when there are also user postProcesses
					cam.isIntermediate = this._postProcesses.length == 0;
				}   
				
				cam._postProcesses = this._postProcesses.slice(0).concat([rigPostProcess]);
				rigPostProcess.markTextureDirty();
			}
		}
	}

	public function attachPostProcess(postProcess:PostProcess, ?insertAt:Int):Int {
		if (!postProcess.isReusable() && this._postProcesses.indexOf(postProcess) > -1) {
			trace("You're trying to reuse a post process not defined as reusable.");
			return 0;
		}
		
		if (insertAt == null || insertAt < 0) {
			this._postProcesses.push(postProcess);
			
		}
		else {
			this._postProcesses.insert(insertAt, postProcess);
		}
		this._cascadePostProcessesToRigCams(); // also ensures framebuffer invalidated   
		
		return this._postProcesses.indexOf(postProcess);
	}

	public function detachPostProcess(postProcess:PostProcess, atIndices:Dynamic = null):Array<Int> {
		var result:Array<Int> = [];
		
		if (atIndices == null) {
			var idx = this._postProcesses.indexOf(postProcess);
			if (idx != -1){
				this._postProcesses.splice(idx, 1);
			}
		} 
		else {
			atIndices = Std.is(atIndices, Array) ? atIndices : [atIndices];
			// iterate descending, so can just splice as we go
			var i:Int = cast atIndices.length - 1;
			while (i >= 0) {
				if (this._postProcesses[atIndices[i]] != postProcess) {
					result.push(i);
					continue;
				}
				this._postProcesses.splice(i, 1);
				
				--i;
			}
		}
		this._cascadePostProcessesToRigCams(); // also ensures framebuffer invalidated
		
		return result;
	}

	override public function getWorldMatrix():Matrix {
		if (this._worldMatrix == null) {
			this._worldMatrix = Matrix.Identity();
		}
		
		var viewMatrix = this.getViewMatrix();
		
		viewMatrix.invertToRef(this._worldMatrix);
		
		return this._worldMatrix;
	}

	public function _getViewMatrix_default():Matrix {
		return Matrix.Identity();
	}

	public function getViewMatrix(force:Bool = false):Matrix {
		this._computedViewMatrix = this._computeViewMatrix(force);
		
		if (!force && this._isSynchronizedViewMatrix()) {
			return this._computedViewMatrix;
		}
		
		if (this.parent == null || this.parent.getWorldMatrix() == null) {
			this._globalPosition.copyFrom(this.position);
		} 
		else {
			if (this._worldMatrix == null) {
				this._worldMatrix = Matrix.Identity();
			}
			
			this._computedViewMatrix.invertToRef(this._worldMatrix);
			
			this._worldMatrix.multiplyToRef(this.parent.getWorldMatrix(), this._computedViewMatrix);
			this._globalPosition.copyFromFloats(this._computedViewMatrix.m[12], this._computedViewMatrix.m[13], this._computedViewMatrix.m[14]);
			
			this._computedViewMatrix.invert();
			
			this._markSyncedWithParent();
		}
		
		this._currentRenderId = this.getScene().getRenderId();
		
		return this._computedViewMatrix;
	}

	public function _computeViewMatrix(force:Bool = false):Matrix {
		if (!force && this._isSynchronizedViewMatrix()) {
			return this._computedViewMatrix;
		}
		
		this._computedViewMatrix = this._getViewMatrix();		
		this._currentRenderId = this.getScene().getRenderId();
		
		return this._computedViewMatrix;
	}

	public function getProjectionMatrix_default(force:Bool = false):Matrix {
		if (this._doNotComputeProjectionMatrix || (!force && this._isSynchronizedProjectionMatrix())) {
			return this._projectionMatrix;
		}
		
		this._refreshFrustumPlanes = true;
		
		var engine = this.getEngine();
		var scene = this.getScene();
		if (this.mode == Camera.PERSPECTIVE_CAMERA) {
			if (this.minZ <= 0) {
				this.minZ = 0.1;
			}
			
			if (scene.useRightHandedSystem) {
				Matrix.PerspectiveFovRHToRef(this.fov,
					engine.getAspectRatio(this),
					this.minZ,
					this.maxZ,
					this._projectionMatrix,
					this.fovMode == Camera.FOVMODE_VERTICAL_FIXED);
			} 
			else {
				Matrix.PerspectiveFovLHToRef(this.fov,
					engine.getAspectRatio(this),
					this.minZ,
					this.maxZ,
					this._projectionMatrix,
					this.fovMode == Camera.FOVMODE_VERTICAL_FIXED);
			}
			
			return this._projectionMatrix;
		}
		
		var halfWidth = engine.getRenderWidth() / 2.0;
		var halfHeight = engine.getRenderHeight() / 2.0;
		if (scene.useRightHandedSystem) {
			Matrix.OrthoOffCenterRHToRef(this.orthoLeft != null ? this.orthoLeft : -halfWidth,
				this.orthoRight != null ? this.orthoRight : halfWidth,
				this.orthoBottom != null ? this.orthoBottom : -halfHeight,
				this.orthoTop != null ? this.orthoTop : halfHeight,
				this.minZ,
				this.maxZ,
				this._projectionMatrix);
		} 
		else {
			Matrix.OrthoOffCenterLHToRef(this.orthoLeft != null ? this.orthoLeft : -halfWidth,
				this.orthoRight != null ? this.orthoRight : halfWidth,
				this.orthoBottom != null ? this.orthoBottom : -halfHeight,
				this.orthoTop != null ? this.orthoTop : halfHeight,
				this.minZ,
				this.maxZ,
				this._projectionMatrix);
		}
		
		return this._projectionMatrix;
	}
	
	override public function dispose(doNotRecurse:Bool = false) {
		// Animations
        this.getScene().stopAnimation(this);
		
		// Remove from scene
		this.getScene().removeCamera(this);
		while (this._rigCameras.length > 0) {
			this._rigCameras.pop().dispose();
		}
		
		// Postprocesses
		var i = this._postProcesses.length;
		while (--i >= 0) {
			this._postProcesses[i].dispose(this);
		}
		
		super.dispose();
	}
	
	// ---- Camera rigs section ----
	public function setCameraRigMode(mode:Int, ?rigParams:Dynamic) {
		while (this._rigCameras.length > 0) {
			this._rigCameras.pop().dispose();
		}
		
		if (rigParams == null) {
			rigParams = { };
		}
		
		this.cameraRigMode = mode;
		this._cameraRigParams = { };
		
		//we have to implement stereo camera calcultating left and right viewpoints from interaxialDistance and target, 
		//not from a given angle as it is now, but until that complete code rewriting provisional stereoHalfAngle value is introduced
		this._cameraRigParams.interaxialDistance = rigParams.interaxialDistance != null ? rigParams.interaxialDistance : 0.0637;
		this._cameraRigParams.stereoHalfAngle = Tools.ToRadians(this._cameraRigParams.interaxialDistance / 0.0637);
		
		// create the rig cameras, unless none
		if (this.cameraRigMode != Camera.RIG_MODE_NONE){
			this._rigCameras.push(this.createRigCamera(this.name + "_L", 0));
			this._rigCameras.push(this.createRigCamera(this.name + "_R", 1));
		}
		
		switch (this.cameraRigMode) {
			case Camera.RIG_MODE_STEREOSCOPIC_ANAGLYPH:
				this._rigCameras[0]._rigPostProcess = new PassPostProcess(this.name + "_passthru", 1.0, this._rigCameras[0]);
				this._rigCameras[1]._rigPostProcess = new AnaglyphPostProcess(this.name + "_anaglyph", 1.0, this._rigCameras);
				
			case Camera.RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_PARALLEL,
				 Camera.RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_CROSSEYED,
				 Camera.RIG_MODE_STEREOSCOPIC_OVERUNDER:
				var isStereoscopicHoriz = this.cameraRigMode == Camera.RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_PARALLEL || this.cameraRigMode == Camera.RIG_MODE_STEREOSCOPIC_SIDEBYSIDE_CROSSEYED;
				
				this._rigCameras[0]._rigPostProcess = new PassPostProcess(this.name + "_passthru", 1.0, this._rigCameras[0]);
				this._rigCameras[1]._rigPostProcess = new StereoscopicInterlacePostProcess(this.name + "_stereoInterlace", this._rigCameras, isStereoscopicHoriz);
				
			case Camera.RIG_MODE_VR:
				var metrics = rigParams.vrCameraMetrics != null ? rigParams.vrCameraMetrics : VRCameraMetrics.GetDefault();
				
				this._rigCameras[0]._cameraRigParams.vrMetrics = metrics;
				this._rigCameras[0].viewport = new Viewport(0, 0, 0.5, 1.0);
				this._rigCameras[0]._cameraRigParams.vrWorkMatrix = new Matrix();
				this._rigCameras[0]._cameraRigParams.vrHMatrix = metrics.leftHMatrix;
				this._rigCameras[0]._cameraRigParams.vrPreViewMatrix = metrics.leftPreViewMatrix;
				this._rigCameras[0].getProjectionMatrix = this._rigCameras[0]._getVRProjectionMatrix;
				
				this._rigCameras[1]._cameraRigParams.vrMetrics = metrics;
				this._rigCameras[1].viewport = new Viewport(0.5, 0, 0.5, 1.0);
				this._rigCameras[1]._cameraRigParams.vrWorkMatrix = new Matrix();
				this._rigCameras[1]._cameraRigParams.vrHMatrix = metrics.rightHMatrix;
				this._rigCameras[1]._cameraRigParams.vrPreViewMatrix = metrics.rightPreViewMatrix;
				this._rigCameras[1].getProjectionMatrix = this._rigCameras[1]._getVRProjectionMatrix;
				
				if (metrics.compensateDistortion) {
					this._rigCameras[0]._rigPostProcess = new VRDistortionCorrectionPostProcess("VR_Distort_Compensation_Left", this._rigCameras[0], false, metrics);
					this._rigCameras[1]._rigPostProcess = new VRDistortionCorrectionPostProcess("VR_Distort_Compensation_Right", this._rigCameras[1], true, metrics);
				}
		}
		
		this._cascadePostProcessesToRigCams(); 
		this._update();
	}

	private function _getVRProjectionMatrix(force:Bool = false):Matrix {
		Matrix.PerspectiveFovLHToRef(this._cameraRigParams.vrMetrics.aspectRatioFov(), this._cameraRigParams.vrMetrics.aspectRatio(), this.minZ, this.maxZ, this._cameraRigParams.vrWorkMatrix);

		cast(this._cameraRigParams.vrWorkMatrix, Matrix).multiplyToRef(this._cameraRigParams.vrHMatrix, this._projectionMatrix);
		return this._projectionMatrix;
	}

	public function setCameraRigParameter(name:String, value:Dynamic) {
		if (this._cameraRigParams == null) {
            this._cameraRigParams = { }; 
        }
		
		Reflect.setProperty(this._cameraRigParams, name, value);
		//provisionnally:
		if (name == "interaxialDistance") {
			this._cameraRigParams.stereoHalfAngle = Tools.ToRadians(value / 0.0637);
		}
	}
	
	/**
	 * Maybe needs to be overridden by children so sub has required properties to be copied
	 */
	public function createRigCamera(name:String, cameraIndex:Int):Camera {
		return null;
	}
	
	/**
	 * Maybe needs to be overridden by children
	 */
	public function _updateRigCameras() {
		for (i in 0...this._rigCameras.length) {
			this._rigCameras[i].minZ = this.minZ;
			this._rigCameras[i].maxZ = this.maxZ;
			this._rigCameras[i].fov = this.fov;
		}
		
		// only update viewport when ANAGLYPH
		if (this.cameraRigMode == Camera.RIG_MODE_STEREOSCOPIC_ANAGLYPH) {
			this._rigCameras[0].viewport = this._rigCameras[1].viewport = this.viewport;
		}
	}
	
	public function getDirection(localAxis:Vector3):Vector3 {
		var result = Vector3.Zero();
		
		this.getDirectionToRef(localAxis, result);
		
		return result;
	}
	
	public function getDirectionToRef(localAxis:Vector3, result:Vector3) {
		Vector3.TransformNormalToRef(localAxis, this.getWorldMatrix(), result);
	}
	
	public function serialize():Dynamic {
		var serializationObject:Dynamic = { };
		serializationObject.name = this.name;
		serializationObject.tags = Tags.GetTags(this);
		serializationObject.id = this.id;
		serializationObject.position = this.position.asArray();
		
		// VK TODO
		//serializationObject.type = Tools.GetConstructorName(this);
		
		// Parent
		if (this.parent != null) {
			serializationObject.parentId = this.parent.id;
		}
		
		serializationObject.fov = this.fov;
		serializationObject.minZ = this.minZ;
		serializationObject.maxZ = this.maxZ;
		
		serializationObject.inertia = this.inertia;
		
		// Animations
		Animation.AppendSerializedAnimations(this, serializationObject);
		serializationObject.ranges = this.serializeAnimationRanges();
		
		// Layer mask
		serializationObject.layerMask = this.layerMask;
		
		return serializationObject;
	}
	
	public static function Parse(parsedCamera:Dynamic, scene:Scene):Camera {
		var camera:Camera = null;
		var position = Vector3.FromArray(parsedCamera.position);
		var lockedTargetMesh:Mesh = parsedCamera.lockedTargetId != null ? cast scene.getLastMeshByID(parsedCamera.lockedTargetId) : null;
		var interaxial_distance:Float = 0;
		
		if (parsedCamera.type == "AnaglyphArcRotateCamera" || parsedCamera.type == "ArcRotateCamera") {
			var alpha = parsedCamera.alpha;
			var beta = parsedCamera.beta;
			var radius = parsedCamera.radius;
			if (parsedCamera.type == "AnaglyphArcRotateCamera") {
				interaxial_distance = parsedCamera.interaxial_distance;
				camera = new AnaglyphArcRotateCamera(parsedCamera.name, alpha, beta, radius, lockedTargetMesh, interaxial_distance, scene);
			} 
			else {
				camera = new ArcRotateCamera(parsedCamera.name, alpha, beta, radius, lockedTargetMesh, scene);
			}
		} 
		else if (parsedCamera.type == "AnaglyphFreeCamera") {
			interaxial_distance = parsedCamera.interaxial_distance;
			camera = new AnaglyphFreeCamera(parsedCamera.name, position, interaxial_distance, scene);
		} 
		else if (parsedCamera.type == "DeviceOrientationCamera") {
			//camera = new DeviceOrientationCamera(parsedCamera.name, position, scene);
		} 
		else if (parsedCamera.type == "FollowCamera") {
			camera = new FollowCamera(parsedCamera.name, position, scene);
			untyped camera.heightOffset = parsedCamera.heightOffset;
			untyped camera.radius = parsedCamera.radius;
			untyped camera.rotationOffset = parsedCamera.rotationOffset;
			if (lockedTargetMesh != null) {
				cast(camera, FollowCamera).target = lockedTargetMesh;
			}
		} 
		else if (parsedCamera.type == "GamepadCamera") {
			//camera = new GamepadCamera(parsedCamera.name, position, scene);
		} 
		else if (parsedCamera.type == "TouchCamera") {
			camera = new TouchCamera(parsedCamera.name, position, scene);
		} 
		else if (parsedCamera.type == "VirtualJoysticksCamera") {
			//camera = new VirtualJoysticksCamera(parsedCamera.name, position, scene);
		} 
		else if (parsedCamera.type == "WebVRFreeCamera") {
			camera = new WebVRFreeCamera(parsedCamera.name, position, scene);
		} 
		else if (parsedCamera.type == "VRDeviceOrientationFreeCamera") {
			camera = new VRDeviceOrientationFreeCamera(parsedCamera.name, position, scene);
		} 
		else {
			// Free Camera is the default value
			camera = new FreeCamera(parsedCamera.name, position, scene);
		}
		
		// apply 3d rig, when found
		if (parsedCamera.cameraRigMode != null) {
			var rigParams = parsedCamera.interaxial_distance != null ? { interaxialDistance: parsedCamera.interaxial_distance } : { };
			camera.setCameraRigMode(parsedCamera.cameraRigMode, rigParams);
		}
		
		// Test for lockedTargetMesh & FreeCamera outside of if-else-if nest, since things like GamepadCamera extend FreeCamera
		if (lockedTargetMesh != null && Std.is(camera, FreeCamera)) {
			cast(camera, FreeCamera).lockedTarget = lockedTargetMesh;
		}
		
		camera.id = parsedCamera.id;
		
		Tags.AddTagsTo(camera, parsedCamera.tags);
		
		// Parent
		if (parsedCamera.parentId != null) {
			camera._waitingParentId = parsedCamera.parentId;
		}
		
		// Target
		if (parsedCamera.target) {
			if (Reflect.hasField(camera, "setTarget")) {
				untyped camera.setTarget(Vector3.FromArray(parsedCamera.target));
			} 
			else {
				//For ArcRotate
				untyped camera.target = Vector3.FromArray(parsedCamera.target);
			}
		} 
		else {
			untyped camera.rotation = Vector3.FromArray(parsedCamera.rotation);
		}
		
		camera.fov = parsedCamera.fov;
		camera.minZ = parsedCamera.minZ;
		camera.maxZ = parsedCamera.maxZ;
		
		untyped camera.speed = parsedCamera.speed;
		camera.inertia = parsedCamera.inertia;
		
		untyped camera.checkCollisions = parsedCamera.checkCollisions;
		untyped camera.applyGravity = parsedCamera.applyGravity;
		if (parsedCamera.ellipsoid != null) {
			untyped camera.ellipsoid = Vector3.FromArray(parsedCamera.ellipsoid);
		}
		
		// Animations
		if (parsedCamera.animations != null) {
			for (animationIndex in 0...parsedCamera.animations.length) {
				var parsedAnimation = parsedCamera.animations[animationIndex];
				
				camera.animations.push(Animation.Parse(parsedAnimation));
			}
			
            Node.ParseAnimationRanges(camera, parsedCamera, scene);
		}

		if (parsedCamera.autoAnimate == true) {
			scene.beginAnimation(camera, parsedCamera.autoAnimateFrom, parsedCamera.autoAnimateTo, parsedCamera.autoAnimateLoop, 1.0);
		}
		
		// Layer Mask
		if (parsedCamera.layerMask != null && (!Math.isNaN(parsedCamera.layerMask))) {
			untyped camera.layerMask = Math.abs(Std.parseInt(parsedCamera.layerMask));
		} 
		else {
			camera.layerMask = 0x0FFFFFFF;
		}
		
		return camera;
	 }
	
	/*public function screenToWorld(x:Int, y:Int, depth:Float, position:Vector3) {
		this.plane.position.z = depth;
		var name = this.plane.name;
		var info = this.getScene().pick(x, y, function (mesh:Mesh) {
			return (mesh.name == name);
		}, true, this);
		position.copyFrom(info.hit ? info.pickedPoint : position);
	}*/
	
}
