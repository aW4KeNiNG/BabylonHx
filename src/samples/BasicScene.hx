package samples;

import com.babylonhx.cameras.Camera;
import com.babylonhx.cameras.WebVRFreeCamera;
import com.babylonhx.cameras.FreeCamera;
import com.babylonhx.lights.HemisphericLight;
import com.babylonhx.materials.StandardMaterial;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.layer.Layer;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Vector2;
import com.babylonhx.math.Space;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.Scene;
import com.babylonhx.Engine;
import com.babylonhx.mesh.VertexBuffer;

import com.babylonhx.animations.Animation;
import com.babylonhx.actions.ActionEvent;
import com.babylonhx.collisions.PickingInfo;

import com.babylonhx.tools.EventState;
import com.babylonhx.utils.Image;
import com.babylonhx.materials.textures.RawTexture;
import com.babylonhx.materials.textures.procedurals.standard.PlasmaProceduralTexture;
import com.babylonhx.materials.textures.procedurals.standard.SpiralProceduralTexture;
import com.babylonhx.materials.textures.procedurals.standard.CombustionProceduralTexture;
import com.babylonhx.materials.textures.procedurals.standard.ElectricProceduralTexture;
import com.babylonhx.materials.textures.procedurals.standard.VoronoiProceduralTexture;

import com.babylonhx.postprocess.NotebookDrawingsPostProcess;
import com.babylonhx.postprocess.WatercolorPostProcess;

/**
 * ...
 * @author Krtolica Vujadin
 */
class BasicScene {

	public function new(scene:Scene) {
		//var camera = new WebVRFreeCamera("camera1", new Vector3(0, 5, -10), scene);
		var camera = new FreeCamera("camera1", new Vector3(0, 5, -10), scene);
		camera.setTarget(Vector3.Zero());
		camera.attachControl();
		
		var light = new HemisphericLight("light1", new Vector3(1, 0.5, 0), scene);
		light.intensity = 1;
		
		var sphere = Mesh.CreateSphere("sphere1", 16, 2, scene);
		/*sphere.material = new StandardMaterial("mat", scene);
		untyped sphere.material.diffuseColor = new Color3(0.3, 0.34, 0.87);*/
		sphere.position.y = 1;
		
		var ground = Mesh.CreateGround("ground1", 26, 26, 2, scene);
		
		/*var plasmaMaterial = new StandardMaterial("mat", scene);
		var plasmaTexture = new PlasmaProceduralTexture("plasma", 512, scene);
		plasmaMaterial.diffuseTexture = plasmaTexture;
		
		sphere.material = ground.material = plasmaMaterial;*/
		
		/*var spiralMaterial = new StandardMaterial("mat", scene);
		var spiralTexture = new VoronoiProceduralTexture("spiral", 512, scene);
		spiralMaterial.diffuseTexture = spiralTexture;		
		sphere.material = ground.material = spiralMaterial;*/
		
		//var ndPP = new NotebookDrawingsPostProcess("notebookDrawings_PP", 1.0, camera);
		var wPP = new WatercolorPostProcess("watercolor_PP", 1.0, camera);
		
		var rotationAxis = new Vector3(1, 0, 0);
		var rotationAngle = 0.0;
		var rotationSpeed = 0.003;
		
		scene.getEngine().runRenderLoop(function () {
            scene.render();
			//sphere.rotate(rotationAxis, rotationAngle * rotationSpeed, Space.WORLD);
			//rotationAngle += 0.005;
        });
	}
	
}
