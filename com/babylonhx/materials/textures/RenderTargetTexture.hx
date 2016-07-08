package com.babylonhx.materials.textures;

import com.babylonhx.Engine;
import com.babylonhx.rendering.RenderingManager;
import com.babylonhx.cameras.Camera;
import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.mesh.SubMesh;
import com.babylonhx.tools.SmartArray;
import com.babylonhx.math.Matrix;
import com.babylonhx.tools.Observable;
import com.babylonhx.tools.Observer;
import com.babylonhx.tools.EventState;

/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.RenderTargetTexture') class RenderTargetTexture extends Texture {
	
	public static inline var REFRESHRATE_RENDER_ONCE:Int = 0;
    public static inline var REFRESHRATE_RENDER_ONEVERYFRAME:Int = 1;
    public static inline var REFRESHRATE_RENDER_ONEVERYTWOFRAMES:Int = 2;
	
	/**
	* Use this predicate to dynamically define the list of mesh you want to render.
	* If set, the renderList property will be overwritten.
	*/
	public var renderListPredicate:AbstractMesh->Bool;

	/**
	* Use this list to define the list of mesh you want to render.
	*/	
	public var renderList:Array<AbstractMesh> = [];
	public var renderParticles:Bool = true;
	public var renderSprites:Bool = false;
	public var activeCamera:Camera;
	public var customRenderFunction:Dynamic;//SmartArray<SubMesh>->SmartArray<SubMesh>->SmartArray<SubMesh>->Void->Void->Void;
	public var useCameraPostProcesses:Bool;
	
	// Events

	/**
	* An event triggered when the texture is unbind.
	* @type {BABYLON.Observable}
	*/
	public var onAfterUnbindObservable:Observable<RenderTargetTexture> = new Observable<RenderTargetTexture>();
	private var _onAfterUnbindObserver:Observer<RenderTargetTexture>;
	public var onAfterUnbind(never, set):RenderTargetTexture->Null<EventState>->Void;
	private  function set_onAfterUnbind(callback:RenderTargetTexture->Null<EventState>->Void):RenderTargetTexture->Null<EventState>->Void {
		if (this._onAfterUnbindObserver != null) {
			this.onAfterUnbindObservable.remove(this._onAfterUnbindObserver);
		}
		this._onAfterUnbindObserver = this.onAfterUnbindObservable.add(callback);
		
		return callback;
	}

	/**
	* An event triggered before rendering the texture
	* @type {BABYLON.Observable}
	*/
	public var onBeforeRenderObservable:Observable<Int> = new Observable<Int>();
	private var _onBeforeRenderObserver:Observer<Int>;
	public var onBeforeRender(never, set):Int->Null<EventState>->Void;
	private function set_onBeforeRender(callback:Int->Null<EventState>->Void):Int->Null<EventState>->Void {
		if (this._onBeforeRenderObserver != null) {
			this.onBeforeRenderObservable.remove(this._onBeforeRenderObserver);
		}
		this._onBeforeRenderObserver = this.onBeforeRenderObservable.add(callback);
		
		return callback;
	}

	/**
	* An event triggered after rendering the texture
	* @type {BABYLON.Observable}
	*/
	public var onAfterRenderObservable:Observable<Int> = new Observable<Int>();
	private var _onAfterRenderObserver:Observer<Int>;
	public var onAfterRender(never, set):Int->Null<EventState>->Void;
	private function set_onAfterRender(callback:Int->Null<EventState>->Void):Int->Null<EventState>->Void {
		if (this._onAfterRenderObserver != null) {
			this.onAfterRenderObservable.remove(this._onAfterRenderObserver);
		}
		this._onAfterRenderObserver = this.onAfterRenderObservable.add(callback);
		
		return callback;
	}

	/**
	* An event triggered after the texture clear
	* @type {BABYLON.Observable}
	*/
	public var onClearObservable:Observable<Engine> = new Observable<Engine>();
	private var _onClearObserver:Observer<Engine>;
	public var onClear(never, set):Engine->Null<EventState>->Void;
	private function set_onClear(callback:Engine->Null<EventState>->Void):Engine->Null<EventState>->Void {
		if (this._onClearObserver != null) {
			this.onClearObservable.remove(this._onClearObserver);
		}
		this._onClearObserver = this.onClearObservable.add(callback);
		
		return callback;
	}
	
	public var refreshRate(get, set):Int;
	public var canRescale(get, never):Bool;

	private var _size:Dynamic = { width: 0, height: 0 };
	public var _generateMipMaps:Bool;
	private var _renderingManager:RenderingManager;
	public var _waitingRenderList:Array<String>;
	private var _doNotChangeAspectRatio:Bool;
	private var _currentRefreshId:Int = -1;
	private var _refreshRate:Int = 1;
	private var _textureMatrix:Matrix;

	
	public function new(name:String, size:Dynamic, scene:Scene, ?generateMipMaps:Bool, doNotChangeAspectRatio:Bool = true, type:Int = Engine.TEXTURETYPE_UNSIGNED_INT, isCube:Bool = false, samplingMode:Int = Texture.TRILINEAR_SAMPLINGMODE) {
		super(null, scene, !generateMipMaps);
		
		this.coordinatesMode = Texture.PROJECTION_MODE;
		
		this.name = name;
		this.isRenderTarget = true;
		if (Std.is(size, Int)) {
			this._size.width = size;
			this._size.height = size;
		}
		else if (size.width != null) {
			this._size.width = size.width;
			this._size.height = size.height;
		}
		this._generateMipMaps = generateMipMaps;
		this._doNotChangeAspectRatio = doNotChangeAspectRatio;
		this.isCube = isCube;
		
		if (samplingMode == Texture.NEAREST_SAMPLINGMODE) {
            this.wrapU = Texture.CLAMP_ADDRESSMODE;
            this.wrapV = Texture.CLAMP_ADDRESSMODE;
        }
		
		if (isCube) {
			this._texture = scene.getEngine().createRenderTargetCubeTexture(this._size, { generateMipMaps: generateMipMaps, samplingMode: samplingMode } );
			this.coordinatesMode = Texture.INVCUBIC_MODE;
            this._textureMatrix = Matrix.Identity();
		}
		else {
			this._texture = scene.getEngine().createRenderTargetTexture(this._size, { generateMipMaps: generateMipMaps, type: type, samplingMode: samplingMode } );
		}
		
		// Rendering groups
		this._renderingManager = new RenderingManager(scene);
	}

	public function resetRefreshCounter() {
		this._currentRefreshId = -1;
	}

	private function get_refreshRate():Int {
		return this._refreshRate;
	}
	// Use 0 to render just once, 1 to render on every frame, 2 to render every two frames and so on...
	private function set_refreshRate(value:Int):Int {
		this._refreshRate = value;
		this.resetRefreshCounter();
		
		return value;
	}

	public function _shouldRender():Bool {
		if (this._currentRefreshId == -1) { // At least render once
			this._currentRefreshId = 1;
			return true;
		}
		
		if (this.refreshRate == this._currentRefreshId) {
			this._currentRefreshId = 1;
			return true;
		}
		
		this._currentRefreshId++;
		
		return false;
	}
	
	override public function isReady():Bool {
		if (!this.getScene().renderTargetsEnabled) {
			return false;
		}
		
		return super.isReady();
	}

	public function getRenderSize():Dynamic {
		return this._size;
	}

	private function get_canRescale():Bool {
		return true;
	}

	override public function scale(ratio:Float) {
		var newSize = { width: Std.int(this._size.width * ratio), height: Std.int(this._size.height * ratio) };
		this.resize(newSize, this._generateMipMaps);
	}
	
	override public function getReflectionTextureMatrix():Matrix {
        if (this.isCube) {
            return this._textureMatrix;
        }
		
        return super.getReflectionTextureMatrix();
    }

	public function resize(size:Dynamic, ?generateMipMaps:Bool) {
		this.releaseInternalTexture();
		if (this.isCube) {
			this._texture = this.getScene().getEngine().createRenderTargetCubeTexture(size);
		} 
		else {
			this._texture = this.getScene().getEngine().createRenderTargetTexture(size, generateMipMaps);
		}
	}

	public function render(useCameraPostProcess:Bool = false) {
		var scene = this.getScene();
		
		if (this.useCameraPostProcesses == false) {
            useCameraPostProcess = this.useCameraPostProcesses;
        }
		
		if (this.activeCamera != null && this.activeCamera != scene.activeCamera) {
    		scene.setTransformMatrix(this.activeCamera.getViewMatrix(), this.activeCamera.getProjectionMatrix(true));
    	}
		
		if (this._waitingRenderList != null) {
			this.renderList = [];
			for (index in 0...this._waitingRenderList.length) {
				var id = this._waitingRenderList[index];
				this.renderList.push(scene.getMeshByID(id));
			}
			
			this._waitingRenderList = null;
		}
		
		// Is predicate defined?
		if (this.renderListPredicate != null) {
			this.renderList.splice(0, this.renderList.length - 1); // Clear previous renderList
			
			var sceneMeshes = this.getScene().meshes;
			
			for (index in 0...sceneMeshes.length) {
				var mesh = sceneMeshes[index];
				if (this.renderListPredicate(mesh)) {
					this.renderList.push(mesh);
				}
			}
		}
		
		if (this.renderList != null && this.renderList.length == 0) {
			return;
		}
		
		// Prepare renderingManager
		this._renderingManager.reset();
		
		var currentRenderList = this.renderList != null ? this.renderList : scene.getActiveMeshes().data;
		var currentRenderListLength = cast this.renderList != null ? this.renderList.length : cast scene.getActiveMeshes().length;
		
		var sceneRenderId = scene.getRenderId();
		for (meshIndex in 0...currentRenderListLength) {
			var mesh = currentRenderList[meshIndex];
			
			if (mesh != null) {
				if (!mesh.isReady()) {
					// Reset _currentRefreshId
					this.resetRefreshCounter();
					continue;
				}
				
				mesh._preActivateForIntermediateRendering(sceneRenderId);
				
				if (mesh.isEnabled() && mesh.isVisible && mesh.subMeshes != null && ((mesh.layerMask & scene.activeCamera.layerMask) != 0)) {
					mesh._activate(sceneRenderId);
					
					for (subMesh in mesh.subMeshes) {
						scene._activeIndices += subMesh.indexCount;
						this._renderingManager.dispatch(subMesh);
					}
				}
			}
		}
		
		if (this.isCube) {
			for (face in 0...6) {
				this.renderToTarget(face, currentRenderList, currentRenderListLength, useCameraPostProcess);
				scene.incrementRenderId();
				scene.resetCachedMaterial();
			}
		} 
		else {
			this.renderToTarget(0, currentRenderList, currentRenderListLength, useCameraPostProcess);
		}
		
		this.onAfterUnbindObservable.notifyObservers(this);
		
		if (this.activeCamera != null && this.activeCamera != scene.activeCamera) {
    		scene.setTransformMatrix(scene.activeCamera.getViewMatrix(), scene.activeCamera.getProjectionMatrix(true));
    	}
		
		scene.resetCachedMaterial();
	}
	
	public function renderToTarget(faceIndex:Int, currentRenderList:Array<AbstractMesh>, currentRenderListLength:Int, useCameraPostProcess:Bool = false) {
		var scene = this.getScene();
		var engine = scene.getEngine();
		
		// Bind
		if (!useCameraPostProcess || !scene.postProcessManager._prepareFrame(this._texture)) {
			if (this.isCube) {
				engine.bindFramebuffer(this._texture, faceIndex);
			} 
			else {
				engine.bindFramebuffer(this._texture);
			}
		}
		
		this.onBeforeRenderObservable.notifyObservers(faceIndex);
		
		// Clear
		if (this.onClearObservable.hasObservers()) {
			this.onClearObservable.notifyObservers(engine);
		} 
		else {
			engine.clear(scene.clearColor, true, true);
		}
		
		if (!this._doNotChangeAspectRatio) {
			scene.updateTransformMatrix(true);
		}
		
		// Render
		this._renderingManager.render(this.customRenderFunction, currentRenderList, this.renderParticles, this.renderSprites);
		
		if (useCameraPostProcess) {
			scene.postProcessManager._finalizeFrame(false, this._texture, faceIndex);
		}
		
		if (!this._doNotChangeAspectRatio) {
			scene.updateTransformMatrix(true);
		}
		
		this.onAfterRenderObservable.notifyObservers(faceIndex);
		
		// Unbind
		if (!this.isCube || faceIndex == 5) {
			if (this.isCube) {
				if (faceIndex == 5) {
					engine.generateMipMapsForCubemap(this._texture);
				}
			}
			
			engine.unBindFramebuffer(this._texture, this.isCube);
		}
	}

	override public function clone():RenderTargetTexture {
		var textureSize = this.getSize();
		var newTexture = new RenderTargetTexture(this.name, textureSize.width, this.getScene(), this._generateMipMaps);
		
		// Base texture
		newTexture.hasAlpha = this.hasAlpha;
		newTexture.level = this.level;
		
		// RenderTarget Texture
		newTexture.coordinatesMode = this.coordinatesMode;
		newTexture.renderList = this.renderList.slice(0);
		
		return newTexture;
	}
	
	override public function serialize():Dynamic {
		if (this.name == null) {
			return null;
		}
		
		var serializationObject = super.serialize();
		
		serializationObject.renderTargetSize = this.getRenderSize();
		serializationObject.renderList = [];
		
		for (index in 0...this.renderList.length) {
			serializationObject.renderList.push(this.renderList[index].id);
		}
		
		return serializationObject;
	}
	
}
