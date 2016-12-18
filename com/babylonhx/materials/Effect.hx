package com.babylonhx.materials;

import com.babylonhx.Engine;
import com.babylonhx.materials.textures.WebGLTexture;
import com.babylonhx.tools.Tools;
import com.babylonhx.math.Matrix;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Vector2;
import com.babylonhx.math.Vector3;
import com.babylonhx.math.Vector4;
import com.babylonhx.postprocess.PostProcess;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.utils.GL;
import com.babylonhx.utils.GL.GLUniformLocation;
import com.babylonhx.utils.GL.GLProgram;
import com.babylonhx.utils.GL.GLTexture;
import com.babylonhx.utils.typedarray.Float32Array;
import com.babylonhx.utils.typedarray.Int32Array;

using StringTools;


/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.Effect') class Effect {
	
	public var name:Dynamic;
	public var defines:String;
	public var onCompiled:Effect->Void;
	public var onError:Effect->String->Void;
	public var onBind:Effect->Void;
	
	public var isSupported(get, never):Bool;

	private var _engine:Engine;
	private var _uniformsNames:Array<String>;
	private var _samplers:Array<String>;
	private var _isReady:Bool = false;
	private var _compilationError:String = "";
	private var _attributesNames:Array<String>;
	private var _attributes:Array<Int>;
	private var _uniforms:Map<String, GLUniformLocation>;
	public var _key:String;
	private var _indexParameters:Dynamic;
	
	@:allow(com.babylonhx.Engine.dispose) 
	private var _program:GLProgram;
	
	private var _valueCache:Map<String, Array<Float>>;	
	private var _valueCacheMatrix:Map<String, Matrix>;	// VK: for matrices only
	

	public function new(baseName:Dynamic, attributesNames:Array<String>, uniformsNames:Array<String>, samplers:Array<String>, engine:Engine, ?defines:String, ?fallbacks:EffectFallbacks, ?onCompiled:Effect->Void, ?onError:Effect->String->Void, ?indexParameters:Dynamic) {
		this._engine = engine;
		this.name = baseName;
		this.defines = defines;
		this._uniformsNames = uniformsNames.concat(samplers);
		this._samplers = samplers;
		this._attributesNames = attributesNames;
		this._indexParameters = indexParameters;
		
		this.onError = onError;
		this.onCompiled = onCompiled;
		
		var vertex:String = baseName.vertex != null ? baseName.vertex : baseName;
        var fragment:String = baseName.fragment != null ? baseName.fragment : baseName;
		
        var vertexShaderUrl:String = "";
        if (vertex.charAt(0) == ".") {
            vertexShaderUrl = vertex;
        } 
		else {
            vertexShaderUrl = Engine.ShadersRepository + vertex;
        }
		
        var fragmentShaderUrl:String = "";
        if (fragment.charAt(0) == ".") {
            fragmentShaderUrl = fragment;
        } 
		else {
            fragmentShaderUrl = Engine.ShadersRepository + fragment;
        }
		
        var _vertexCode:String = "";
		var prepareEffect = function(_fragmentCode:String) {
			this._prepareEffect(_vertexCode, _fragmentCode, attributesNames, defines, fallbacks);					
			// Cache
			this._valueCache = new Map<String, Array<Float>>();
			this._valueCacheMatrix = new Map<String, Matrix>();
		};
		var getFragmentCode = function() {
			var _fragmentCode:String = "";
			if (ShadersStore.Shaders.exists(fragment + ".fragment")) {
				_fragmentCode = ShadersStore.Shaders.get(fragment + ".fragment");
				this._processIncludes(_fragmentCode, function(fragmentCodeWithIncludes:String) {
					_fragmentCode = fragmentCodeWithIncludes;
					prepareEffect(_fragmentCode);
				});
			} 
			else {
				Tools.LoadFile(fragmentShaderUrl + ".fragment.fx", function(content:String) {
					_fragmentCode = content;
					prepareEffect(_fragmentCode);
				}, "text");
			}
		};
		
        if (ShadersStore.Shaders.exists(vertex + ".vertex")) {
            _vertexCode = ShadersStore.Shaders.get(vertex + ".vertex");
			this._processIncludes(_vertexCode, function(vertexCodeWithIncludes:String) {
				_vertexCode = vertexCodeWithIncludes;
				getFragmentCode();
			});
        } 
		else {
			Tools.LoadFile(vertexShaderUrl + ".vertex.fx", function(content:String) {
				_vertexCode = content;				
				getFragmentCode();
			}, "text");
        }  
	}

	// Properties
	inline public function isReady():Bool {
		return this._isReady;
	}

	inline public function getProgram():GLProgram {
		return this._program;
	}

	inline public function getAttributesNames():Array<String> {
		return this._attributesNames;
	}

	inline public function getAttributeLocation(index:Int):Int {
		return this._attributes[index];
	}

	inline public function getAttributeLocationByName(name:String):Int {
		var index = this._attributesNames.indexOf(name);
		
		return this._attributes[index];
	}

	inline public function getAttributesCount():Int {
		return this._attributes.length;
	}

	inline public function getUniformIndex(uniformName:String):Int {
		return this._uniformsNames.indexOf(uniformName);
	}

	inline public function getUniform(uniformName:String):GLUniformLocation {
		#if (cpp && lime)
		return (this._uniforms.exists(uniformName) ? this._uniforms[uniformName] : -1);
		#else
		return this._uniforms[uniformName];
		#end
	}

	inline public function getSamplers():Array<String> {
		return this._samplers;
	}

	inline public function getCompilationError():String {
		return this._compilationError;
	}
	
	public function getVertexShaderSource():String {
		return this._evaluateDefinesOnString(this._engine.getVertexShaderSource(this._program));
        //return this._engine.getVertexShaderSource(this._program);
    }

    public function getFragmentShaderSource():String {
		return this._evaluateDefinesOnString(this._engine.getFragmentShaderSource(this._program));
        //return this._engine.getFragmentShaderSource(this._program);	
    }

	// Methods
	public function _loadVertexShader(vertex:String, callbackFn:String->Void) {
        // Is in local store ?
        if (ShadersStore.Shaders.exists(vertex + "VertexShader")) {
            callbackFn(ShadersStore.Shaders.get(vertex + "VertexShader"));
            return;
        }
        
        // Vertex shader
		Tools.LoadFile("assets/shaders/" + vertex + ".vertex.fx", callbackFn, "text");
    }
	
	public function _loadFragmentShader(fragment:String, callbackFn:String->Void) {
        // Is in local store ?
        if (ShadersStore.Shaders.exists(fragment + "PixelShader")) {
            callbackFn(ShadersStore.Shaders.get(fragment + "PixelShader"));
            return;
        }
        
        // Fragment shader
		Tools.LoadFile("assets/shaders/" + fragment + ".fragment.fx", callbackFn, "text");
    }
	
	private function _processIncludes(sourceCode:String, callback:Dynamic->Void) {
		var regex:EReg = ~/#include<(.+)>(\((.*)\))*(\[(.*)\])*/g;
		var match = regex.match(sourceCode);
		
		var returnValue = sourceCode;
		
		while (match) {
			var includeFile:String = regex.matched(1);
			
			if (IncludesShadersStore.Shaders[includeFile] != null) {
				sourceCode = StringTools.replace(sourceCode, regex.matched(0), IncludesShadersStore.Shaders[includeFile]);
				
				// Substitution
				var includeContent = IncludesShadersStore.Shaders[includeFile];
				var match2:String = regex.matched(2);
				if (match2 != null) {
					var splits = regex.matched(3).split(",");
					
					var index = 0;
					while (index < splits.length) {
						var source = new EReg(splits[index], "g");
						var dest = splits[index + 1];
						
						includeContent = source.replace(includeContent, dest);
						
						index += 2;
					}
				}
				
				var match4:String = regex.matched(4);
				if (match4 != null) {
					var rx:EReg = ~/\{X\}/g;
					var indexString:String = regex.matched(5);
					
					if (indexString.indexOf("..") != -1) {
						var indexSplits = indexString.split("..");
						var minIndex = Std.parseInt(indexSplits[0]);
						var maxIndex = Std.parseInt(indexSplits[1]);
						var sourceIncludeContent = includeContent.substr(0);
						includeContent = "";
						
						if (maxIndex == null || Math.isNaN(maxIndex)) {
							maxIndex = Std.int(Reflect.getProperty(this._indexParameters, indexSplits[1]));
						}
						
						for (i in minIndex...maxIndex + 1) {
							includeContent += rx.replace(sourceIncludeContent, i + "") + "\n";
						}
					} 
					else {
						includeContent = rx.replace(includeContent, indexString);
					}
				}
				
				// Replace
				returnValue = StringTools.replace(returnValue, regex.matched(0), includeContent);
			} 
			else {
				var includeShaderUrl = Engine.ShadersRepository + "ShadersInclude/" + includeFile + ".fx";
				
				Tools.LoadFile(includeShaderUrl, function(fileContent:Dynamic) {
					IncludesShadersStore.Shaders[includeFile] = fileContent;
					this._processIncludes(sourceCode, callback);
				});
				
				return;
			}
			
			match = regex.match(sourceCode);
		}
		
		callback(returnValue);
	}
	
	private function _processPrecision(source:String):String {
		if (source.indexOf("precision highp float") == -1) {
			if (!this._engine.getCaps().highPrecisionShaderSupported) {
				source = "precision mediump float;\n" + source;
			} 
			else {
				source = "precision highp float;\n" + source;
			}
		} 
		else {
			if (!this._engine.getCaps().highPrecisionShaderSupported) { // Moving highp to mediump
				source = StringTools.replace(source, "precision highp float", "precision mediump float");
			}
		}		
		
		#if (!android && !js && !purejs && !web && !html5)	// TODO !mobile ??
		// native bug fix for neko / osx / etc http://community.openfl.org/t/lime-2-8-0-shader-issues/7060/2
		source = StringTools.replace(source, "precision highp float;", "\n");
		source = StringTools.replace(source, "precision highp float;", "\n");
		source = StringTools.replace(source, "precision mediump float;", "\n");
		source = StringTools.replace(source, "precision mediump float;", "\n");
		#end
		
		return source;
	}
	
	private function _prepareEffect(vertexSourceCode:String, fragmentSourceCode:String, attributesNames:Array<String>, defines:String, ?fallbacks:EffectFallbacks) {		
        try {
            var engine = this._engine;
			
			// Precision
			vertexSourceCode = this._processPrecision(vertexSourceCode);
			fragmentSourceCode = this._processPrecision(fragmentSourceCode);
			
            this._program = engine.createShaderProgram(vertexSourceCode, fragmentSourceCode, defines);
			
            this._uniforms = engine.getUniforms(this._program, this._uniformsNames);
            this._attributes = engine.getAttributes(this._program, attributesNames);
			
			var index:Int = 0;
			while (index < this._samplers.length) {				
                var sampler = this.getUniform(this._samplers[index]);	
				#if (js || purejs || html5 || web || snow || nme || neko)
				if (sampler == null) {
				#else // openfl/lime
				if ( #if legacy sampler != null && #end cast(sampler, Int) < 0) {
				#end
					this._samplers.splice(index, 1);
					index--;
				}
				
				index++;
            }
			
            engine.bindSamplers(this);
			
            this._isReady = true;
			
			if (this.onCompiled != null) {
				this.onCompiled(this);
			}
			
        } catch (e:Dynamic) {		
			
			#if (js || purejs)
			// Is it a problem with precision?
			if (e.indexOf("highp") != -1) {
				vertexSourceCode = StringTools.replace(vertexSourceCode, "precision highp float", "precision mediump float");
				fragmentSourceCode = StringTools.replace(fragmentSourceCode, "precision highp float", "precision mediump float");
				
				this._prepareEffect(vertexSourceCode, fragmentSourceCode, attributesNames, defines, fallbacks);
				
				return;
			}
			#end
            // Let's go through fallbacks then
			if (fallbacks != null && fallbacks.isMoreFallbacks) {
				defines = fallbacks.reduce(defines);
				this._prepareEffect(vertexSourceCode, fragmentSourceCode, attributesNames, defines, fallbacks);
            } 
			else {
                trace("Unable to compile effect: " + this.name);
                trace("Defines: " + defines);
				#if (js || purejs || web || html5)
                trace("Error: " + e);
				#else
				trace("Error #: " + GL.getError());
				trace("Error: " + e);
				#end
                this._compilationError = cast e;
				
				if (this.onError != null) {
					this.onError(this, this._compilationError);
				}
            }
        }
    }
	
	private function get_isSupported():Bool {
		return this._compilationError == "";
	}

	inline public function _bindTexture(channel:String, texture:WebGLTexture) {
		this._engine._bindTexture(this._samplers.indexOf(channel), texture.data);
	}

	public function setTexture(channel:String, texture:BaseTexture) {
		this._engine.setTexture(this._samplers.indexOf(channel), this.getUniform(channel), texture);
	}
	
	public function setTextureArray(channel:String, textures:Array<BaseTexture>) {
		if (this._samplers.indexOf(channel + "Ex") == -1) {
			var initialPos = this._samplers.indexOf(channel);
			for (index in 1...textures.length) {
				this._samplers.insert(initialPos + index, channel + "Ex");
			}
		}
		
		this._engine.setTextureArray(this._samplers.indexOf(channel), this.getUniform(channel), textures);
	}

	inline public function setTextureFromPostProcess(channel:String, postProcess:PostProcess) {
		this._engine.setTextureFromPostProcess(this._samplers.indexOf(channel), postProcess);
	}

	public function _cacheMatrix(uniformName:String, matrix:Matrix):Bool {
		var changed:Bool = false;
		var cache:Matrix = this._valueCacheMatrix[uniformName];
		if (cache == null || !Std.is(cache, Matrix)) {
			changed = true;
			cache = new Matrix();
		}
		
		var tm = cache.m;
		var om = matrix.m;
		for (index in 0...16) {
			if (tm[index] != om[index]) { 
				tm[index] = om[index];
				changed = true;
			}
		}
		
		this._valueCacheMatrix[uniformName] = cache;
		
		return changed;
	}

	public function _cacheFloat2(uniformName:String, x:Float, y:Float):Bool {
		var cache:Array<Float> = this._valueCache[uniformName];
		if (cache == null) {
			cache = [x, y];
			this._valueCache[uniformName] = cache;
			
			return true;
		}
		
		var changed = false;
		if (cache[0] != x) {
			cache[0] = x;
			changed = true;
		}
		if (cache[1] != y) {
			cache[1] = y;
			changed = true;
		}
		
		return changed;
	}

	public function _cacheFloat3(uniformName:String, x:Float, y:Float, z:Float):Bool {
		var cache:Array<Float> = this._valueCache[uniformName];
		if (cache == null) {
			cache = [x, y, z];
			this._valueCache[uniformName] = cache;
			return true;
		}
		
		var changed = false;
		if (cache[0] != x) {
			cache[0] = x;
			changed = true;
		}
		if (cache[1] != y) {
			cache[1] = y;
			changed = true;
		}
		if (cache[2] != z) {
			cache[2] = z;
			changed = true;
		}
		
		return changed;
	}

	public function _cacheFloat4(uniformName:String, x:Float, y:Float, z:Float, w:Float):Bool {
		var cache:Array<Float> = this._valueCache[uniformName];
		if (cache == null) {
			cache = [x, y, z, w];
			this._valueCache[uniformName] = cache;
			
			return true;
		}
		
		var changed = false;
		if (cache[0] != x) {
			cache[0] = x;
			changed = true;
		}
		if (cache[1] != y) {
			cache[1] = y;
			changed = true;
		}
		if (cache[2] != z) {
			cache[2] = z;
			changed = true;
		}
		if (cache[3] != w) {
			cache[3] = w;
			changed = true;
		}
		
		return changed;
	}
	
	/*inline public function setIntArray(uniformName:String, array:Int32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setIntArray(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setIntArray2(uniformName:String, array:Int32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setIntArray2(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setIntArray3(uniformName:String, array:Int32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setIntArray3(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setIntArray4(uniformName:String, array:Int32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setIntArray4(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setFloatArray(uniformName:String, array:Float32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setFloatArray(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setFloatArray2(uniformName:String, array:Float32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setFloatArray2(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setFloatArray3(uniformName:String, array:Float32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setFloatArray3(this.getUniform(uniformName), array);
		
		return this;
	}

	inline public function setFloatArray4(uniformName:String, array:Float32Array):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setFloatArray4(this.getUniform(uniformName), array);
		
		return this;
	}*/

	inline public function setArray(uniformName:String, array:Array<Float>):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setArray(this.getUniform(uniformName), array);
		
		return this;
	}
	
	inline public function setArray2(uniformName:String, array:Array<Float>):Effect {
		this._valueCache[uniformName] = null;
        this._engine.setArray2(this.getUniform(uniformName), array);
		
        return this;
    }

    inline public function setArray3(uniformName:String, array:Array<Float>):Effect {
		this._valueCache[uniformName] = null;
        this._engine.setArray3(this.getUniform(uniformName), array);
		
        return this;
    }

    inline public function setArray4(uniformName:String, array:Array<Float>):Effect {
		this._valueCache[uniformName] = null;
        this._engine.setArray4(this.getUniform(uniformName), array);
		
        return this;
    }

	inline public function setMatrices(uniformName:String, matrices: #if (js || purejs) Float32Array #else Array<Float> #end ):Effect {
		this._valueCache[uniformName] = null;
		this._engine.setMatrices(this.getUniform(uniformName), matrices);
		
		return this;
	}

	inline public function setMatrix(uniformName:String, matrix:Matrix):Effect {
		if (this._cacheMatrix(uniformName, matrix)) {
			this._engine.setMatrix(this.getUniform(uniformName), matrix);
		}
		
		return this;
	}
	
	inline public function setMatrix3x3(uniformName:String, matrix:Float32Array):Effect {
		this._valueCache[uniformName] = null;
        this._engine.setMatrix3x3(this.getUniform(uniformName), matrix);
		
        return this;
    }

    inline public function setMatrix2x2(uniformName:String, matrix:Float32Array):Effect {
		this._valueCache[uniformName] = null;
        this._engine.setMatrix2x2(this.getUniform(uniformName), matrix);
		
        return this;
    }

	inline public function setFloat(uniformName:String, value:Float):Effect {
		var val = this._valueCache[uniformName];
		if (val != null && val[0] == value) {
			return this;
		}	
		
		this._valueCache.set(uniformName, [value]);		
		this._engine.setFloat(this.getUniform(uniformName), value);
		
		return this;
	}

	inline public function setBool(uniformName:String, bool:Bool):Effect {
		var val = this._valueCache[uniformName];
		if (val != null && val[0] == (bool ? 1.0 : 0.0)) {
			return this;
		}
		
		this._valueCache[uniformName] = bool ? [1.0] : [0.0];
		this._engine.setBool(this.getUniform(uniformName), bool);
		
		return this;
	}

	inline public function setVector2(uniformName:String, vector2:Vector2):Effect {
		if (this._cacheFloat2(uniformName, vector2.x, vector2.y)) {
			this._engine.setFloat2(this.getUniform(uniformName), vector2.x, vector2.y);
		}
		
		return this;
	}

	inline public function setFloat2(uniformName:String, x:Float, y:Float):Effect {
		if (this._cacheFloat2(uniformName, x, y)) {
			this._engine.setFloat2(this.getUniform(uniformName), x, y);
		}
		
		return this;
	}

	inline public function setVector3(uniformName:String, vector3:Vector3):Effect {
		if (this._cacheFloat3(uniformName, vector3.x, vector3.y, vector3.z)) {
			this._engine.setFloat3(this.getUniform(uniformName), vector3.x, vector3.y, vector3.z);
		}
		
		return this;
	}

	inline public function setFloat3(uniformName:String, x:Float, y:Float, z:Float):Effect {
		if (this._cacheFloat3(uniformName, x, y, z)) {
			this._engine.setFloat3(this.getUniform(uniformName), x, y, z);
		}
		
		return this;
	}
	
	inline public function setVector4(uniformName:String, vector4:Vector4):Effect {
		if (this._cacheFloat4(uniformName, vector4.x, vector4.y, vector4.z, vector4.w)) {
			this._engine.setFloat4(this.getUniform(uniformName), vector4.x, vector4.y, vector4.z, vector4.w);
		}
		
		return this;
	}

	inline public function setFloat4(uniformName:String, x:Float, y:Float, z:Float, w:Float):Effect {
		if (this._cacheFloat4(uniformName, x, y, z, w)) {
			this._engine.setFloat4(this.getUniform(uniformName), x, y, z, w);
		}
		
		return this;
	}

	inline public function setColor3(uniformName:String, color3:Color3):Effect {
		if (this._cacheFloat3(uniformName, color3.r, color3.g, color3.b)) {
			this._engine.setColor3(this.getUniform(uniformName), color3);
		}
		
		return this;
	}

	inline public function setColor4(uniformName:String, color3:Color3, alpha:Float):Effect {
		if (this._cacheFloat4(uniformName, color3.r, color3.g, color3.b, alpha)) {
			this._engine.setColor4(this.getUniform(uniformName), color3, alpha);
		}
		
		return this;
	}
	
	private function _recombineShader(node:Dynamic):String {
		if (node.define != null) {
			if (node.condition != null) {
				var defineIndex = this.defines.indexOf("#define " + node.define);
                if (defineIndex == -1) {
                    return null;
                }
				
                var nextComma = this.defines.indexOf("\n", defineIndex);
                var defineValue = this.defines.substr(defineIndex + 7, nextComma - defineIndex - 7).replace(node.define, "").trim();
                var condition = defineValue + node.condition;
				
				// VK TODO:
                //if (!eval(condition)) {
                    return null;
				//}
			}
			else if (node.ndef != null) {
				if (this.defines.indexOf("#define " + node.define) != -1) {
					return null;
				}
			}
			else if (this.defines.indexOf("#define " + node.define) == -1) {
				return null;
			}
		}
		
		var result:String = "";
		for (index in 0...node.children.length) {
			var line = node.children[index];
			
			if (line.children != null) {
				var combined = this._recombineShader(line);
				if (combined != null) {
					result += combined + "\r\n";
				}
				
				continue;
			}
			
			result += line + "\r\n";
		}
		
		return result;
	}

	private function _evaluateDefinesOnString(shaderString:String):String {
		var root:Dynamic = {
			children: []
		};
		var currentNode:Dynamic = root;
		
		var lines = shaderString.split("\n");
		
		var newNode:Dynamic = { };
		
		for (index in 0...lines.length) {
			var line = StringTools.trim(lines[index]);
			
			// #ifdef
			var pos = line.indexOf("#ifdef ");
			if (pos != -1) {
				var define = line.substr(pos + 7);
				
				var newNode:Dynamic = {
					condition: null,
					ndef: false,
					define: define,
					children: [],
					parent: currentNode
				}
				
				currentNode.children.push(newNode);
				currentNode = newNode;
				continue;
			}
			
			// #ifndef
			var pos = line.indexOf("#ifndef ");
			if (pos != -1) {
				var define = line.substr(pos + 8);
				
				newNode = {
					condition: null,
					define: define,
					ndef: true,
					children: [],
					parent: currentNode
				}
				
				currentNode.children.push(newNode);
				currentNode = newNode;
				continue;
			}
			
			// #if
			var pos = line.indexOf("#if ");
			if (pos != -1) {
				var define = StringTools.trim(line.substr(pos + 4));
				var conditionPos = define.indexOf(" ");
				
				newNode = {
					condition: define.substr(conditionPos + 1),
					define: define.substr(0, conditionPos),
					ndef: false,
					children: [],
					parent: currentNode
				}
				
				currentNode.children.push(newNode);
				currentNode = newNode;
				continue;
			}
			
			// #endif
			pos = line.indexOf("#endif");
			if (pos != -1) {
				currentNode = currentNode.parent;
				continue;
			}
			
			currentNode.children.push(line);
		}
		
		// Recombine
		return this._recombineShader(root);
	}

}
