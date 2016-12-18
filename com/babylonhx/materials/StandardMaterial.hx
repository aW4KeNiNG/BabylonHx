package com.babylonhx.materials;

import com.babylonhx.Engine;
import com.babylonhx.lights.shadows.ShadowGenerator;
import com.babylonhx.lights.IShadowLight;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.materials.textures.RefractionTexture;
import com.babylonhx.materials.textures.RenderTargetTexture;
import com.babylonhx.materials.textures.ColorGradingTexture;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Matrix;
import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.tools.SmartArray;
import com.babylonhx.lights.SpotLight;
import com.babylonhx.lights.DirectionalLight;
import com.babylonhx.lights.HemisphericLight;
import com.babylonhx.lights.PointLight;
import com.babylonhx.tools.Tools;
import com.babylonhx.tools.Tags;
import com.babylonhx.animations.IAnimatable;
import com.babylonhx.tools.serialization.SerializationHelper;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */

typedef SMD = StandardMaterialDefines

@:expose('BABYLON.StandardMaterial') class StandardMaterial extends Material {
	
	// Flags used to enable or disable a type of texture for all Standard Materials
	public static var DiffuseTextureEnabled:Bool = true;
	public static var AmbientTextureEnabled:Bool = true;
	public static var OpacityTextureEnabled:Bool = true;
	public static var ReflectionTextureEnabled:Bool = true;
	public static var EmissiveTextureEnabled:Bool = true;
	public static var SpecularTextureEnabled:Bool = true;
	public static var BumpTextureEnabled:Bool = true;
	public static var FresnelEnabled:Bool = true;
	public static var LightmapTextureEnabled:Bool = true;
	public static var RefractionTextureEnabled:Bool = true;
	public static var ColorGradingTextureEnabled:Bool = true;
	
	@serializeAsTexture()
	public var diffuseTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var ambientTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var opacityTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var reflectionTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var emissiveTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var specularTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var bumpTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var lightmapTexture:BaseTexture = null;
	
	@serializeAsTexture()
	public var refractionTexture:BaseTexture = null;

	@serializeAsColor3("ambient")
	public var ambientColor:Color3 = new Color3(0, 0, 0);
	
	@serializeAsColor3("diffuse")
	public var diffuseColor:Color3 = new Color3(1, 1, 1);
	
	@serializeAsColor3("specular")
	public var specularColor:Color3 = new Color3(1, 1, 1);
	
	@serializeAsColor3("emissive")
	public var emissiveColor:Color3 = new Color3(0, 0, 0);
	
	@serialize()
	public var specularPower:Float = 64;
	
	@serialize()
	public var useAlphaFromDiffuseTexture:Bool = false;
	
	@serialize()
	public var useEmissiveAsIllumination:Bool = false;
	
	@serialize()
	public var linkEmissiveWithDiffuse:Bool = false;
	
	@serialize()
	public var useReflectionFresnelFromSpecular:Bool = false;
	
	@serialize()
	public var useSpecularOverAlpha:Bool = false;
	
	@serialize()
	public var useReflectionOverAlpha:Bool = false;
	
	@serialize()	
	public var disableLighting:Bool = false;
	
	@serialize()
	public var useParallax:Bool = false;
	
	@serialize()
	public var useParallaxOcclusion:Bool = false;
	
	@serialize()
	public var parallaxScaleBias:Float = 0.05;
	
	@serialize()
	public var roughness:Float = 0;
	
	@serialize()
	public var indexOfRefraction:Float = 0.98;
	
	@serialize()
	public var invertRefractionY:Bool = true;
	
	@serialize()
	public var useLightmapAsShadowmap:Bool = false;

	@serializeAsFresnelParameters()
	public var diffuseFresnelParameters:FresnelParameters;
	
	@serializeAsFresnelParameters()
	public var opacityFresnelParameters:FresnelParameters;
	
	@serializeAsFresnelParameters()
	public var reflectionFresnelParameters:FresnelParameters;
	
	@serializeAsFresnelParameters()
	public var refractionFresnelParameters:FresnelParameters;
	
	@serializeAsFresnelParameters()
	public var emissiveFresnelParameters:FresnelParameters;
	
	@serialize()
	public var useGlossinessFromSpecularMapAlpha:Bool = false;
	
	@serialize()
	public var maxSimultaneousLights:Int = 4;
	
	/**
     * If sets to true, x component of normal map value will invert (x = 1.0 - x).
     */
    @serialize()
    public var invertNormalMapX:Bool = false;
	
	/**
	 * If sets to true, y component of normal map value will invert (y = 1.0 - y).
	 */
	@serialize()
	public var invertNormalMapY:Bool = false;
	
	/**
	 * Color Grading 2D Lookup Texture.
	 * This allows special effects like sepia, black and white to sixties rendering style. 
	 */
	@serializeAsTexture()
	public var cameraColorGradingTexture:BaseTexture = null;
	
	/**
	 * The color grading curves provide additional color adjustmnent that is applied after any color grading transform (3D LUT). 
	 * They allow basic adjustment of saturation and small exposure adjustments, along with color filter tinting to provide white 
	 * balance adjustment or more stylistic effects.
	 * These are similar to controls found in many professional imaging or colorist software. The global controls are applied to 
	 * the entire image. For advanced tuning, extra controls are provided to adjust the shadow, midtone and highlight areas of the image; 
	 * corresponding to low luminance, medium luminance, and high luminance areas respectively.
	 */
	@serializeAsColorCurves()
	public var cameraColorCurves:ColorCurves = null;

	private var _renderTargets:SmartArray<RenderTargetTexture> = new SmartArray<RenderTargetTexture>(16);
	private var _worldViewProjectionMatrix:Matrix = Matrix.Zero();
	private var _globalAmbientColor:Color3 = new Color3(0, 0, 0);
	private var _renderId:Int = 0;
	
	private var _defines:StandardMaterialDefines = new StandardMaterialDefines();
	private var _cachedDefines:StandardMaterialDefines = new StandardMaterialDefines();
	
	@serialize()
	public var useLogarithmicDepth(get, set):Bool;
	private var _useLogarithmicDepth:Bool = false;
	
	private var defs:Vector<Bool>;
	
	
	private var shaderName:String = "default";	
	private var uniforms:Array<String> = ["world", "view", "viewProjection", "vEyePosition", "vLightsType", "vAmbientColor", "vDiffuseColor", "vSpecularColor", "vEmissiveColor",
			"vFogInfos", "vFogColor", "pointSize",
			"vDiffuseInfos", "vAmbientInfos", "vOpacityInfos", "vReflectionInfos", "vEmissiveInfos", "vSpecularInfos", "vBumpInfos", "vLightmapInfos", "vRefractionInfos",
			"mBones",
			"vClipPlane", "diffuseMatrix", "ambientMatrix", "opacityMatrix", "reflectionMatrix", "emissiveMatrix", "specularMatrix", "bumpMatrix", "lightmapMatrix", "refractionMatrix",
			"depthValues",
			"diffuseLeftColor", "diffuseRightColor", "opacityParts", "reflectionLeftColor", "reflectionRightColor", "emissiveLeftColor", "emissiveRightColor", "refractionLeftColor", "refractionRightColor",
			"logarithmicDepthConstant"
		];		
	private var samplers:Array<String> = ["diffuseSampler", "ambientSampler", "opacitySampler", "reflectionCubeSampler", "reflection2DSampler", "emissiveSampler", "specularSampler", "bumpSampler", "lightmapSampler", "refractionCubeSampler", "refraction2DSampler"];
	

	public function new(name:String, scene:Scene) {
		super(name, scene);
		
		this._cachedDefines.BonesPerMesh = -1;
		
		this.getRenderTargetTextures = function():SmartArray<RenderTargetTexture> {
			this._renderTargets.reset();
			
			if (this.reflectionTexture != null && this.reflectionTexture.isRenderTarget) {
				this._renderTargets.push(cast this.reflectionTexture);
			}
			
			if (this.refractionTexture != null && this.refractionTexture.isRenderTarget) {
				this._renderTargets.push(cast this.refractionTexture);
			}
			
			return this._renderTargets;
		}
		
		this.defs = this._defines.defines;
	}
	
	private function get_useLogarithmicDepth():Bool {
		return this._useLogarithmicDepth;
	}
	private function set_useLogarithmicDepth(value:Bool):Bool {
		this._useLogarithmicDepth = value && this.getScene().getEngine().getCaps().fragmentDepthSupported;
		
		return this._useLogarithmicDepth;
	}

	override public function needAlphaBlending():Bool {
		return (this.alpha < 1.0) || (this.opacityTexture != null) || this._shouldUseAlphaFromDiffuseTexture() || (this.opacityFresnelParameters != null) && this.opacityFresnelParameters.isEnabled;
	}

	override public function needAlphaTesting():Bool {
		return this.diffuseTexture != null && this.diffuseTexture.hasAlpha;
	}

	private function _shouldUseAlphaFromDiffuseTexture():Bool {
		return this.diffuseTexture != null && this.diffuseTexture.hasAlpha && this.useAlphaFromDiffuseTexture;
	}

	override public function getAlphaTestTexture():BaseTexture {
		return this.diffuseTexture;
	}

	// Methods
	private function _checkCache(scene:Scene, ?mesh:AbstractMesh, useInstances:Bool = false):Bool {
		if (mesh == null) {
			return true;
		}
		
		if (this.defs[SMD.INSTANCES] != useInstances) {
			return false;
		}
		
		if (mesh._materialDefines != null && mesh._materialDefines.isEqual(this._defines)) {
			return true;
		}
		
		return false;
	}

	override public function isReady(?mesh:AbstractMesh, useInstances:Bool = false):Bool {
		if (this.isFrozen) {
			if (this._wasPreviouslyReady) {
				return true;
			}
		}
		
		var scene = this.getScene();
		
		if (!this.checkReadyOnEveryCall) {
			if (this._renderId == scene.getRenderId()) {
				if (this._checkCache(scene, mesh, useInstances)) {
					return true;
				}
			}
		}
		
		var engine = scene.getEngine();
		var needNormals = false;
		var needUVs = false;
		
		this._defines.reset();
		
		// Textures
		if (scene.texturesEnabled) {
			if (this.diffuseTexture != null && StandardMaterial.DiffuseTextureEnabled) {
				if (!this.diffuseTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.DIFFUSE] = true;
				}
			}
			
			if (this.ambientTexture != null && StandardMaterial.AmbientTextureEnabled) {
				if (!this.ambientTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.AMBIENT] = true;
				}
			}
			
			if (this.opacityTexture != null && StandardMaterial.OpacityTextureEnabled) {
				if (!this.opacityTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.OPACITY] = true;
					
					if (this.opacityTexture.getAlphaFromRGB) {
						this.defs[SMD.OPACITYRGB] = true;
					}
				}
			}
			
			if (this.reflectionTexture != null && StandardMaterial.ReflectionTextureEnabled) {
				if (!this.reflectionTexture.isReady()) {
					return false;
				} 
				else {
					needNormals = true;
					this.defs[SMD.REFLECTION] = true;
					
					if (this.roughness > 0) {
						this.defs[SMD.ROUGHNESS] = true;
					}
					
					if (this.useReflectionOverAlpha) {
						this.defs[SMD.REFLECTIONOVERALPHA] = true;
					}
					
					if (this.reflectionTexture.coordinatesMode == Texture.INVCUBIC_MODE) {
						this.defs[SMD.INVERTCUBICMAP] = true;
					}
					
					this.defs[SMD.REFLECTIONMAP_3D] = this.reflectionTexture.isCube;
					
					switch (this.reflectionTexture.coordinatesMode) {
						case Texture.CUBIC_MODE, Texture.INVCUBIC_MODE:
							this.defs[SMD.REFLECTIONMAP_CUBIC] = true;
							
						case Texture.EXPLICIT_MODE:
							this.defs[SMD.REFLECTIONMAP_EXPLICIT] = true;
							
						case Texture.PLANAR_MODE:
							this.defs[SMD.REFLECTIONMAP_PLANAR] = true;
							
						case Texture.PROJECTION_MODE:
							this.defs[SMD.REFLECTIONMAP_PROJECTION] = true;
							
						case Texture.SKYBOX_MODE:
							this.defs[SMD.REFLECTIONMAP_SKYBOX] = true;
							
						case Texture.SPHERICAL_MODE:
							this.defs[SMD.REFLECTIONMAP_SPHERICAL] = true;
							
						case Texture.EQUIRECTANGULAR_MODE:
							this.defs[SMD.REFLECTIONMAP_EQUIRECTANGULAR] = true;	
							
						case Texture.FIXED_EQUIRECTANGULAR_MODE:
                            this.defs[SMD.REFLECTIONMAP_EQUIRECTANGULAR_FIXED] = true;
					}
				}
			}
			
			if (this.emissiveTexture != null && StandardMaterial.EmissiveTextureEnabled) {
				if (!this.emissiveTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.EMISSIVE] = true;
				}
			}
			
			if (this.lightmapTexture != null && StandardMaterial.LightmapTextureEnabled) {
				if (!this.lightmapTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.LIGHTMAP] = true;
					this.defs[SMD.USELIGHTMAPASSHADOWMAP] = this.useLightmapAsShadowmap;
				}
			}
			
			if (this.specularTexture != null && StandardMaterial.SpecularTextureEnabled) {
				if (!this.specularTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.SPECULAR] = true;
					this.defs[SMD.GLOSSINESS] = this.useGlossinessFromSpecularMapAlpha;
				}
			}
			
			if (scene.getEngine().getCaps().standardDerivatives == true && this.bumpTexture != null && StandardMaterial.BumpTextureEnabled) {
				if (!this.bumpTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.BUMP] = true;
					
					if (this.useParallax) {
						this.defs[SMD.PARALLAX] = true;
						if (this.useParallaxOcclusion) {
							this.defs[SMD.PARALLAXOCCLUSION] = true;
						}
					}
					
					if (this.invertNormalMapX) {
                        this.defs[SMD.INVERTNORMALMAPX] = true;
                    }
					
					if (this.invertNormalMapY) {
                        this.defs[SMD.INVERTNORMALMAPY] = true;
                    }
				}
			}
			
			if (this.refractionTexture != null && StandardMaterial.RefractionTextureEnabled) {
				if (!this.refractionTexture.isReady()) {
					return false;
				} 
				else {
					needUVs = true;
					this.defs[SMD.REFRACTION] = true;
					
					this.defs[SMD.REFRACTIONMAP_3D] = this.refractionTexture.isCube;
				}
			}
			
			if (this.cameraColorGradingTexture != null && StandardMaterial.ColorGradingTextureEnabled) {
				if (!this.cameraColorGradingTexture.isReady()) {
					return false;
				} 
				else {
					this.defs[SMD.CAMERACOLORGRADING] = true;
				}
			}
		}		
		
		// Effect
		if (scene.clipPlane != null) {
			this.defs[SMD.CLIPPLANE] = true;
		}
		
		if (engine.getAlphaTesting()) {
			this.defs[SMD.ALPHATEST] = true;
		}
		
		if (this._shouldUseAlphaFromDiffuseTexture()) {
			this.defs[SMD.ALPHAFROMDIFFUSE] = true;
		}
		
		if (this.useEmissiveAsIllumination) {
			this.defs[SMD.EMISSIVEASILLUMINATION] = true;
		}
		
		if (this.linkEmissiveWithDiffuse) {
			this.defs[SMD.LINKEMISSIVEWITHDIFFUSE] = true;
		}
		
		if (this.useLogarithmicDepth) {
            this.defs[SMD.LOGARITHMICDEPTH] = true;
        }
		
		if (this.cameraColorCurves != null) {
			this.defs[SMD.CAMERACOLORCURVES] = true;
		}
		
		// Point size
		if (this.pointsCloud || scene.forcePointsCloud) {
			this.defs[SMD.POINTSIZE] = true;
		}
		
		// Fog
		if (scene.fogEnabled && mesh != null && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE && this.fogEnabled) {
			this.defs[SMD.FOG] = true;
		}
		
		if (scene.lightsEnabled && !this.disableLighting) {
			needNormals = MaterialHelper.PrepareDefinesForLights(scene, mesh, this._defines, maxSimultaneousLights, SMD.SPECULARTERM, SMD.SHADOWS, SMD.SHADOWFULLFLOAT);
		}
		
		if (StandardMaterial.FresnelEnabled) {
			// Fresnel
			if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled) {
				this.defs[SMD.DIFFUSEFRESNEL] = true;
			}
			
			if (this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled) {
				this.defs[SMD.OPACITYFRESNEL] = true;
			}
			
			if (this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
				this.defs[SMD.REFLECTIONFRESNEL] = true;
				
				if (this.useReflectionFresnelFromSpecular) {
					this.defs[SMD.REFLECTIONFRESNELFROMSPECULAR] = true;
				}
			}
			
			if (this.refractionFresnelParameters != null && this.refractionFresnelParameters.isEnabled) {
				this.defs[SMD.REFRACTIONFRESNEL] = true;
			}
			
			if (this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled) {
				this.defs[SMD.EMISSIVEFRESNEL] = true;
			}
			
			if (this.defs[SMD.DIFFUSEFRESNEL] ||
				this.defs[SMD.OPACITYFRESNEL] ||
				this.defs[SMD.REFLECTIONFRESNEL] ||
				this.defs[SMD.EMISSIVEFRESNEL] ||
				this.defs[SMD.REFRACTIONFRESNEL]) {	
				
				needNormals = true;
				this.defs[SMD.FRESNEL] = true;
			}
		}
		
		if (this.defs[SMD.SPECULARTERM] && this.useSpecularOverAlpha) {
			this.defs[SMD.SPECULAROVERALPHA] = true;
		}
		
		// Attribs
		if (mesh != null) {
			if (needNormals && mesh.isVerticesDataPresent(VertexBuffer.NormalKind)) {
				this.defs[SMD.NORMAL] = true;
			}
			if (needUVs) {
				if (mesh.isVerticesDataPresent(VertexBuffer.UVKind)) {
					this.defs[SMD.UV1] = true;
				}
				if (mesh.isVerticesDataPresent(VertexBuffer.UV2Kind)) {
					this.defs[SMD.UV2] = true;
				}
			}
			if (mesh.useVertexColors && mesh.isVerticesDataPresent(VertexBuffer.ColorKind)) {
				this.defs[SMD.VERTEXCOLOR] = true;
				
				if (mesh.hasVertexAlpha) {
					this.defs[SMD.VERTEXALPHA] = true;
				}
			}
			if (mesh.useBones && mesh.computeBonesUsingShaders) {
				this._defines.NUM_BONE_INFLUENCERS = mesh.numBoneInfluencers;
				this._defines.BonesPerMesh = (mesh.skeleton.bones.length + 1);
			}
			
			// Instances
			if (useInstances) {
				this.defs[SMD.INSTANCES] = true;
			}
		}
		
		// Get correct effect      
		if (!this._defines.isEqual(this._cachedDefines)) {
			this._defines.cloneTo(this._cachedDefines);
			
			scene.resetCachedMaterial();
			
			// Fallbacks
			var fallbacks = new EffectFallbacks();
			if (this.defs[SMD.REFLECTION]) {
				fallbacks.addFallback(0, "REFLECTION");
			}
			
			if (this.defs[SMD.SPECULAR]) {
				fallbacks.addFallback(0, "SPECULAR");
			}
			
			if (this.defs[SMD.BUMP]) {
				fallbacks.addFallback(0, "BUMP");
			}
			
			if (this.defs[SMD.PARALLAX]) {
				fallbacks.addFallback(1, "PARALLAX");
			}
			
			if (this.defs[SMD.PARALLAXOCCLUSION]) {
				fallbacks.addFallback(0, "PARALLAXOCCLUSION");
			}
			
			if (this.defs[SMD.SPECULAROVERALPHA]) {
				fallbacks.addFallback(0, "SPECULAROVERALPHA");
			}
			
			if (this.defs[SMD.FOG]) {
				fallbacks.addFallback(1, "FOG");
			}
			
			if (this.defs[SMD.POINTSIZE]) {
                fallbacks.addFallback(0, "POINTSIZE");
            }
			
			if (this.defs[SMD.LOGARITHMICDEPTH]) {
                fallbacks.addFallback(0, "LOGARITHMICDEPTH");
            }
			
			MaterialHelper.HandleFallbacksForShadows(this._defines, fallbacks, this.maxSimultaneousLights);
			
			if (this.defs[SMD.SPECULARTERM]) {
				fallbacks.addFallback(0, "SPECULARTERM");
			}
			
			if (this.defs[SMD.DIFFUSEFRESNEL]) {
				fallbacks.addFallback(1, "DIFFUSEFRESNEL");
			}
			
			if (this.defs[SMD.OPACITYFRESNEL]) {
				fallbacks.addFallback(2, "OPACITYFRESNEL");
			}
			
			if (this.defs[SMD.REFLECTIONFRESNEL]) {
				fallbacks.addFallback(3, "REFLECTIONFRESNEL");
			}
			
			if (this.defs[SMD.EMISSIVEFRESNEL]) {
				fallbacks.addFallback(4, "EMISSIVEFRESNEL");
			}
			
			if (this.defs[SMD.FRESNEL]) {
				fallbacks.addFallback(4, "FRESNEL");
			}
			
			if (this._defines.NUM_BONE_INFLUENCERS > 0){
				fallbacks.addCPUSkinningFallback(0, mesh);    
			}
			
			//Attributes
			var attribs:Array<String> = [VertexBuffer.PositionKind];
			
			if (this.defs[SMD.NORMAL]) {
				attribs.push(VertexBuffer.NormalKind);
			}
			
			if (this.defs[SMD.UV1]) {
				attribs.push(VertexBuffer.UVKind);
			}
			
			if (this.defs[SMD.UV2]) {
				attribs.push(VertexBuffer.UV2Kind);
			}
			
			if (this.defs[SMD.VERTEXCOLOR]) {
				attribs.push(VertexBuffer.ColorKind);
			}
			
			MaterialHelper.PrepareAttributesForBones(attribs, mesh, this._defines.NUM_BONE_INFLUENCERS, fallbacks);
            MaterialHelper.PrepareAttributesForInstances(attribs, this.defs, SMD.INSTANCES);
			
			// Legacy browser patch
			if (scene.getEngine().getCaps().standardDerivatives != true) {
				shaderName = "legacydefault";
			}
			var join:String = this._defines.toString();
			
			if (this.defs[SMD.CAMERACOLORCURVES]) {
				ColorCurves.PrepareUniforms(uniforms);
			}
			if (this.defs[SMD.CAMERACOLORGRADING]) {
				ColorGradingTexture.PrepareUniformsAndSamplers(uniforms, samplers);
			}
			
			MaterialHelper.PrepareUniformsAndSamplersList(uniforms, samplers, this._defines.lights, this.maxSimultaneousLights);
			
			this._effect = scene.getEngine().createEffect(shaderName,
                    attribs, uniforms, samplers,
                    join, fallbacks, this.onCompiled, this.onError, { maxSimultaneousLights: this.maxSimultaneousLights - 1 });
		}
		if (this._effect == null || !this._effect.isReady()) {
			return false;
		}
		
		this._renderId = scene.getRenderId();
		this._wasPreviouslyReady = true;
		
		if (mesh != null) {
			if (mesh._materialDefines == null) {
				mesh._materialDefines = new StandardMaterialDefines();
			}
			
			this._defines.cloneTo(mesh._materialDefines);
		}
		
		return true;
	}

	override public function unbind() {
		if (this.reflectionTexture != null && this.reflectionTexture.isRenderTarget) {
			this._effect.setTexture("reflection2DSampler", null);
		}
		
		if (this.refractionTexture != null && this.refractionTexture.isRenderTarget) {
			this._effect.setTexture("refraction2DSampler", null);
		}
		
		super.unbind();
	}

	override public function bindOnlyWorldMatrix(world:Matrix) {
		this._effect.setMatrix("world", world);
	}

	override public function bind(world:Matrix, ?mesh:Mesh) {
		var scene = this.getScene();
		
		// Matrices        
		this.bindOnlyWorldMatrix(world);
		
		// Bones
		MaterialHelper.BindBonesParameters(mesh, this._effect);
		
		if (scene.getCachedMaterial() != this) {
			this._effect.setMatrix("viewProjection", scene.getTransformMatrix());
			
			if (StandardMaterial.FresnelEnabled) {
				// Fresnel
				if (this.diffuseFresnelParameters != null && this.diffuseFresnelParameters.isEnabled) {
					this._effect.setColor4("diffuseLeftColor", this.diffuseFresnelParameters.leftColor, this.diffuseFresnelParameters.power);
					this._effect.setColor4("diffuseRightColor", this.diffuseFresnelParameters.rightColor, this.diffuseFresnelParameters.bias);
				}
				
				if (this.opacityFresnelParameters != null && this.opacityFresnelParameters.isEnabled) {
					this._effect.setColor4("opacityParts", new Color3(this.opacityFresnelParameters.leftColor.toLuminance(), this.opacityFresnelParameters.rightColor.toLuminance(), this.opacityFresnelParameters.bias), this.opacityFresnelParameters.power);
				}
				
				if (this.reflectionFresnelParameters != null && this.reflectionFresnelParameters.isEnabled) {
					this._effect.setColor4("reflectionLeftColor", this.reflectionFresnelParameters.leftColor, this.reflectionFresnelParameters.power);
					this._effect.setColor4("reflectionRightColor", this.reflectionFresnelParameters.rightColor, this.reflectionFresnelParameters.bias);
				}
				
				if (this.refractionFresnelParameters != null && this.refractionFresnelParameters.isEnabled) {
					this._effect.setColor4("refractionLeftColor", this.refractionFresnelParameters.leftColor, this.refractionFresnelParameters.power);
					this._effect.setColor4("refractionRightColor", this.refractionFresnelParameters.rightColor, this.refractionFresnelParameters.bias);
				}
				
				if (this.emissiveFresnelParameters != null && this.emissiveFresnelParameters.isEnabled) {
					this._effect.setColor4("emissiveLeftColor", this.emissiveFresnelParameters.leftColor, this.emissiveFresnelParameters.power);
					this._effect.setColor4("emissiveRightColor", this.emissiveFresnelParameters.rightColor, this.emissiveFresnelParameters.bias);
				}
			}
			
			// Textures 
			if (scene.texturesEnabled) {
				if (this.diffuseTexture != null && StandardMaterial.DiffuseTextureEnabled) {
					this._effect.setTexture("diffuseSampler", this.diffuseTexture);
					
					this._effect.setFloat2("vDiffuseInfos", this.diffuseTexture.coordinatesIndex, this.diffuseTexture.level);
					this._effect.setMatrix("diffuseMatrix", this.diffuseTexture.getTextureMatrix());
				}
				
				if (this.ambientTexture != null && StandardMaterial.AmbientTextureEnabled) {
					this._effect.setTexture("ambientSampler", this.ambientTexture);
					
					this._effect.setFloat2("vAmbientInfos", this.ambientTexture.coordinatesIndex, this.ambientTexture.level);
					this._effect.setMatrix("ambientMatrix", this.ambientTexture.getTextureMatrix());
				}
				
				if (this.opacityTexture != null && StandardMaterial.OpacityTextureEnabled) {
					this._effect.setTexture("opacitySampler", this.opacityTexture);
					
					this._effect.setFloat2("vOpacityInfos", this.opacityTexture.coordinatesIndex, this.opacityTexture.level);
					this._effect.setMatrix("opacityMatrix", this.opacityTexture.getTextureMatrix());
				}
				
				if (this.reflectionTexture != null && StandardMaterial.ReflectionTextureEnabled) {
					if (this.reflectionTexture.isCube) {
						this._effect.setTexture("reflectionCubeSampler", this.reflectionTexture);
					} 
					else {
						this._effect.setTexture("reflection2DSampler", this.reflectionTexture);
					}
					
					this._effect.setMatrix("reflectionMatrix", this.reflectionTexture.getReflectionTextureMatrix());
					this._effect.setFloat2("vReflectionInfos", this.reflectionTexture.level, this.roughness);
				}
				
				if (this.emissiveTexture != null && StandardMaterial.EmissiveTextureEnabled) {
					this._effect.setTexture("emissiveSampler", this.emissiveTexture);
					
					this._effect.setFloat2("vEmissiveInfos", this.emissiveTexture.coordinatesIndex, this.emissiveTexture.level);
					this._effect.setMatrix("emissiveMatrix", this.emissiveTexture.getTextureMatrix());
				}
				
				if (this.lightmapTexture != null && StandardMaterial.LightmapTextureEnabled) {
					this._effect.setTexture("lightmapSampler", this.lightmapTexture);
					
					this._effect.setFloat2("vLightmapInfos", this.lightmapTexture.coordinatesIndex, this.lightmapTexture.level);
					this._effect.setMatrix("lightmapMatrix", this.lightmapTexture.getTextureMatrix());
				}
				
				if (this.specularTexture != null && StandardMaterial.SpecularTextureEnabled) {
					this._effect.setTexture("specularSampler", this.specularTexture);
					
					this._effect.setFloat2("vSpecularInfos", this.specularTexture.coordinatesIndex, this.specularTexture.level);
					this._effect.setMatrix("specularMatrix", this.specularTexture.getTextureMatrix());
				}
				
				if (this.bumpTexture != null && scene.getEngine().getCaps().standardDerivatives == true && StandardMaterial.BumpTextureEnabled) {
					this._effect.setTexture("bumpSampler", this.bumpTexture);
					
					this._effect.setFloat3("vBumpInfos", this.bumpTexture.coordinatesIndex, 1.0 / this.bumpTexture.level, this.parallaxScaleBias);
					this._effect.setMatrix("bumpMatrix", this.bumpTexture.getTextureMatrix());
				}
				
				if (this.refractionTexture != null && StandardMaterial.RefractionTextureEnabled) {
					var depth:Float = 1.0;
					if (this.refractionTexture.isCube) {
						this._effect.setTexture("refractionCubeSampler", this.refractionTexture);
					} 
					else {
						this._effect.setTexture("refraction2DSampler", this.refractionTexture);
						this._effect.setMatrix("refractionMatrix", this.refractionTexture.getReflectionTextureMatrix());
						
						if (Std.is(this.refractionTexture, RefractionTexture)) {
							depth = untyped this.refractionTexture.depth;
						}
					}
					this._effect.setFloat4("vRefractionInfos", this.refractionTexture.level, this.indexOfRefraction, depth, this.invertRefractionY ? -1 : 1);
				}
				
				if (this.cameraColorGradingTexture != null && StandardMaterial.ColorGradingTextureEnabled) {
					ColorGradingTexture.Bind(this.cameraColorGradingTexture, this._effect);
				}
			}
			
			// Clip plane
			MaterialHelper.BindClipPlane(this._effect, scene);
			
			// Point size
			if (this.pointsCloud) {
				this._effect.setFloat("pointSize", this.pointSize);
			}
			
			// Colors
			scene.ambientColor.multiplyToRef(this.ambientColor, this._globalAmbientColor);
			
			this._effect.setVector3("vEyePosition", scene._mirroredCameraPosition != null ? scene._mirroredCameraPosition : scene.activeCamera.position);
			this._effect.setColor3("vAmbientColor", this._globalAmbientColor);
			
			if (this.defs[SMD.SPECULARTERM]) {
				this._effect.setColor4("vSpecularColor", this.specularColor, this.specularPower);
			}
			this._effect.setColor3("vEmissiveColor", this.emissiveColor);
		}
		
		if (scene.getCachedMaterial() != this || !this.isFrozen) {
			// Diffuse
			this._effect.setColor4("vDiffuseColor", this.diffuseColor, this.alpha * mesh.visibility);
			
			// Lights
			if (scene.lightsEnabled && !this.disableLighting) {
				MaterialHelper.BindLights(scene, mesh, this._effect, this.defs[SMD.SPECULARTERM], this.maxSimultaneousLights);
			}
			
			// View
			if (scene.fogEnabled && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE || this.reflectionTexture != null || this.refractionTexture != null) {
				this._effect.setMatrix("view", scene.getViewMatrix());
			}
			
			// Fog
			MaterialHelper.BindFogParameters(scene, mesh, this._effect);
			
			// Log. depth
			MaterialHelper.BindLogDepth(this.defs[SMD.LOGARITHMICDEPTH], this._effect, scene);
			
			// Color Curves
			if (this.cameraColorCurves != null) {
				ColorCurves.Bind(this.cameraColorCurves, this._effect);
			}
		}
		
		super.bind(world, mesh);
	}

	public function getAnimatables():Array<IAnimatable> {
		var results:Array<IAnimatable> = [];
		
		if (this.diffuseTexture != null && this.diffuseTexture.animations != null && this.diffuseTexture.animations.length > 0) {
			results.push(this.diffuseTexture);
		}
		
		if (this.ambientTexture != null && this.ambientTexture.animations != null && this.ambientTexture.animations.length > 0) {
			results.push(this.ambientTexture);
		}
		
		if (this.opacityTexture != null && this.opacityTexture.animations != null && this.opacityTexture.animations.length > 0) {
			results.push(this.opacityTexture);
		}
		
		if (this.reflectionTexture != null && this.reflectionTexture.animations != null && this.reflectionTexture.animations.length > 0) {
			results.push(this.reflectionTexture);
		}
		
		if (this.emissiveTexture != null && this.emissiveTexture.animations != null && this.emissiveTexture.animations.length > 0) {
			results.push(this.emissiveTexture);
		}
		
		if (this.specularTexture != null && this.specularTexture.animations != null && this.specularTexture.animations.length > 0) {
			results.push(this.specularTexture);
		}
		
		if (this.bumpTexture != null && this.bumpTexture.animations != null && this.bumpTexture.animations.length > 0) {
			results.push(this.bumpTexture);
		}
		
		if (this.refractionTexture != null && this.refractionTexture.animations != null && this.refractionTexture.animations.length > 0) {
			results.push(this.refractionTexture);
		}
		
		if (this.cameraColorGradingTexture != null && this.cameraColorGradingTexture.animations != null && this.cameraColorGradingTexture.animations.length > 0) {
			results.push(this.cameraColorGradingTexture);
		}
		
		return results;
	}

	override public function dispose(forceDisposeEffect:Bool = false, forceDisposeTextures:Bool = true) {
		if (forceDisposeTextures) {
			if (this.diffuseTexture != null) {
				this.diffuseTexture.dispose();
			}
			
			if (this.ambientTexture != null) {
				this.ambientTexture.dispose();
			}
			
			if (this.opacityTexture != null) {
				this.opacityTexture.dispose();
			}
			
			if (this.reflectionTexture != null) {
				this.reflectionTexture.dispose();
			}
			
			if (this.emissiveTexture != null) {
				this.emissiveTexture.dispose();
			}
			
			if (this.specularTexture != null) {
				this.specularTexture.dispose();
			}
			
			if (this.bumpTexture != null) {
				this.bumpTexture.dispose();
			}
			
			if (this.refractionTexture != null) {
				this.refractionTexture.dispose();
			}
			
			if (this.cameraColorGradingTexture != null) {
				this.cameraColorGradingTexture.dispose();
			}
		}
		
		super.dispose(forceDisposeEffect);
	}

	override public function clone(name:String, cloneChildren:Bool = false):StandardMaterial {
		var newStandardMaterial = new StandardMaterial(name, this.getScene());
		
		// Base material
		this.copyTo(newStandardMaterial);
		
		// Standard material
		if (this.diffuseTexture != null) {
			newStandardMaterial.diffuseTexture = this.diffuseTexture.clone();
		}
		if (this.ambientTexture != null) {
			newStandardMaterial.ambientTexture = this.ambientTexture.clone();
		}
		if (this.opacityTexture != null) {
			newStandardMaterial.opacityTexture = this.opacityTexture.clone();
		}
		if (this.reflectionTexture != null) {
			newStandardMaterial.reflectionTexture = this.reflectionTexture.clone();
		}
		if (this.emissiveTexture != null) {
			newStandardMaterial.emissiveTexture = this.emissiveTexture.clone();
		}
		if (this.specularTexture != null) {
			newStandardMaterial.specularTexture = this.specularTexture.clone();
		}
		if (this.bumpTexture != null) {
			newStandardMaterial.bumpTexture = this.bumpTexture.clone();
		}
		if (this.lightmapTexture != null) {
			newStandardMaterial.lightmapTexture = this.lightmapTexture.clone();
			newStandardMaterial.useLightmapAsShadowmap = this.useLightmapAsShadowmap;
		}
		if (this.refractionTexture != null) {
			newStandardMaterial.refractionTexture = this.refractionTexture.clone();
		}
		
		newStandardMaterial.ambientColor = this.ambientColor.clone();
		newStandardMaterial.diffuseColor = this.diffuseColor.clone();
		newStandardMaterial.specularColor = this.specularColor.clone();
		newStandardMaterial.specularPower = this.specularPower;
		newStandardMaterial.emissiveColor = this.emissiveColor.clone();
		newStandardMaterial.useAlphaFromDiffuseTexture = this.useAlphaFromDiffuseTexture;
		newStandardMaterial.useEmissiveAsIllumination = this.useEmissiveAsIllumination;
		newStandardMaterial.useGlossinessFromSpecularMapAlpha = this.useGlossinessFromSpecularMapAlpha;
		newStandardMaterial.useReflectionFresnelFromSpecular = this.useReflectionFresnelFromSpecular;
		newStandardMaterial.useSpecularOverAlpha = this.useSpecularOverAlpha;
		newStandardMaterial.useReflectionOverAlpha = this.useReflectionOverAlpha;
		newStandardMaterial.roughness = this.roughness;
		newStandardMaterial.indexOfRefraction = this.indexOfRefraction;
        newStandardMaterial.invertRefractionY = this.invertRefractionY;
		
		if (this.diffuseFresnelParameters != null) {
			newStandardMaterial.diffuseFresnelParameters = this.diffuseFresnelParameters.clone();
		}
		if (this.emissiveFresnelParameters != null) {
			newStandardMaterial.emissiveFresnelParameters = this.emissiveFresnelParameters.clone();
		}
		if (this.reflectionFresnelParameters != null) {
			newStandardMaterial.reflectionFresnelParameters = this.reflectionFresnelParameters.clone();
		}
		if (this.refractionFresnelParameters != null) {
			newStandardMaterial.refractionFresnelParameters = this.refractionFresnelParameters.clone();
		}
		if (this.opacityFresnelParameters != null) {
			newStandardMaterial.opacityFresnelParameters = this.opacityFresnelParameters.clone();
		}
		
		return newStandardMaterial;
	}
	
	override public function serialize():Dynamic {
		var serializationObject = super.serialize();
		
		serializationObject.ambient = this.ambientColor.asArray();
		serializationObject.diffuse = this.diffuseColor.asArray();
		serializationObject.specular = this.specularColor.asArray();
		serializationObject.specularPower = this.specularPower;
		serializationObject.emissive = this.emissiveColor.asArray();
		serializationObject.useReflectionFresnelFromSpecular = this.useReflectionFresnelFromSpecular;
        serializationObject.useEmissiveAsIllumination = this.useEmissiveAsIllumination;
        serializationObject.indexOfRefraction = this.indexOfRefraction;
        serializationObject.invertRefractionY = this.invertRefractionY;
		serializationObject.useSpecularOverAlpha = this.useSpecularOverAlpha;
		serializationObject.useReflectionOverAlpha = this.useReflectionOverAlpha;
		
		if (this.diffuseTexture != null) {
			serializationObject.diffuseTexture = this.diffuseTexture.serialize();
		}
		
		if (this.diffuseFresnelParameters != null) {
			serializationObject.diffuseFresnelParameters = this.diffuseFresnelParameters.serialize();
		}
		
		if (this.ambientTexture != null) {
			serializationObject.ambientTexture = this.ambientTexture.serialize();
		}
		
		if (this.opacityTexture != null) {
			serializationObject.opacityTexture = this.opacityTexture.serialize();
		}
		
		if (this.opacityFresnelParameters != null) {
			serializationObject.opacityFresnelParameters = this.diffuseFresnelParameters.serialize();
		}
		
		if (this.reflectionTexture != null) {
			serializationObject.reflectionTexture = this.reflectionTexture.serialize();
		}
		
		if (this.reflectionFresnelParameters != null) {
			serializationObject.reflectionFresnelParameters = this.reflectionFresnelParameters.serialize();
		}
		
		if (this.emissiveTexture != null) {
			serializationObject.emissiveTexture = this.emissiveTexture.serialize();
		}
		
		if (this.lightmapTexture != null) {
			serializationObject.lightmapTexture = this.lightmapTexture.serialize();
			serializationObject.useLightmapAsShadowmap = this.useLightmapAsShadowmap;
		}
		
		if (this.emissiveFresnelParameters != null) {
			serializationObject.emissiveFresnelParameters = this.emissiveFresnelParameters.serialize();
		}
		
		if (this.specularTexture != null) {
			serializationObject.specularTexture = this.specularTexture.serialize();
		}
		
		if (this.bumpTexture != null) {
			serializationObject.bumpTexture = this.bumpTexture.serialize();
		}
		
		if (this.refractionTexture != null) {
			serializationObject.refractionTexture = this.refractionTexture.serialize();
		}
		
		return serializationObject;
	}
	
	
	public static function ParseFresnelParameters(parsedFresnelParameters:Dynamic):FresnelParameters {
        var fresnelParameters = new FresnelParameters();
		
        fresnelParameters.isEnabled = parsedFresnelParameters.isEnabled;
        fresnelParameters.leftColor = Color3.FromArray(parsedFresnelParameters.leftColor);
        fresnelParameters.rightColor = Color3.FromArray(parsedFresnelParameters.rightColor);
        fresnelParameters.bias = parsedFresnelParameters.bias;
        fresnelParameters.power = parsedFresnelParameters.power != null ? parsedFresnelParameters.power : 1.0;
		
        return fresnelParameters;
    }

    public static function Parse(source:Dynamic, scene:Scene, rootUrl:String):Material {
        var material = new StandardMaterial(source.name, scene);
		
        material.ambientColor = Color3.FromArray(source.ambient);
        material.diffuseColor = Color3.FromArray(source.diffuse);
        material.specularColor = Color3.FromArray(source.specular);
        material.specularPower = source.specularPower;
        material.emissiveColor = Color3.FromArray(source.emissive);
		material.useReflectionFresnelFromSpecular = source.useReflectionFresnelFromSpecular;
        material.useEmissiveAsIllumination = source.useEmissiveAsIllumination;
		material.indexOfRefraction = source.indexOfRefraction;
        material.invertRefractionY = source.invertRefractionY;
		material.useSpecularOverAlpha = source.useSpecularOverAlpha;
		material.useReflectionOverAlpha = source.useReflectionOverAlpha;
		
        material.alpha = source.alpha;
		
        material.id = source.id;
		
		if (source.disableDepthWrite != null) {
            material.disableDepthWrite = source.disableDepthWrite;
        }
		
        Tags.AddTagsTo(material, source.tags);
        material.backFaceCulling = source.backFaceCulling;
        material.wireframe = source.wireframe;
		
        if (source.diffuseTexture != null) {
            material.diffuseTexture = Texture.Parse(source.diffuseTexture, scene, rootUrl);
        }
		
        if (source.diffuseFresnelParameters != null) {
            material.diffuseFresnelParameters = StandardMaterial.ParseFresnelParameters(source.diffuseFresnelParameters);
        }
		
        if (source.ambientTexture != null) {
            material.ambientTexture = Texture.Parse(source.ambientTexture, scene, rootUrl);
        }
		
        if (source.opacityTexture != null) {
            material.opacityTexture = Texture.Parse(source.opacityTexture, scene, rootUrl);
        }
		
        if (source.opacityFresnelParameters != null) {
            material.opacityFresnelParameters = StandardMaterial.ParseFresnelParameters(source.opacityFresnelParameters);
        }
		
        if (source.reflectionTexture != null) {
            material.reflectionTexture = Texture.Parse(source.reflectionTexture, scene, rootUrl);
        }
		
        if (source.reflectionFresnelParameters != null) {
            material.reflectionFresnelParameters = StandardMaterial.ParseFresnelParameters(source.reflectionFresnelParameters);
        }
		
        if (source.emissiveTexture != null) {
            material.emissiveTexture = Texture.Parse(source.emissiveTexture, scene, rootUrl);
        }
		
		if (source.lightmapTexture != null) {
            material.lightmapTexture = Texture.Parse(source.lightmapTexture, scene, rootUrl);
            untyped material.lightmapThreshold = source.lightmapThreshold;
        }
		
        if (source.emissiveFresnelParameters != null) {
            material.emissiveFresnelParameters = StandardMaterial.ParseFresnelParameters(source.emissiveFresnelParameters);
        }
		
        if (source.specularTexture != null) {
            material.specularTexture = Texture.Parse(source.specularTexture, scene, rootUrl);
        }
		
        if (source.bumpTexture != null) {
            material.bumpTexture = Texture.Parse(source.bumpTexture, scene, rootUrl);
        }
		
		if (source.refractionTexture != null) {
			material.refractionTexture = Texture.Parse(source.refractionTexture, scene, rootUrl);
		}
		
		if (source.checkReadyOnlyOnce != null) {
            material.checkReadyOnlyOnce = source.checkReadyOnlyOnce;
        }
		
        return material;
    }

}