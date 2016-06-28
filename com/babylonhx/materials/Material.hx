package com.babylonhx.materials;

import com.babylonhx.ISmartArrayCompatible;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.materials.textures.RenderTargetTexture;
import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.tools.SmartArray;
import com.babylonhx.tools.Tags;
import com.babylonhx.math.Matrix;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.tools.Observable;
import com.babylonhx.tools.Observer;
import com.babylonhx.tools.EventState;
import com.babylonhx.tools.serialization.SerializationHelper;


/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.Material') class Material implements ISmartArrayCompatible {
	
	public static inline var TriangleFillMode:Int = 0;
	public static inline var WireFrameFillMode:Int = 1;
	public static inline var PointFillMode:Int = 2;
	
	public static inline var ClockWiseSideOrientation:Int = 0;
	public static inline var CounterClockWiseSideOrientation:Int = 1;
	
	@serialize()
	public var id:String;
	
	@serialize()
	public var name:String;
	
	@serialize()
	public var checkReadyOnEveryCall:Bool = false;
	
	@serialize()
	public var checkReadyOnlyOnce:Bool = false;
	
	@serialize()
	public var state:String = "";
	
	@serialize()
	public var alpha:Float = 1.0;
	
	@serialize()
	public var backFaceCulling:Bool = true;
	
	@serialize()
	public var sideOrientation:Int = Material.CounterClockWiseSideOrientation;
	
	public var onCompiled:Effect->Void;
	public var onError:Effect->String->Void;
	public var getRenderTargetTextures:Void->SmartArray<RenderTargetTexture>;
	
	/**
	* An event triggered when the material is disposed.
	* @type {BABYLON.Observable}
	*/
	public var onDisposeObservable:Observable<Material> = new Observable<Material>();
	private var _onDisposeObserver:Observer<Material>;
	public var onDispose(never, set):Material->Null<EventState>->Void;
	private function set_onDispose(callback:Material->Null<EventState>->Void):Material->Null<EventState>->Void {
		if (this._onDisposeObserver != null) {
			this.onDisposeObservable.remove(this._onDisposeObserver);
		}
		this._onDisposeObserver = this.onDisposeObservable.add(callback);
		
		return callback;
	}

	/**
	* An event triggered when the material is compiled.
	* @type {BABYLON.Observable}
	*/
	public var onBindObservable:Observable<AbstractMesh> = new Observable<AbstractMesh>();
	private var _onBindObserver:Observer<AbstractMesh>;
	public var onBind(never, set):AbstractMesh->Null<EventState>->Void;
	private function set_onBind(callback:AbstractMesh->Null<EventState>->Void):AbstractMesh->Null<EventState>->Void {
		if (this._onBindObserver != null) {
			this.onBindObservable.remove(this._onBindObserver);
		}
		this._onBindObserver = this.onBindObservable.add(callback);
		
		return callback;
	}
	
	@serialize()
	public var alphaMode:Int = Engine.ALPHA_COMBINE;
	
	@serialize()
	public var disableDepthWrite:Bool = false;
	
	@serialize()
	public var fogEnabled:Bool = true;

	@serialize()
	public var pointSize:Float = 1.0;
	
	@serialize()
	public var zOffset:Float = 0.0;

	@serialize()
	public var wireframe(get, set):Bool;
	private function get_wireframe():Bool {
		return this._fillMode == Material.WireFrameFillMode;
	}
	private function set_wireframe(value:Bool):Bool {
		this._fillMode = (value ? Material.WireFrameFillMode : Material.TriangleFillMode);
		return value;
	}
	
	@serialize()
	public var pointsCloud(get, set):Bool;
	private function get_pointsCloud():Bool {
		return this._fillMode == Material.PointFillMode;
	}
	private function set_pointsCloud(value:Bool):Bool {
		this._fillMode = (value ? Material.PointFillMode : Material.TriangleFillMode);
		return value;
	}

	@serialize()
	public var fillMode(get, set):Int;
	private function get_fillMode():Int {
		return this._fillMode;
	}
	private function set_fillMode(value:Int):Int {
		this._fillMode = value;
		return value;
	}
	
	public var isFrozen(get, never):Bool;

	public var _effect:Effect;
	public var _wasPreviouslyReady:Bool = false;
	private var _scene:Scene;
	private var _fillMode:Int = Material.TriangleFillMode;
	private var _cachedDepthWriteState:Bool;
	
	public var __smartArrayFlags:Array<Int> = [];
	
	public var __serializableMembers:Dynamic;
	

	public function new(name:String, scene:Scene, doNotAdd:Bool = false) {
		this.id = name;
		this.name = name;
		
		this._scene = scene;
		
		if (!doNotAdd) {
			scene.materials.push(this);
		}
		
		// TODO: macro ...
		#if purejs
		untyped __js__("Object.defineProperty(this, 'wireframe', { get: this.get_wireframe, set: this.set_wireframe })");
		untyped __js__("Object.defineProperty(this, 'fillMode', { get: this.get_fillMode, set: this.set_fillMode })");
		untyped __js__("Object.defineProperty(this, 'pointsCloud', { get: this.get_pointsCloud, set: this.set_pointsCloud })");
		#end
	}
	
	private function get_isFrozen():Bool {
		return this.checkReadyOnlyOnce;
	}
	
	public function freeze() {
		this.checkReadyOnlyOnce = true;
	}
	
	public function unfreeze() {
		this.checkReadyOnlyOnce = false;
	}

	public function isReady(?mesh:AbstractMesh, useInstances:Bool = false):Bool {
		return true;
	}

	public function getEffect():Effect {
		return this._effect;
	}

	public function getScene():Scene {
		return this._scene;
	}

	public function needAlphaBlending():Bool {
		return (this.alpha < 1.0);
	}

	public function needAlphaTesting():Bool {
		return false;
	}

	public function getAlphaTestTexture():BaseTexture {
		return null;
	}
	
	public function markDirty() {
		this._wasPreviouslyReady = false;
	}

	public function _preBind():Void {
		var engine = this._scene.getEngine();
		
		engine.enableEffect(this._effect);
		engine.setState(this.backFaceCulling, this.zOffset, false, this.sideOrientation == Material.ClockWiseSideOrientation);
	}

	public function bind(world:Matrix, ?mesh:Mesh) {		
		this._scene._cachedMaterial = this;		
        this.onBindObservable.notifyObservers(mesh);
		
		if (this.disableDepthWrite) {
            var engine = this._scene.getEngine();
            this._cachedDepthWriteState = engine.getDepthWrite();
            engine.setDepthWrite(false);
        }
	}

	public function bindOnlyWorldMatrix(world:Matrix) { }

	public function unbind():Void {
		if (this.disableDepthWrite) {
            var engine = this._scene.getEngine();
            engine.setDepthWrite(this._cachedDepthWriteState);
        }
	}
	
	public function clone(name:String, cloneChildren:Bool = false):Material {
		return null;
	}
	
	public function getBindedMeshes():Array<AbstractMesh> {
		var result = new Array<AbstractMesh>();
		
		for (index in 0...this._scene.meshes.length) {
			var mesh = this._scene.meshes[index];
			
			if (mesh.material == this) {
				result.push(mesh);
			}
		}
		
		return result;
	}

	public function dispose(forceDisposeEffect:Bool = false, forceDisposeTextures:Bool = true) {	
		// Animations
        this.getScene().stopAnimation(this);
		
		// Remove from scene
		var index = this._scene.materials.indexOf(this);
		if (index >= 0) {
			this._scene.materials.splice(index, 1);
		}
		
		// Shader are kept in cache for further use but we can get rid of this by using forceDisposeEffect
		if (forceDisposeEffect && this._effect != null) {
			this._scene.getEngine()._releaseEffect(this._effect);
			this._effect = null;
		}
		
		// Remove from meshes
		for (index in 0...this._scene.meshes.length) {
			var mesh = this._scene.meshes[index];
			
			if (mesh.material == this) {
				mesh.material = null;
			}
		}
		
		// Callback
		this.onDisposeObservable.notifyObservers(this);
		
		this.onDisposeObservable.clear();
        this.onBindObservable.clear();
	}
	
	public function copyTo(other:Material) {
		other.checkReadyOnlyOnce = this.checkReadyOnlyOnce;
		other.checkReadyOnEveryCall = this.checkReadyOnEveryCall;
		other.alpha = this.alpha;
		other.fillMode = this.fillMode;
		other.backFaceCulling = this.backFaceCulling;
		other.wireframe = this.wireframe;
		other.fogEnabled = this.fogEnabled;
		other.wireframe = this.wireframe;
		other.zOffset = this.zOffset;
		other.alphaMode = this.alphaMode;
		other.sideOrientation = this.sideOrientation;
		other.disableDepthWrite = this.disableDepthWrite;
		other.pointSize = this.pointSize;
		other.pointsCloud = this.pointsCloud;
	}
	
	public function serialize():Dynamic {
		return SerializationHelper.Serialize(Material, this);
	}
	
	public static function ParseMultiMaterial(parsedMultiMaterial:Dynamic, scene:Scene):MultiMaterial {
		var multiMaterial = new MultiMaterial(parsedMultiMaterial.name, scene);
		
		multiMaterial.id = parsedMultiMaterial.id;
		
		Tags.AddTagsTo(multiMaterial, parsedMultiMaterial.tags);
		
		for (matIndex in 0...parsedMultiMaterial.materials.length) {
			var subMatId = parsedMultiMaterial.materials[matIndex];
			
			if (subMatId != null) {
				multiMaterial.subMaterials.push(scene.getMaterialByID(subMatId));
			} 
			else {
				multiMaterial.subMaterials.push(null);
			}
		}
		
		return multiMaterial;
	}

	public static function Parse(parsedMaterial:Dynamic, scene:Scene, rootUrl:String):Material {
		if (parsedMaterial.customType == null) {
			return StandardMaterial.Parse(parsedMaterial, scene, rootUrl);
		}
		
		var materialType = Type.resolveClass(parsedMaterial.customType);
		
		if (materialType != null) {
			return Type.createEmptyInstance(materialType).Parse(parsedMaterial, scene, rootUrl);
		}
		
		return null;
	}
	
}
