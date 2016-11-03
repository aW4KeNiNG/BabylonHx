package com.babylonhx.particles;

import com.babylonhx.IDisposable;
import com.babylonhx.math.Tmp;
import com.babylonhx.Scene;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Color4;
import com.babylonhx.math.Axis;
import com.babylonhx.math.Matrix;
import com.babylonhx.math.Quaternion;
import com.babylonhx.culling.BoundingInfo;
import com.babylonhx.cameras.Camera;
import com.babylonhx.mesh.Mesh;
import com.babylonhx.mesh.VertexData;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.mesh.MeshBuilder;
import com.babylonhx.utils.typedarray.Float32Array;


/**
 * ...
 * @author Krtolica Vujadin
 */

typedef SolidParticleOptions = {
	?updatable:Bool,
	?isPickable:Bool
}

typedef PickedParticle = {
	idx:Int,
	faceId:Int
}
 
class SolidParticleSystem implements IDisposable {
	
	// public members 
	/**
	*  The SPS array of Solid Particle objects. Just access each particle as with any classic array.
	*  Example : var p = SPS.particles[i];
	*/
	public var particles:Array<SolidParticle> = [];
	/**
	* The SPS total number of particles. Read only. Use SPS.counter instead if you need to set your own value.
	*/
	public var nbParticles:Int = 0;
	/**
	* If the particles must ever face the camera (default false). Useful for planar particles.
	*/
	public var billboard:Bool = false;
	/**
	 * Recompute normals when adding a shape
	 */
	public var recomputeNormals:Bool = true;
	/**
	* This a counter ofr your own usage. It's not set by any SPS functions.
	*/
	public var counter:Int = 0;
	/**
	* The SPS name. This name is also given to the underlying mesh.
	*/
	public var name:String;
	/**
	* The SPS mesh. It's a standard BJS Mesh, so all the methods from the Mesh class are avalaible.
	*/
	public var mesh:Mesh;
	/**
	* This empty object is intended to store some SPS specific or temporary values in order to lower the Garbage Collector activity.
	* Please read : http://doc.babylonjs.com/tutorials/Solid_Particle_System#garbage-collector-concerns
	*/
	public var vars:Dynamic = { };
	/**
	* This array is populated when the SPS is set as 'pickable'.
	* Each key of this array is a faceId value that you can get from a pickResult object.
	* Each element of this array is an object {idx: int, faceId: int}.
	* idx is the picked particle index in the SPS.particles array
	* faceId is the picked face index counted within this particles
	* Please read : http://doc.babylonjs.com/tutorials/Solid_Particle_System#pickable-particles
	*/
	public var pickedParticles:Array<PickedParticle> = [];
	
	// private members
	private var _scene:Scene;
	private var _positions:Array<Float> = [];
	private var _indices:Array<Int> = [];
	private var _normals:Array<Float> = [];
	private var _colors:Array<Float> = [];
	private var _uvs:Array<Float> = [];
	//private var _positions32:Float32Array;
	//private var _normals32:Float32Array;		// updated normals for the VBO
	//private var _fixedNormal32:Float32Array;	// initial normal references
	//private var _colors32:Float32Array;			
	//private var _uvs32:Float32Array;			
	private var _index:Int = 0;  // indices index
	private var _updatable:Bool = true;
	private var _pickable:Bool = false;
	private var _isVisibilityBoxLocked:Bool = false;
	private var _alwaysVisible:Bool = false;
	private var _shapeCounter:Int = 0;
	private var _copy:SolidParticle = new SolidParticle(null, null, null, null, null);
	private var _shape:Array<Vector3>;
	private var _shapeUV:Array<Float>;
	private var _color:Color4 = new Color4(0, 0, 0, 0);
	private var _computeParticleColor:Bool = true;
	private var _computeParticleTexture:Bool = true;
	private var _computeParticleRotation:Bool = true;
	private var _computeParticleVertex:Bool = false;
	private var _computeBoundingBox:Bool = false;
	private var _cam_axisZ:Vector3 = Vector3.Zero();
	private var _cam_axisY:Vector3 = Vector3.Zero();
	private var _cam_axisX:Vector3 = Vector3.Zero();
	private var _axisX:Vector3 = Axis.X;
	private var _axisY:Vector3 = Axis.Y;
	private var _axisZ:Vector3 = Axis.Z;
	private var _camera:Camera;
	private var _particle:SolidParticle;
	private var _camDir:Vector3 = Vector3.Zero();
	private var _rotMatrix:Matrix = new Matrix();
	private var _invertMatrix:Matrix = new Matrix();
	private var _rotated:Vector3 = Vector3.Zero();
	private var _quaternion:Quaternion = new Quaternion();
	private var _vertex:Vector3 = Vector3.Zero();
	private var _normal:Vector3 = Vector3.Zero();
	private var _yaw:Float = 0.0;
	private var _pitch:Float = 0.0;
	private var _roll:Float = 0.0;
	private var _halfroll:Float = 0.0;
	private var _halfpitch:Float = 0.0;
	private var _halfyaw:Float = 0.0;
	private var _sinRoll:Float = 0.0;
	private var _cosRoll:Float = 0.0;
	private var _sinPitch:Float = 0.0;
	private var _cosPitch:Float = 0.0;
	private var _sinYaw:Float = 0.0;
	private var _cosYaw:Float = 0.0;
	private var _w:Float = 0.0;
	private var _minimum:Vector3 = Tmp.vector3[0];
    private var _maximum:Vector3 = Tmp.vector3[1];
	private var _scale:Vector3 = Tmp.vector3[2];
	private var _translation:Vector3 = Tmp.vector3[3];
	private var _minBbox:Vector3 = Tmp.vector3[4];
    private var _maxBbox:Vector3 = Tmp.vector3[5];
	private var _particlesIntersect:Bool = false;
	
	public var isAlwaysVisible(get, set):Bool;
	
	public var computeParticleColor(get, set):Bool;
	public var computeParticleTexture(get, set):Bool;
	public var computeParticleRotation(get, set):Bool;
	public var computeParticleVertex(get, set):Bool;
	public var computeBoundingBox(get, set):Bool;
	
	
	/**
	* Creates a SPS (Solid Particle System) object.
	* @param name the SPS name, this will be the underlying mesh name
	* @param scene the scene in which the SPS is added
	* @param options "updatable" (default true) : if the SPS must be updatable or immutable, "isPickable" (default false) : if the solid particles must be pickable
	*/
	public function new(name:String, scene:Scene, ?options:SolidParticleOptions) {
		this.name = name;
		this._scene = scene;
		this._camera = scene.activeCamera;
		
		this._pickable = options != null && options.isPickable != null ? options.isPickable : false;
		this._updatable = options != null && options.updatable != null ? options.updatable : true;
		
		if (this._pickable) {
			this.pickedParticles = [];
		}
	}
	
	/**
	* Builds the SPS underlying mesh. Returns a standard Mesh.
	* If no model shape was added to the SPS, the return mesh is only a single triangular plane.
	*/
	public function buildMesh():Mesh {
		if (this.nbParticles == 0) {
			var triangle = MeshBuilder.CreateDisc("", { radius: 1, tessellation: 3 }, this._scene);
			this.addShape(triangle, 1);
			triangle.dispose();
		}
		
		/*this._positions32 = new Float32Array(this._positions);
		this._uvs32 = new Float32Array(this._uvs);
		this._colors32 = new Float32Array(this._colors);*/
		if (this.recomputeNormals) {
			VertexData.ComputeNormals(this._positions, this._indices, this._normals);
		}
		/*this._normals32 = new Float32Array(this._normals);*/
		//this._fixedNormal32 = new Float32Array(this._normals);
		
		var vertexData:VertexData = new VertexData();
		vertexData.set(this._positions, VertexBuffer.PositionKind);
		vertexData.indices = this._indices;
		vertexData.set(this._normals, VertexBuffer.NormalKind);
		/*if (this._uvs32 != null) {
			vertexData.set(this._uvs, VertexBuffer.UVKind);
		}
		if (this._colors32 != null) {
			vertexData.set(this._colors, VertexBuffer.ColorKind);
		}*/
		if (this._uvs != null) {
			vertexData.set(this._uvs, VertexBuffer.UVKind);
		}
		if (this._colors != null) {
			vertexData.set(this._colors, VertexBuffer.ColorKind);
		}
		var mesh = new Mesh(name, this._scene);
		vertexData.applyToMesh(mesh, this._updatable);
		this.mesh = mesh;
		this.mesh.isPickable = this._pickable;
		
		// free memory
		/*this._positions = null;
		this._normals = null;
		this._uvs = null;
		this._colors = null;*/
		
		if (!this._updatable) {
			this.particles.splice(0, this.particles.length - 1); // = [];
		}
		
		return mesh;
	}
	
	/**
	* Digests the mesh and generates as many solid particles in the system as wanted.
	* These particles will have the same geometry than the mesh parts and will be positioned at the same localisation than the mesh original places.
	* Thus the particles generated from digest() have their property "position" yet set.
	* @param mesh the mesh to be digested
	* @param facetNb the number of mesh facets per particle (optional, default 1), this parameter is overriden by the parameter "number" if any
	* @param delta the random extra number of facets per partical (optional, default 0), each particle will have between facetNb and facetNb + delta facets
	* @param number the wanted number of particles : each particle is built with mesh_total_facets / number facets (optional)
	*/
	public function digest(mesh:Mesh, ?options:Dynamic) {
		var size:Int = (options != null && options.facetNb != null) ? options.facetNb : 1;
		var number:Int = (options != null && options.number != null) ? options.number : -1;
		var delta:Int = (options != null && options.delta != null) ? options.delta : 0;
		var meshPos = mesh.getVerticesData(VertexBuffer.PositionKind);
		var meshInd = mesh.getIndices();
		var meshUV = mesh.getVerticesData(VertexBuffer.UVKind);
		var meshCol = mesh.getVerticesData(VertexBuffer.ColorKind);
		var meshNor = mesh.getVerticesData(VertexBuffer.NormalKind);
		
		var f:Int = 0;                              		 // facet counter
		var totalFacets:Int = Std.int(meshInd.length / 3);   // a facet is a triangle, so 3 indices
		// compute size from number
		if (number != -1) {
			number = (number > totalFacets) ? totalFacets : number;
			size = Math.round(totalFacets / number);
			delta = 0;
		} 
		else {
			size = (size > totalFacets) ? totalFacets : size;
		}
		
		var facetPos:Array<Float> = [];      // submesh positions
		var facetInd:Array<Int> = [];        // submesh indices
		var facetUV:Array<Float> = [];       // submesh UV
		var facetCol:Array<Float> = [];      // submesh colors
		var barycenter:Vector3 = Tmp.vector3[0];
		var rand:Int = 0;
		var size0:Int = size;
		
		while (f < totalFacets) {
			size = size0 + Math.floor((1 + delta) * Math.random());
			if (f > totalFacets - size) {
				size = totalFacets - f;
			}
			// reset temp arrays
			facetPos.splice(0, facetPos.length - 1);
			facetInd.splice(0, facetInd.length - 1);
			facetUV.splice(0, facetUV.length - 1);
			facetCol.splice(0, facetCol.length - 1);
			
			// iterate over "size" facets
			var fi:Int = 0;
			for (j in f * 3...(f + size) * 3) {
				facetInd.push(fi);
				var i:Int = meshInd[j];
				facetPos.push(meshPos[i * 3]);
				facetPos.push(meshPos[i * 3 + 1]);
				facetPos.push(meshPos[i * 3 + 2]);
				if (meshUV != null && meshUV.length > 0) {
					facetUV.push(meshUV[i * 2]);
					facetUV.push(meshUV[i * 2 + 1]);
				}
				if (meshCol != null && meshCol.length > 0) {
					facetCol.push(meshCol[i * 4]);
					facetCol.push(meshCol[i * 4 + 1]);
					facetCol.push(meshCol[i * 4 + 2]);
					facetCol.push(meshCol[i * 4 + 3]);
				}
				fi++;
			}
			
			// create a model shape for each single particle
			var idx:Int = this.nbParticles;
			var shape:Array<Vector3> = this._posToShape(facetPos);
			var shapeUV:Array<Float> = this._uvsToShapeUV(facetUV);
			
			// compute the barycenter of the shape
			for (v in 0...shape.length) {
				barycenter.addInPlace(shape[v]);
			}
			barycenter.scaleInPlace(1 / shape.length);
			
			// shift the shape from its barycenter to the origin
			for (v in 0...shape.length) {
				shape[v].subtractInPlace(barycenter);
			}
			var bInfo:BoundingInfo = null;
            if (this._particlesIntersect) {
                bInfo = new BoundingInfo(barycenter, barycenter);
            }
			var modelShape = new ModelShape(this._shapeCounter, shape, shapeUV, null, null);
			
			// add the particle in the SPS
			this._meshBuilder(this._index, shape, this._positions, facetInd, this._indices, facetUV, this._uvs, facetCol, this._colors, meshNor, this._normals, idx, 0, null);
			this._addParticle(idx, this._positions.length, modelShape, this._shapeCounter, 0, bInfo);
			// initialize the particle position
			this.particles[this.nbParticles].position.addInPlace(barycenter);
			
			this._index += shape.length;
			idx++;
			this.nbParticles++;
			this._shapeCounter++;
			f += size;
		}
	}
	
	//reset copy
	private function _resetCopy() {
		this._copy.position.x = 0;
		this._copy.position.y = 0;
		this._copy.position.z = 0;
		this._copy.rotation.x = 0;
		this._copy.rotation.y = 0;
		this._copy.rotation.z = 0;
		this._copy.rotationQuaternion = null;
		this._copy.scaling.x = 1;
		this._copy.scaling.y = 1;
		this._copy.scaling.z = 1;
		this._copy.uvs.x = 0;
		this._copy.uvs.y = 0;
		this._copy.uvs.z = 1;
		this._copy.uvs.w = 1;
		this._copy.color = null;
	}

	// _meshBuilder : inserts the shape model in the global SPS mesh
	private function _meshBuilder(p:Int, shape:Array<Vector3>, positions:Array<Float>, meshInd:Array<Int>, indices:Array<Int>, meshUV:Array<Float>, uvs:Array<Float>, meshCol:Array<Float>, colors:Array<Float>, meshNor:Array<Float>, normals:Array<Float>, idx:Int, idxInShape:Int, ?options:Dynamic) {
		var u:Int = 0;
		var c:Int = 0;
		var n:Int = 0;
		
		this._resetCopy();
		if (options != null && options.positionFunction != null) {        // call to custom positionFunction
			options.positionFunction(this._copy, p, idxInShape);
		}
		
		if (this._copy.rotationQuaternion != null) {
			this._quaternion.x = this._copy.rotationQuaternion.x;
			this._quaternion.y = this._copy.rotationQuaternion.y;
			this._quaternion.z = this._copy.rotationQuaternion.z;
			this._quaternion.w = this._copy.rotationQuaternion.w;
		} 
		else {
			this._yaw = this._copy.rotation.y;
			this._pitch = this._copy.rotation.x;
			this._roll = this._copy.rotation.z;
			this._quaternionRotationYPR();
		}
		this._quaternionToRotationMatrix();
		
		for (i in 0...shape.length) {
			this._vertex.x = shape[i].x;
			this._vertex.y = shape[i].y;
			this._vertex.z = shape[i].z;
			
			if (options != null && options.vertexFunction != null) {
				options.vertexFunction(this._copy, this._vertex, i);
			}
			
			this._vertex.x *= this._copy.scaling.x;
			this._vertex.y *= this._copy.scaling.y;
			this._vertex.z *= this._copy.scaling.z;
			
			Vector3.TransformCoordinatesToRef(this._vertex, this._rotMatrix, this._rotated);
			positions.push(this._copy.position.x + this._rotated.x);
			positions.push(this._copy.position.y + this._rotated.y);
			positions.push(this._copy.position.z + this._rotated.z);
			
			if (meshUV != null) {
				uvs.push((this._copy.uvs.z - this._copy.uvs.x) * meshUV[u] + this._copy.uvs.x);
				uvs.push((this._copy.uvs.w - this._copy.uvs.y) * meshUV[u + 1] + this._copy.uvs.y);
				u += 2;
			}
			
			if (this._copy.color != null) {
				this._color = this._copy.color;
			} 
			else if (meshCol != null) {
				this._color.r = meshCol[c];
				this._color.g = meshCol[c + 1];
				this._color.b = meshCol[c + 2];
				this._color.a = meshCol[c + 3];
			} 
			else {
				this._color.r = 1;
				this._color.g = 1;
				this._color.b = 1;
				this._color.a = 1;
			}
			
			colors.push(this._color.r);
			colors.push(this._color.g);
			colors.push(this._color.b);
			colors.push(this._color.a);
			c += 4;
			
			if (!this.recomputeNormals && meshNor != null) {
                this._normal.x = meshNor[n];
                this._normal.y = meshNor[n + 1];
                this._normal.z = meshNor[n + 2];
                Vector3.TransformCoordinatesToRef(this._normal, this._rotMatrix, this._normal);
                normals.push(this._normal.x);
				normals.push(this._normal.y);
				normals.push(this._normal.z);
                n += 3;
            }
		}
		
		for (i in 0...meshInd.length) {
			indices.push(p + meshInd[i]);
		}
		
		if (this._pickable) {
			var nbfaces = Std.int(meshInd.length / 3);
			for (i in 0...nbfaces) {
				this.pickedParticles.push({ idx: idx, faceId: i });
			}
		}
	}

	// returns a shape array from positions array
	private function _posToShape(positions:Array<Float>):Array<Vector3> {
		var shape:Array<Vector3> = [];
		var i:Int = 0;
		while (i < positions.length) {
			shape.push(new Vector3(positions[i], positions[i + 1], positions[i + 2]));
			i += 3;
		}
		
		return shape;
	}

	// returns a shapeUV array from a Vector4 uvs
	private function _uvsToShapeUV(uvs:Array<Float>):Array<Float> {
		var shapeUV:Array<Float> = [];
		if (uvs != null) {
			for (i in 0...uvs.length) {
				shapeUV.push(uvs[i]);
			}
		}
		
		return shapeUV;
	}

	// adds a new particle object in the particles array
	private function _addParticle(idx:Int, idxpos:Int, model:ModelShape, shapeId:Int, idxInShape:Int, ?bInfo:BoundingInfo) {
		this.particles.push(new SolidParticle(idx, idxpos, model, shapeId, idxInShape, bInfo));
	}

	/**
	* Adds sosme particles to the SPS from the model shape.
	* Please read the doc : http://doc.babylonjs.com/tutorials/Solid_Particle_System#create-an-immutable-sps
	* @param mesh any Mesh object that will be used as a model for the solid particles.
	* @param nb the number of particles to be created from this model
	* @param positionFunction an optional javascript function to called for each particle on SPS creation
	* @param vertexFunction an optional javascript function to called for each vertex of each particle on SPS creation
	*/
	public function addShape(mesh:Mesh, nb:Int, ?options:Dynamic):Int {
		var meshPos:Array<Float> = mesh.getVerticesData(VertexBuffer.PositionKind);
		var meshInd:Array<Int> = mesh.getIndices();
		var meshUV:Array<Float> = mesh.getVerticesData(VertexBuffer.UVKind);
		var meshCol:Array<Float> = mesh.getVerticesData(VertexBuffer.ColorKind);
		var meshNor:Array<Float> = mesh.getVerticesData(VertexBuffer.NormalKind);
		
		var shape:Array<Vector3> = this._posToShape(meshPos);
		var shapeUV:Array<Float> = this._uvsToShapeUV(meshUV);
		
		var posfunc = options != null ? options.positionFunction : null;
		var vtxfunc = options != null ? options.vertexFunction : null;
		
		var modelShape = new ModelShape(this._shapeCounter, shape, shapeUV, posfunc, vtxfunc);
		
		// particles
		var idx = this.nbParticles;
		for (i in 0...nb) {
		    this._meshBuilder(this._index, shape, this._positions, meshInd, this._indices, meshUV, this._uvs, meshCol, this._colors, meshNor, this._normals, idx, i, options);
			if (this._updatable) {
				this._addParticle(idx, this._positions.length, modelShape, this._shapeCounter, i);
			}
			this._index += shape.length;
			idx++;
		}
		this.nbParticles += nb;
		this._shapeCounter++;
		
		return this._shapeCounter;
	}
	
	// rebuilds a particle back to its just built status : if needed, recomputes the custom positions and vertices
	private function _rebuildParticle(particle:SolidParticle) {
		this._resetCopy();
		if (particle._model._positionFunction != null) {        // recall to stored custom positionFunction
			particle._model._positionFunction(this._copy, particle.idx, particle.idxInShape);
		}
		
		if (this._copy.rotationQuaternion != null) {
			this._quaternion.x = this._copy.rotationQuaternion.x;
			this._quaternion.y = this._copy.rotationQuaternion.y;
			this._quaternion.z = this._copy.rotationQuaternion.z;
			this._quaternion.w = this._copy.rotationQuaternion.w;
		} 
		else {
			this._yaw = this._copy.rotation.y;
			this._pitch = this._copy.rotation.x;
			this._roll = this._copy.rotation.z;
			this._quaternionRotationYPR();
		}
		this._quaternionToRotationMatrix();
		
		this._shape = particle._model._shape;
		for (pt in 0...this._shape.length) {
			this._vertex.x = this._shape[pt].x;
			this._vertex.y = this._shape[pt].y;
			this._vertex.z = this._shape[pt].z;
			
			if (particle._model._vertexFunction != null) {
				particle._model._vertexFunction(this._copy, this._vertex, pt); // recall to stored vertexFunction
			}
			
			this._vertex.x *= this._copy.scaling.x;
			this._vertex.y *= this._copy.scaling.y;
			this._vertex.z *= this._copy.scaling.z;
			
			Vector3.TransformCoordinatesToRef(this._vertex, this._rotMatrix, this._rotated);
			
			this._positions[particle._pos + pt * 3] = this._copy.position.x + this._rotated.x;
			this._positions[particle._pos + pt * 3 + 1] = this._copy.position.y + this._rotated.y;
			this._positions[particle._pos + pt * 3 + 2] = this._copy.position.z + this._rotated.z;
		}
		
		particle.position.x = 0;
		particle.position.y = 0;
		particle.position.z = 0;
		particle.rotation.x = 0;
		particle.rotation.y = 0;
		particle.rotation.z = 0;
		particle.rotationQuaternion = null;
		particle.scaling.x = 1;
		particle.scaling.y = 1;
		particle.scaling.z = 1;
	}

	/**
	* Rebuilds the whole mesh and updates the VBO : custom positions and vertices are recomputed if needed.
	*/
	inline public function rebuildMesh() {
		for (p in 0...this.particles.length) {
			this._rebuildParticle(this.particles[p]);
		}
		this.mesh.updateVerticesData(VertexBuffer.PositionKind, this._positions, false, false);
	} 

	/**
	*  Sets all the particles : this method actually really updates the mesh according to the particle positions, rotations, colors, textures, etc.
	*  This method calls updateParticle() for each particles of the SPS.
	*  For an animated SPS, it is usually called within the render loop.
	* @param start (default 0) the particle index in the particle array where to start to compute the particle property values
	* @param end (default nbParticle - 1)  the particle index in the particle array where to stop to compute the particle property values
	* @param update (default true) if the mesh must be finally updated on this call after all the particle computations.
	*/
	public function setParticles(start:Int = 0, end:Int = -1, update:Bool = true) {
		if (!this._updatable) {
			return;
		}
		
		if (end == -1) {
			end = this.nbParticles - 1;
		}
		
		// custom beforeUpdate
		this.beforeUpdateParticles(start, end, update);
		
		this._cam_axisX.x = 1;
		this._cam_axisX.y = 0;
		this._cam_axisX.z = 0;
		
		this._cam_axisY.x = 0;
		this._cam_axisY.y = 1;
		this._cam_axisY.z = 0;
		
		this._cam_axisZ.x = 0;
		this._cam_axisZ.y = 0;
		this._cam_axisZ.z = 1;
		
		// if the particles will always face the camera
		if (this.billboard) {    
			// compute camera position and un-rotate it by the current mesh rotation
			if (this.mesh._worldMatrix.decompose(this._scale, this._quaternion, this._translation)) {
                this._quaternionToRotationMatrix();
                this._rotMatrix.invertToRef(this._invertMatrix);
                untyped this._camera._currentTarget.subtractToRef(this._camera.globalPosition, this._camDir);
                Vector3.TransformCoordinatesToRef(this._camDir, this._invertMatrix, this._cam_axisZ);
                this._cam_axisZ.normalize();
                // set two orthogonal vectors (_cam_axisX and and _cam_axisY) to the rotated camDir axis (_cam_axisZ)
                Vector3.CrossToRef(this._cam_axisZ, this._axisX, this._cam_axisY);
                Vector3.CrossToRef(this._cam_axisY, this._cam_axisZ, this._cam_axisX);
                this._cam_axisY.normalize();
                this._cam_axisX.normalize();
            }
		}
		
		Matrix.IdentityToRef(this._rotMatrix);
		var idx = 0;
		var index = 0;
		var colidx = 0;
		var colorIndex = 0;
		var uvidx = 0;
		var uvIndex = 0;
		var pt = 0;
		
		if (this._computeBoundingBox) {
			Vector3.FromFloatsToRef(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, this._minimum);
			Vector3.FromFloatsToRef(Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY, this._maximum);
		}
		
		// particle loop
		end = (end > this.nbParticles - 1) ? this.nbParticles - 1 : end;
		
		for (p in start...end + 1) {
			this._particle = this.particles[p];
			this._shape = this._particle._model._shape;
			this._shapeUV = this._particle._model._shapeUV;
			
			// call to custom user function to update the particle properties
			if (this.updateParticle != null) {
				this.updateParticle(this._particle);
			}
			
			if (this._particle.isVisible) {
				// particle rotation matrix
				if (this.billboard) {
					this._particle.rotation.x = 0.0;
					this._particle.rotation.y = 0.0;
				}
				if (this._computeParticleRotation || this.billboard) {
					if (this._particle.rotationQuaternion != null) {
						this._quaternion.copyFrom(this._particle.rotationQuaternion);
					} 
					else {
						this._yaw = this._particle.rotation.y;
						this._pitch = this._particle.rotation.x;
						this._roll = this._particle.rotation.z;
						this._quaternionRotationYPR();
					}
					this._quaternionToRotationMatrix();
				}
				
				// particle vertex loop
				for (pt in 0...this._shape.length) {
					idx = index + pt * 3;
					colidx = colorIndex + pt * 4;
					uvidx = uvIndex + pt * 2;
					
					this._vertex.x = this._shape[pt].x;
					this._vertex.y = this._shape[pt].y;
					this._vertex.z = this._shape[pt].z;
					
					if (this._computeParticleVertex) {
						this.updateParticleVertex(this._particle, this._vertex, pt);
					}
					
					// positions
					this._vertex.x *= this._particle.scaling.x;
					this._vertex.y *= this._particle.scaling.y;
					this._vertex.z *= this._particle.scaling.z;
					
					this._w = (this._vertex.x * this._rotMatrix.m[3]) + (this._vertex.y * this._rotMatrix.m[7]) + (this._vertex.z * this._rotMatrix.m[11]) + this._rotMatrix.m[15];
					this._rotated.x = ((this._vertex.x * this._rotMatrix.m[0]) + (this._vertex.y * this._rotMatrix.m[4]) + (this._vertex.z * this._rotMatrix.m[8]) + this._rotMatrix.m[12]) / this._w;
					this._rotated.y = ((this._vertex.x * this._rotMatrix.m[1]) + (this._vertex.y * this._rotMatrix.m[5]) + (this._vertex.z * this._rotMatrix.m[9]) + this._rotMatrix.m[13]) / this._w;
					this._rotated.z = ((this._vertex.x * this._rotMatrix.m[2]) + (this._vertex.y * this._rotMatrix.m[6]) + (this._vertex.z * this._rotMatrix.m[10]) + this._rotMatrix.m[14]) / this._w;
					
					this._positions[idx] = this._particle.position.x + this._cam_axisX.x * this._rotated.x + this._cam_axisY.x * this._rotated.y + this._cam_axisZ.x * this._rotated.z;
					this._positions[idx + 1] = this._particle.position.y + this._cam_axisX.y * this._rotated.x + this._cam_axisY.y * this._rotated.y + this._cam_axisZ.y * this._rotated.z;
					this._positions[idx + 2] = this._particle.position.z + this._cam_axisX.z * this._rotated.x + this._cam_axisY.z * this._rotated.y + this._cam_axisZ.z * this._rotated.z;
					
					if (this._computeBoundingBox) {
						if (this._positions[idx] < this._minimum.x) {
							this._minimum.x = this._positions[idx];
						}
						if (this._positions[idx] > this._maximum.x) {
							this._maximum.x = this._positions[idx];
						}
						if (this._positions[idx + 1] < this._minimum.y) {
							this._minimum.y = this._positions[idx + 1];
						}
						if (this._positions[idx + 1] > this._maximum.y) {
							this._maximum.y = this._positions[idx + 1];
						}
						if (this._positions[idx + 2] < this._minimum.z) {
							this._minimum.z = this._positions[idx + 2];
						}
						if (this._positions[idx + 2] > this._maximum.z) {
							this._maximum.z = this._positions[idx + 2];
						}
					}
					
					// normals : if the particles can't be morphed then just rotate the normals, what if much more faster than ComputeNormals()
					if (!this._computeParticleVertex && !this.billboard) {
						this._normal.x = this._normals[idx];
						this._normal.y = this._normals[idx + 1];
						this._normal.z = this._normals[idx + 2];
						
						this._w = (this._normal.x * this._rotMatrix.m[3]) + (this._normal.y * this._rotMatrix.m[7]) + (this._normal.z * this._rotMatrix.m[11]) + this._rotMatrix.m[15];
						this._rotated.x = ((this._normal.x * this._rotMatrix.m[0]) + (this._normal.y * this._rotMatrix.m[4]) + (this._normal.z * this._rotMatrix.m[8]) + this._rotMatrix.m[12]) / this._w;
						this._rotated.y = ((this._normal.x * this._rotMatrix.m[1]) + (this._normal.y * this._rotMatrix.m[5]) + (this._normal.z * this._rotMatrix.m[9]) + this._rotMatrix.m[13]) / this._w;
						this._rotated.z = ((this._normal.x * this._rotMatrix.m[2]) + (this._normal.y * this._rotMatrix.m[6]) + (this._normal.z * this._rotMatrix.m[10]) + this._rotMatrix.m[14]) / this._w;
						
						this._normals[idx] = this._cam_axisX.x * this._rotated.x + this._cam_axisY.x * this._rotated.y + this._cam_axisZ.x * this._rotated.z;
						this._normals[idx + 1] = this._cam_axisX.y * this._rotated.x + this._cam_axisY.y * this._rotated.y + this._cam_axisZ.y * this._rotated.z;
						this._normals[idx + 2] = this._cam_axisX.z * this._rotated.x + this._cam_axisY.z * this._rotated.y + this._cam_axisZ.z * this._rotated.z;
					}
					
					if (this._computeParticleColor) {
						this._colors[colidx] = this._particle.color.r;
						this._colors[colidx + 1] = this._particle.color.g;
						this._colors[colidx + 2] = this._particle.color.b;
						this._colors[colidx + 3] = this._particle.color.a;
					}
					
					if (this._computeParticleTexture) {
						this._uvs[uvidx] = this._shapeUV[pt * 2] * (this._particle.uvs.z - this._particle.uvs.x) + this._particle.uvs.x;
						this._uvs[uvidx + 1] = this._shapeUV[pt * 2 + 1] * (this._particle.uvs.w - this._particle.uvs.y) + this._particle.uvs.y;
					}
				}				
			} 
			// particle not visible : scaled to zero and positioned to the camera position
			else {
				for (pt in 0...this._shape.length) {
					idx = index + pt * 3;
					colidx = colorIndex + pt * 4;
					uvidx = uvIndex + pt * 2;
					this._positions[idx] = this._camera.position.x;
					this._positions[idx + 1] = this._camera.position.y;
					this._positions[idx + 2] = this._camera.position.z;
					this._normals[idx] = 0.0;
					this._normals[idx + 1] = 0.0;
					this._normals[idx + 2] = 0.0;
					if (this._computeParticleColor) {
						this._colors[colidx] = this._particle.color.r;
						this._colors[colidx + 1] = this._particle.color.g;
						this._colors[colidx + 2] = this._particle.color.b;
						this._colors[colidx + 3] = this._particle.color.a;
					}
					if (this._computeParticleTexture) {
						this._uvs[uvidx] = this._shapeUV[pt * 2] * (this._particle.uvs.z - this._particle.uvs.x) + this._particle.uvs.x;
						this._uvs[uvidx + 1] = this._shapeUV[pt * 2 + 1] * (this._particle.uvs.w - this._particle.uvs.y) + this._particle.uvs.y;
					}
				}
			}
			
			// if the particle intersections must be computed : update the bbInfo
			if (this._particlesIntersect) {
				var bInfo = this._particle._boundingInfo;
				var bBox = bInfo.boundingBox;
				var bSphere = bInfo.boundingSphere;
				
				// place, scale and rotate the particle bbox within the SPS local system
				for (b in 0...bBox.vectors.length) {
					if (this._particle.isVisible) {
						this._vertex.x = this._particle._modelBoundingInfo.boundingBox.vectors[b].x * this._particle.scaling.x;
						this._vertex.y = this._particle._modelBoundingInfo.boundingBox.vectors[b].y * this._particle.scaling.y;
						this._vertex.z = this._particle._modelBoundingInfo.boundingBox.vectors[b].z * this._particle.scaling.z;
						this._w = (this._vertex.x * this._rotMatrix.m[3]) + (this._vertex.y * this._rotMatrix.m[7]) + (this._vertex.z * this._rotMatrix.m[11]) + this._rotMatrix.m[15];
						this._rotated.x = ((this._vertex.x * this._rotMatrix.m[0]) + (this._vertex.y * this._rotMatrix.m[4]) + (this._vertex.z * this._rotMatrix.m[8]) + this._rotMatrix.m[12]) / this._w;
						this._rotated.y = ((this._vertex.x * this._rotMatrix.m[1]) + (this._vertex.y * this._rotMatrix.m[5]) + (this._vertex.z * this._rotMatrix.m[9]) + this._rotMatrix.m[13]) / this._w;
						this._rotated.z = ((this._vertex.x * this._rotMatrix.m[2]) + (this._vertex.y * this._rotMatrix.m[6]) + (this._vertex.z * this._rotMatrix.m[10]) + this._rotMatrix.m[14]) / this._w;
						bBox.vectors[b].x = this._particle.position.x + this._cam_axisX.x * this._rotated.x + this._cam_axisY.x * this._rotated.y + this._cam_axisZ.x * this._rotated.z;
						bBox.vectors[b].y = this._particle.position.y + this._cam_axisX.y * this._rotated.x + this._cam_axisY.y * this._rotated.y + this._cam_axisZ.y * this._rotated.z;
						bBox.vectors[b].z = this._particle.position.z + this._cam_axisX.z * this._rotated.x + this._cam_axisY.z * this._rotated.y + this._cam_axisZ.z * this._rotated.z;
					}
					else {
						bBox.vectors[b].x = this._camera.position.x;
						bBox.vectors[b].y = this._camera.position.y;
						bBox.vectors[b].z = this._camera.position.z;
					}
				}
				// place and scale the particle bouding sphere in the SPS local system
				if (this._particle.isVisible) {
					this._minBbox.x = this._particle._modelBoundingInfo.minimum.x * this._particle.scaling.x;
                    this._minBbox.y = this._particle._modelBoundingInfo.minimum.y * this._particle.scaling.y;
                    this._minBbox.z = this._particle._modelBoundingInfo.minimum.z * this._particle.scaling.z;
                    this._maxBbox.x = this._particle._modelBoundingInfo.maximum.x * this._particle.scaling.x;
                    this._maxBbox.y = this._particle._modelBoundingInfo.maximum.y * this._particle.scaling.y;
                    this._maxBbox.z = this._particle._modelBoundingInfo.maximum.z * this._particle.scaling.z;
                    bSphere.center.x = this._particle.position.x + (this._minBbox.x + this._maxBbox.x) * 0.5;
                    bSphere.center.y = this._particle.position.y + (this._minBbox.y + this._maxBbox.y) * 0.5;
                    bSphere.center.z = this._particle.position.z + (this._minBbox.z + this._maxBbox.z) * 0.5;
				} 
				else {
					bSphere.center.x = this._camera.position.x;
					bSphere.center.y = this._camera.position.x;
					bSphere.center.z = this._camera.position.x;
					bSphere.radius = 0.0;                       
				}
				
				// then update the bbox and the bsphere into the world system
				bBox._update(this.mesh._worldMatrix);
				bSphere._update(this.mesh._worldMatrix);
			}
			
			// increment indexes for the next particle
			index = idx + 3;
			colorIndex = colidx + 4;
			uvIndex = uvidx + 2;
		}
		
		// if the VBO must be updated
		if (update) {
			if (this._computeParticleColor) {
				this.mesh.updateVerticesData(VertexBuffer.ColorKind, this._colors, false, false);
			}
			if (this._computeParticleTexture) {
				this.mesh.updateVerticesData(VertexBuffer.UVKind, this._uvs, false, false);
			}
			this.mesh.updateVerticesData(VertexBuffer.PositionKind, this._positions, false, false);
			if (!this.mesh.areNormalsFrozen) {
				if (this._computeParticleVertex || this.billboard) {
					// recompute the normals only if the particles can be morphed, update then also the normal reference array _fixedNormal32[]
					VertexData.ComputeNormals(this._positions, this._indices, this._normals);
				}
				this.mesh.updateVerticesData(VertexBuffer.NormalKind, this._normals, false, false);
			}
		}
		if (this._computeBoundingBox) {
			this.mesh._boundingInfo = new BoundingInfo(this._minimum, this._maximum);
			this.mesh._boundingInfo._update(this.mesh._worldMatrix);
		}
		this.afterUpdateParticles(start, end, update);
	}
	
	private function _quaternionRotationYPR() {
		this._halfroll = this._roll * 0.5;
		this._halfpitch = this._pitch * 0.5;
		this._halfyaw = this._yaw * 0.5;
		this._sinRoll = Math.sin(this._halfroll);
		this._cosRoll = Math.cos(this._halfroll);
		this._sinPitch = Math.sin(this._halfpitch);
		this._cosPitch = Math.cos(this._halfpitch);
		this._sinYaw = Math.sin(this._halfyaw);
		this._cosYaw = Math.cos(this._halfyaw);
		this._quaternion.x = (this._cosYaw * this._sinPitch * this._cosRoll) + (this._sinYaw * this._cosPitch * this._sinRoll);
		this._quaternion.y = (this._sinYaw * this._cosPitch * this._cosRoll) - (this._cosYaw * this._sinPitch * this._sinRoll);
		this._quaternion.z = (this._cosYaw * this._cosPitch * this._sinRoll) - (this._sinYaw * this._sinPitch * this._cosRoll);
		this._quaternion.w = (this._cosYaw * this._cosPitch * this._cosRoll) + (this._sinYaw * this._sinPitch * this._sinRoll);
	}
	
	private function _quaternionToRotationMatrix() {
		this._rotMatrix.m[0] = 1.0 - (2.0 * (this._quaternion.y * this._quaternion.y + this._quaternion.z * this._quaternion.z));
		this._rotMatrix.m[1] = 2.0 * (this._quaternion.x * this._quaternion.y + this._quaternion.z * this._quaternion.w);
		this._rotMatrix.m[2] = 2.0 * (this._quaternion.z * this._quaternion.x - this._quaternion.y * this._quaternion.w);
		this._rotMatrix.m[3] = 0;
		this._rotMatrix.m[4] = 2.0 * (this._quaternion.x * this._quaternion.y - this._quaternion.z * this._quaternion.w);
		this._rotMatrix.m[5] = 1.0 - (2.0 * (this._quaternion.z * this._quaternion.z + this._quaternion.x * this._quaternion.x));
		this._rotMatrix.m[6] = 2.0 * (this._quaternion.y * this._quaternion.z + this._quaternion.x * this._quaternion.w);
		this._rotMatrix.m[7] = 0;
		this._rotMatrix.m[8] = 2.0 * (this._quaternion.z * this._quaternion.x + this._quaternion.y * this._quaternion.w);
		this._rotMatrix.m[9] = 2.0 * (this._quaternion.y * this._quaternion.z - this._quaternion.x * this._quaternion.w);
		this._rotMatrix.m[10] = 1.0 - (2.0 * (this._quaternion.y * this._quaternion.y + this._quaternion.x * this._quaternion.x));
		this._rotMatrix.m[11] = 0;
		this._rotMatrix.m[12] = 0;
		this._rotMatrix.m[13] = 0;
		this._rotMatrix.m[14] = 0;
		this._rotMatrix.m[15] = 1.0;
	}

	/**
	* Disposes the SPS
	*/
	public function dispose(doNotRecurse:Bool = false) {
		this.mesh.dispose();
		this.vars = null;
		// drop references to internal big arrays for the GC
		this._positions = null;
		this._indices = null;
		this._normals = null;
		this._uvs = null;
		this._colors = null;
		//this._positions32 = null;
		//this._normals32 = null;
		//this._fixedNormal32 = null;
		//this._uvs32 = null;
		//this._colors32 = null;
		this.pickedParticles = null;
	}
	
	/**
	*  Visibilty helper : Recomputes the visible size according to the mesh bounding box
	* doc : http://doc.babylonjs.com/tutorials/Solid_Particle_System#sps-visibility
	*/
	inline public function refreshVisibleSize() {
		if (!this._isVisibilityBoxLocked) {
			this.mesh.refreshBoundingInfo();
		}
	}
	
	/** Visibility helper : Sets the size of a visibility box, this sets the underlying mesh bounding box.
	* @param size the size (float) of the visibility box
	* note : this doesn't lock the SPS mesh bounding box.
	* doc : http://doc.babylonjs.com/tutorials/Solid_Particle_System#sps-visibility
	*/
	inline public function setVisibilityBox(size:Float) {
		var vis = size / 2;
		this.mesh._boundingInfo = new BoundingInfo(new Vector3(-vis, -vis, -vis), new Vector3(vis, vis, vis));
	}

	// getter and setter
	/**
	* True if the SPS is set as always visible
	*/
	private function get_isAlwaysVisible():Bool {
		return this._alwaysVisible;
	}
	/**
	* Sets the SPS as always visible or not
	* doc : http://doc.babylonjs.com/tutorials/Solid_Particle_System#sps-visibility
	*/
	private function set_isAlwaysVisible(val:Bool):Bool {
		this._alwaysVisible = val;
		this.mesh.alwaysSelectAsActiveMesh = val;
		
		return val;
	}
	
	/**
	* Sets the SPS visibility box as locked or not. This enables/disables the underlying mesh bounding box updates.
	* doc : http://doc.babylonjs.com/tutorials/Solid_Particle_System#sps-visibility
	*/
	private function set_isVisibilityBoxLocked(val:Bool):Bool {
		this._isVisibilityBoxLocked = val;
		this.mesh.getBoundingInfo().isLocked = val;
		
		return val;
	}
	/**
	* True if the SPS visibility box is locked. The underlying mesh bounding box is then not updatable any more.
	*/
	private function get_isVisibilityBoxLocked():Bool {
		return this._isVisibilityBoxLocked;
	}

	// Optimizer setters
	/**
	* Tells to setParticle() to compute the particle rotations or not.
	* Default value : true. The SPS is faster when it's set to false.
	* Note : the particle rotations aren't stored values, so setting computeParticleRotation to false will prevents the particle to rotate.
	*/
	private function set_computeParticleRotation(val:Bool):Bool {
		return this._computeParticleRotation = val;
	}

	/**
	* Tells to setParticle() to compute the particle colors or not.
	* Default value : true. The SPS is faster when it's set to false.
	* Note : the particle colors are stored values, so setting computeParticleColor to false will keep yet the last colors set.
	*/
	private function set_computeParticleColor(val:Bool):Bool {
		return this._computeParticleColor = val;
	}

	/**
	* Tells to setParticle() to compute the particle textures or not.
	* Default value : true. The SPS is faster when it's set to false.
	* Note : the particle textures are stored values, so setting computeParticleTexture to false will keep yet the last colors set.
	*/
	private function set_computeParticleTexture(val:Bool):Bool {
		return this._computeParticleTexture = val;
	}

	/**
	* Tells to setParticle() to call the vertex function for each vertex of each particle, or not.
	* Default value : false. The SPS is faster when it's set to false.
	* Note : the particle custom vertex positions aren't stored values.
	*/
	private function set_computeParticleVertex(val:Bool):Bool {
		return this._computeParticleVertex = val;
	} 
	
	/**
	* Tells to setParticles() to compute or not the mesh bounding box when computing the particle positions.
	*/
	public function set_computeBoundingBox(val:Bool) {
		return this._computeBoundingBox = val;
	}

	// getters
	private function get_computeParticleRotation():Bool {
		return this._computeParticleRotation;
	}

	private function get_computeParticleColor():Bool {
		return this._computeParticleColor;
	}

	private function get_computeParticleTexture():Bool {
		return this._computeParticleTexture;
	}

	private function get_computeParticleVertex():Bool {
		return this._computeParticleVertex;
	} 
	
	private function get_computeBoundingBox():Bool {
		return this._computeBoundingBox;
	}
   

	// =======================================================================
	// Particle behavior logic
	// these following methods may be overwritten by the user to fit his needs


	/**
	* This function does nothing. It may be overwritten to set all the particle first values.
	* The SPS doesn't call this function, you may have to call it by your own.
	* doc : http://doc.babylonjs.com/overviews/Solid_Particle_System#particle-management
	*/
	public var initParticles:Void->Void;

	/**
	* This function does nothing. It may be overwritten to recycle a particle.
	* The SPS doesn't call this function, you may have to call it by your own.
	* doc : http://doc.babylonjs.com/overviews/Solid_Particle_System#particle-management
	*/
	public var recycleParticle:SolidParticle->SolidParticle;

	/**
	* Updates a particle : this function should  be overwritten by the user.
	* It is called on each particle by `setParticles()`. This is the place to code each particle behavior.
	* doc : http://doc.babylonjs.com/overviews/Solid_Particle_System#particle-management
	* ex : just set a particle position or velocity and recycle conditions
	*/
	public var updateParticle:SolidParticle->SolidParticle;

	/**
	* Updates a vertex of a particle : it can be overwritten by the user.
	* This will be called on each vertex particle by `setParticles()` if `computeParticleVertex` is set to true only.
	* @param particle the current particle
	* @param vertex the current index of the current particle
	* @param pt the index of the current vertex in the particle shape
	* doc : http://doc.babylonjs.com/overviews/Solid_Particle_System#update-each-particle-shape
	* ex : just set a vertex particle position
	*/
	public var updateParticleVertex:SolidParticle->Vector3->Int->Vector3;

	/**
	* This will be called before any other treatment by `setParticles()` and will be passed three parameters.
	* This does nothing and may be overwritten by the user.
	* @param start the particle index in the particle array where to stop to iterate, same than the value passed to setParticle()
	* @param stop the particle index in the particle array where to stop to iterate, same than the value passed to setParticle()
	* @param update the boolean update value actually passed to setParticles()
	*/
	public function beforeUpdateParticles(?start:Float, ?stop:Float, update:Bool = false) {
		
	}

	/**
	* This will be called  by `setParticles()` after all the other treatments and just before the actual mesh update.
	* This will be passed three parameters.
	* This does nothing and may be overwritten by the user.
	* @param start the particle index in the particle array where to stop to iterate, same than the value passed to setParticle()
	* @param stop the particle index in the particle array where to stop to iterate, same than the value passed to setParticle()
	* @param update the boolean update value actually passed to setParticles()
	*/
	public function afterUpdateParticles(?start:Float, ?stop:Float, ?update:Bool) {
		
	}
	
}
