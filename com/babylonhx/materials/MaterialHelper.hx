package com.babylonhx.materials;

import com.babylonhx.mesh.AbstractMesh;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Tmp;
import com.babylonhx.lights.Light;
import com.babylonhx.lights.IShadowLight;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */
class MaterialHelper {	

	public static function PrepareDefinesForLights(scene:Scene, mesh:AbstractMesh, defines:MaterialDefines, maxSimultaneousLights:Int, SPECULARTERM:Int = -1, SHADOWS:Int = -1, SHADOWFULLFLOAT:Int = -1):Bool {
		var lightIndex:Int = 0;
		var needNormals:Bool = false;
		var needShadows:Bool = false;
		
		for (index in 0...scene.lights.length) {
			var light = scene.lights[index];
			
			if (!light.isEnabled()) {
				continue;
			}
			
			// Excluded check
			if (light._excludedMeshesIds.length > 0) {
				for (excludedIndex in 0...light._excludedMeshesIds.length) {
					var excludedMesh = scene.getMeshByID(light._excludedMeshesIds[excludedIndex]);
					
					if (excludedMesh != null) {
						light.excludedMeshes.push(excludedMesh);
					}
				}
				
				light._excludedMeshesIds = [];
			}
			
			// Included check
			if (light._includedOnlyMeshesIds.length > 0) {
				for (includedOnlyIndex in 0...light._includedOnlyMeshesIds.length) {
					var includedOnlyMesh = scene.getMeshByID(light._includedOnlyMeshesIds[includedOnlyIndex]);
					
					if (includedOnlyMesh != null) {
						light.includedOnlyMeshes.push(includedOnlyMesh);
					}
				}
				
				light._includedOnlyMeshesIds = [];
			}
			
			if (!light.canAffectMesh(mesh)) {
				continue;
			}
			needNormals = true;
			
			defines.lights[lightIndex] = true;
			
			switch (light.type) {
				case "SPOTLIGHT":
					defines.spotlights[lightIndex] = true;
					
				case "POINTLIGHT":
					defines.pointlights[lightIndex] = true;
					
				case "DIRLIGHT":
					defines.dirlights[lightIndex] = true;
					
				case "HEMILIGHT":
					defines.hemilights[lightIndex] = true;
			}
			
			// Specular
			if (!light.specular.equalsFloats(0, 0, 0) && SPECULARTERM > -1) {
				defines.defines[SPECULARTERM] = true;
			}
			
			// Shadows
			if (scene.shadowsEnabled) {
				var shadowGenerator = light.getShadowGenerator();
				if (mesh != null && mesh.receiveShadows && shadowGenerator != null) {
					defines.shadows[lightIndex] = true; 
					
					defines.defines[SHADOWS] = true;
					
					if (shadowGenerator.useVarianceShadowMap || shadowGenerator.useBlurVarianceShadowMap) {
						defines.shadowvsms[lightIndex] = true;
					}
					
					if (shadowGenerator.usePoissonSampling) {
						defines.shadowpcfs[lightIndex] = true;
					}
					
					needShadows = true;
				}
			}
			
			lightIndex++;
			if (lightIndex == maxSimultaneousLights) {
				break;
			}
		}
		
		if (needShadows && scene.getEngine().getCaps().textureFloat == true && scene.getEngine().getCaps().textureFloatLinearFiltering == true && SHADOWFULLFLOAT != -1) {
			defines.defines[SHADOWFULLFLOAT] = true;
		}
		
		return needNormals;
	}
	
	public static function PrepareUniformsAndSamplersList(uniformsList:Array<String>, samplersList:Array<String>, lights:Array<Bool>, maxSimultaneousLights:Int = 4) {
		for (lightIndex in 0...maxSimultaneousLights) {
			if (!lights[lightIndex]) {
				break;
			}
			
			uniformsList.push("vLightData" + lightIndex);
			uniformsList.push("vLightDiffuse" + lightIndex);
			uniformsList.push("vLightSpecular" + lightIndex);
			uniformsList.push("vLightDirection" + lightIndex);
			uniformsList.push("vLightGround" + lightIndex);
			uniformsList.push("lightMatrix" + lightIndex);
			uniformsList.push("shadowsInfo" + lightIndex);
			
			samplersList.push("shadowSampler" + lightIndex);
		}
	}

	public static function HandleFallbacksForShadows(defines:MaterialDefines, fallbacks:EffectFallbacks, maxSimultaneousLights:Int = 4) {
		for (lightIndex in 0...maxSimultaneousLights) {
			if (!defines.lights[lightIndex]) {
				continue;
			}
			
			if (lightIndex > 0) {
				fallbacks.addFallback(lightIndex, "LIGHT" + lightIndex);
			}
			
			if (defines.shadows[lightIndex]) {
				fallbacks.addFallback(0, "SHADOW" + lightIndex);
			}
			
			if (defines.shadowpcfs[lightIndex]) {
				fallbacks.addFallback(0, "SHADOWPCF" + lightIndex);
			}
			
			if (defines.shadowvsms[lightIndex]) {
				fallbacks.addFallback(0, "SHADOWVSM" + lightIndex);
			}
		}
	}

	inline public static function PrepareAttributesForBones(attribs:Array<String>, mesh:AbstractMesh, numBoneInfluencers:Int, fallbacks:EffectFallbacks) {
		if (numBoneInfluencers > 0) {
			fallbacks.addCPUSkinningFallback(0, mesh);
			
			attribs.push(VertexBuffer.MatricesIndicesKind);
			attribs.push(VertexBuffer.MatricesWeightsKind);
			if (numBoneInfluencers > 4) {
				attribs.push(VertexBuffer.MatricesIndicesExtraKind);
				attribs.push(VertexBuffer.MatricesWeightsExtraKind);
			}
		}
	}

	public static function PrepareAttributesForInstances(attribs:Array<String>, defines:Vector<Bool>, INSTANCES:Int) {
		if (defines[INSTANCES]) {
			attribs.push("world0");
			attribs.push("world1");
			attribs.push("world2");
			attribs.push("world3");
		}
	}

	// Bindings
	public static function BindLightShadow(light:Light, scene:Scene, mesh:AbstractMesh, lightIndex:Int, effect:Effect, depthValuesAlreadySet:Bool):Bool {
		var shadowGenerator = light.getShadowGenerator();
		if (mesh.receiveShadows && shadowGenerator != null) {
			if (!cast(light, IShadowLight).needCube()) {
				effect.setMatrix("lightMatrix" + lightIndex, shadowGenerator.getTransformMatrix());
			} 
			else {
				if (!depthValuesAlreadySet) {
					depthValuesAlreadySet = true;
					effect.setFloat2("depthValues", scene.activeCamera.minZ, scene.activeCamera.maxZ);
				}
			}
			
			effect.setTexture("shadowSampler" + lightIndex, shadowGenerator.getShadowMapForRendering());
			effect.setFloat3("shadowsInfo" + lightIndex, shadowGenerator.getDarkness(), shadowGenerator.blurScale / shadowGenerator.getShadowMap().getSize().width, shadowGenerator.bias);
		}
		
		return depthValuesAlreadySet;
	}
	
	inline public static function BindLightProperties(light:Light, effect:Effect, lightIndex:Int) {
		switch (light.type) {
			case "POINTLIGHT":
				light.transferToEffect(effect, "vLightData" + lightIndex);
				
			case "DIRLIGHT":
				light.transferToEffect(effect, "vLightData" + lightIndex);
				
			case "SPOTLIGHT":
				light.transferToEffect(effect, "vLightData" + lightIndex, "vLightDirection" + lightIndex);
				
			case "HEMILIGHT":
				light.transferToEffect(effect, "vLightData" + lightIndex, "vLightGround" + lightIndex);			
		}
	}

	public static function BindLights(scene:Scene, mesh:AbstractMesh, effect:Effect, specularTerm:Bool, maxSimultaneousLights:Int = 4) {
		var lightIndex:Int = 0;
		var depthValuesAlreadySet:Bool = false;
		for (index in 0...scene.lights.length) {
			var light = scene.lights[index];
			
			if (!light.isEnabled()) {
				continue;
			}
			
			if (!light.canAffectMesh(mesh)) {
				continue;
			}
			
			BindLightProperties(light, effect, lightIndex);
			
			light.diffuse.scaleToRef(light.intensity, Tmp.color3[0]);
			effect.setColor4("vLightDiffuse" + lightIndex, Tmp.color3[0], light.range);
			if (specularTerm) {
				light.specular.scaleToRef(light.intensity, Tmp.color3[1]);
				effect.setColor3("vLightSpecular" + lightIndex, Tmp.color3[1]);
			}
			
			// Shadows
			if (scene.shadowsEnabled) {
				depthValuesAlreadySet = BindLightShadow(light, scene, mesh, lightIndex, effect, depthValuesAlreadySet);
			}
			
			lightIndex++;
			
			if (lightIndex == maxSimultaneousLights) {
				break;
			}
		}
	}

	inline public static function BindFogParameters(scene:Scene, mesh:AbstractMesh, effect:Effect) {
		if (scene.fogEnabled && mesh.applyFog && scene.fogMode != Scene.FOGMODE_NONE) {
			effect.setFloat4("vFogInfos", scene.fogMode, scene.fogStart, scene.fogEnd, scene.fogDensity);
			effect.setColor3("vFogColor", scene.fogColor);
		}
	}
	
	inline public static function BindBonesParameters(mesh:AbstractMesh, effect:Effect) {
		if (mesh != null && mesh.useBones && mesh.computeBonesUsingShaders) {
			effect.setMatrices("mBones", mesh.skeleton.getTransformMatrices(cast mesh));
		}
	}
	
	inline public static function BindLogDepth(logarithmicDepth:Bool, effect:Effect, scene:Scene) {
        if (logarithmicDepth) {
            effect.setFloat("logarithmicDepthConstant", 2.0 / (Math.log(scene.activeCamera.maxZ + 1.0) / 0.6931471805599453));  // Math.LN2
        }
    }

    inline public static function BindClipPlane(effect:Effect, scene:Scene) {
        if (scene.clipPlane != null) {
            var clipPlane = scene.clipPlane;
            effect.setFloat4("vClipPlane", clipPlane.normal.x, clipPlane.normal.y, clipPlane.normal.z, clipPlane.d);
        }
    }
	
}
