package com.babylonhx;

import com.babylonhx.states._AlphaState;
import com.babylonhx.states._DepthCullingState;
import com.babylonhx.cameras.Camera;
import com.babylonhx.materials.textures.WebGLTexture;
import com.babylonhx.materials.textures.VideoTexture;
import com.babylonhx.materials.textures.BaseTexture;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.materials.Effect;
import com.babylonhx.materials.EffectFallbacks;
import com.babylonhx.math.Color3;
import com.babylonhx.math.Color4;
import com.babylonhx.math.Matrix;
import com.babylonhx.mesh.WebGLBuffer;
import com.babylonhx.mesh.VertexBuffer;
import com.babylonhx.math.Viewport;
import com.babylonhx.postprocess.PostProcess;
import com.babylonhx.tools.Tools;

import com.babylonhx.utils.GL;
import com.babylonhx.utils.GL.GLProgram;
import com.babylonhx.utils.GL.GLUniformLocation;
import com.babylonhx.utils.typedarray.UInt8Array;
import com.babylonhx.utils.typedarray.Float32Array;
import com.babylonhx.utils.typedarray.Int32Array;
import com.babylonhx.utils.typedarray.Int16Array;
import com.babylonhx.utils.typedarray.ArrayBufferView;
import com.babylonhx.utils.typedarray.ArrayBuffer;
import com.babylonhx.utils.GL.GLFramebuffer;
import com.babylonhx.utils.GL.GLBuffer;
import com.babylonhx.utils.Image;


import haxe.ds.Vector;


#if (js || purejs)
import com.babylonhx.audio.AudioEngine;
import js.Browser;

#end

#if openfl
import openfl.display.OpenGLView;
#elseif nme
import nme.display.OpenGLView;
#end

/**
 * ...
 * @author Krtolica Vujadin
 */

typedef BufferPointer = { 
	indx:Int,
	size:Int,
	type:Int,
	normalized:Bool,
	stride:Int,
	offset:Int,
	buffer:WebGLBuffer
}

@:expose('BABYLON.Engine') class Engine {
	
	// Const statics

	public static inline var ALPHA_DISABLE:Int = 0;
	public static inline var ALPHA_ADD:Int = 1;
	public static inline var ALPHA_COMBINE:Int = 2;
	public static inline var ALPHA_SUBTRACT:Int = 3;
	public static inline var ALPHA_MULTIPLY:Int = 4;
	public static inline var ALPHA_MAXIMIZED:Int = 5;
	public static inline var ALPHA_ONEONE:Int = 6;

	public static inline var DELAYLOADSTATE_NONE:Int = 0;
	public static inline var DELAYLOADSTATE_LOADED:Int = 1;
	public static inline var DELAYLOADSTATE_LOADING:Int = 2;
	public static inline var DELAYLOADSTATE_NOTLOADED:Int = 4;
	
	public static inline var TEXTUREFORMAT_ALPHA = 0;
	public static inline var TEXTUREFORMAT_LUMINANCE = 1;
	public static inline var TEXTUREFORMAT_LUMINANCE_ALPHA = 2;
	public static inline var TEXTUREFORMAT_RGB = 4;
	public static inline var TEXTUREFORMAT_RGBA = 5;

	public static inline var TEXTURETYPE_UNSIGNED_INT = 0;
	public static inline var TEXTURETYPE_FLOAT = 1;

	public static var Version:String = "2.0.0";

	// Updatable statics so stick with vars here
	public static var CollisionsEpsilon:Float = 0.001;
	public static var ShadersRepository:String = "assets/shaders/";


	// Public members
	public var isFullscreen:Bool = false;
	public var isPointerLock:Bool = false;
	public var cullBackFaces:Bool = true;
	public var renderEvenInBackground:Bool = true;
	public var scenes:Array<Scene> = [];

	// Private Members	
	private var _renderingCanvas:Dynamic;

	private var _windowIsBackground:Bool = false;

	private var _onBlur:Void->Void;
	private var _onFocus:Void->Void;
	private var _onFullscreenChange:Void->Void;
	private var _onPointerLockChange:Void->Void;

	private var _hardwareScalingLevel:Float;	
	private var _caps:EngineCapabilities;
	private var _pointerLockRequested:Bool;
	private var _alphaTest:Bool;
		
	private var _drawCalls:Int = 0;
	public var drawCalls(get, never):Int;
	private function get_drawCalls():Int {
        return this._drawCalls;
    }
	
	private var _glVersion:String;
	private var _glExtensions:Array<String>;
    private var _glRenderer:String;
    private var _glVendor:String;

    private var _videoTextureSupported:Null<Bool>;
	
	private var _renderingQueueLaunched:Bool = false;
	private var _activeRenderLoops:Array<Dynamic> = [];
	
	// FPS
    public var fpsRange:Float = 60.0;
    public var previousFramesDuration:Array<Float> = [];
    public var fps:Float = 60.0;
    public var deltaTime:Float = 0.0;

	// States
	private var _depthCullingState:_DepthCullingState = new _DepthCullingState();
	private var _alphaState:_AlphaState = new _AlphaState();
	private var _alphaMode:Int = Engine.ALPHA_DISABLE;

	// Cache
	private var _loadedTexturesCache:Array<WebGLTexture> = [];
	private var _maxTextureChannels:Int = 16;
	private var _activeTexture:Int;
	public var _activeTexturesCache:Vector<WebGLTexture>;
	private var _currentEffect:Effect;
	private var _currentProgram:GLProgram;
	private var _compiledEffects:Map<String, Effect> = new Map<String, Effect>();
	private var _vertexAttribArrays:Array<Bool>;
	private var _cachedViewport:Viewport;
	private var _cachedVertexBuffers:Dynamic; // WebGLBuffer | Map<String, VertexBuffer>;
	private var _cachedIndexBuffer:WebGLBuffer;
	private var _cachedEffectForVertexBuffers:Effect;
	private var _currentRenderTarget:WebGLTexture;
	private var _uintIndicesCurrentlySet:Bool = false;
	private var _currentBoundBuffer:Map<Int, WebGLBuffer> = new Map();
	private var _currentFramebuffer:GLFramebuffer;
	private var _currentBufferPointers:Array<BufferPointer> = [];
	private var _currentInstanceLocations:Array<Int> = [];
	private var _currentInstanceBuffers:Array<WebGLBuffer> = [];
	private var _textureUnits:Int32Array;

	public var _canvasClientRect:Dynamic = { x: 0, y: 0, width: 960, height: 640 };

	private var _workingCanvas:Image;
	#if (openfl || nme)
	public var _workingContext:OpenGLView; 
	#end
	
	// quick and dirty solution to handle mouse/keyboard 
	public static var mouseDown:Array<Dynamic> = [];
	public static var mouseUp:Array<Dynamic> = [];
	public static var mouseMove:Array<Dynamic> = [];
	public static var mouseWheel:Array<Dynamic> = [];
	public static var touchDown:Array<Dynamic> = [];
	public static var touchUp:Array<Dynamic> = [];
	public static var touchMove:Array<Dynamic> = [];
	public static var keyUp:Array<Dynamic> = [];
	public static var keyDown:Array<Dynamic> = [];
	
	public static var width:Int;
	public static var height:Int;
	public static var onResize:Array<Void->Void> = [];
	
	#if (js || purejs)
	public var audioEngine:AudioEngine = new AudioEngine();
	#end
	
	
	public function new(canvas:Dynamic, antialias:Bool = false, ?options:Dynamic, adaptToDeviceRatio:Bool = false) {		
		this._renderingCanvas = canvas;
		this._canvasClientRect.width = 960;// canvas.width;
		this._canvasClientRect.height = 640;// canvas.height;
		
		options = options != null ? options : {};
		options.antialias = antialias;
		
		if (options.preserveDrawingBuffer == null) {
            options.preserveDrawingBuffer = false;
        }
		
		#if purejs
		GL.context = cast(canvas, js.html.CanvasElement).getContext("webgl", options);
		if(GL.context == null)
			GL.context = cast(canvas, js.html.CanvasElement).getContext("experimental-webgl", options);
		#end
		
		#if (openfl || nme)
		this._workingContext = new OpenGLView();
		this._workingContext.render = this._renderLoop;
		canvas.addChild(this._workingContext);
		#end
		
		width = 960;
		height = 640;		
		
		this._onBlur = function() {
			this._windowIsBackground = true;
		};
		
		this._onFocus = function() {
			this._windowIsBackground = false;
		};
		
		// Viewport
		#if (js || purejs || web)
		this._hardwareScalingLevel = 1;// adaptToDeviceRatio ? 1.0 / (untyped Browser.window.devicePixelRatio || 1.0) : 1.0; 
		#else
		this._hardwareScalingLevel = 1;// Std.int(1.0 / (Capabilities.pixelAspectRatio));	
		#end
        this.resize();
		
		// Caps
		this._caps = new EngineCapabilities();
		this._caps.maxTexturesImageUnits = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
		this._caps.maxTextureSize = GL.getParameter(GL.MAX_TEXTURE_SIZE);
		this._caps.maxCubemapTextureSize = GL.getParameter(GL.MAX_CUBE_MAP_TEXTURE_SIZE);
		this._caps.maxRenderTextureSize = GL.getParameter(GL.MAX_RENDERBUFFER_SIZE);
		
		// Infos
		this._glVersion = GL.getParameter(GL.VERSION);
		this._glVendor = GL.getParameter(GL.VENDOR);
		this._glRenderer = GL.getParameter(GL.RENDERER);
		this._glExtensions = GL.getSupportedExtensions();
		//for (ext in this._glExtensions) {
			//trace(ext);
		//}
		//trace(this._glExtensions);
		
		#if (!snow || (js && snow))
		// Extensions
		try {
			this._caps.standardDerivatives = GL.getExtension('OES_standard_derivatives') != null;
			this._caps.s3tc = GL.getExtension('WEBGL_compressed_texture_s3tc');
			this._caps.textureFloat = (GL.getExtension('OES_texture_float') != null);
			this._caps.textureAnisotropicFilterExtension = GL.getExtension('EXT_texture_filter_anisotropic') || GL.getExtension('WEBKIT_EXT_texture_filter_anisotropic') || GL.getExtension("MOZ_EXT_texture_filter_anisotropic");
			this._caps.maxAnisotropy = this._caps.textureAnisotropicFilterExtension != null ? GL.getParameter(this._caps.textureAnisotropicFilterExtension.MAX_TEXTURE_MAX_ANISOTROPY_EXT) : 0;
			
			#if (!mobile && cpp)
			this._caps.instancedArrays = GL.getExtension("GL_ARB_instanced_arrays");
			/*this._caps.instancedArrays = { 
				vertexAttribDivisorANGLE: GL.getExtension('glVertexAttribDivisorARB'),
				drawElementsInstancedANGLE: GL.getExtension('glDrawElementsInstancedARB'),
				drawArraysInstancedANGLE: GL.getExtension('glDrawElementsInstancedARB')
			};*/
			#else
			this._caps.instancedArrays = GL.getExtension("ANGLE_instanced_arrays");
			#end
			
			this._caps.uintIndices = GL.getExtension("OES_element_index_uint") != null;	
			this._caps.fragmentDepthSupported = GL.getExtension("EXT_frag_depth") != null;
			this._caps.highPrecisionShaderSupported = true;
			if (GL.getShaderPrecisionFormat != null) {
				var highp = GL.getShaderPrecisionFormat(GL.FRAGMENT_SHADER, GL.HIGH_FLOAT);
				this._caps.highPrecisionShaderSupported = highp != null && highp.precision != 0;
			}
			this._caps.drawBufferExtension = GL.getExtension("WEBGL_draw_buffers");
			this._caps.textureFloatLinearFiltering = GL.getExtension("OES_texture_float_linear") != null;
			this._caps.textureLOD = GL.getExtension('EXT_shader_texture_lod') != null;
			if (this._caps.textureLOD) {
				this._caps.textureLODExt = "GL_EXT_shader_texture_lod";
				this._caps.textureCubeLodFnName = "textureCubeLodEXT";
			}
		} 
		catch (err:Dynamic) {
			trace(err);
		}
		#if (!js && !purejs)
			if (this._caps.s3tc == null) {
				this._caps.s3tc = this._glExtensions.indexOf("GL_EXT_texture_compression_s3tc") != -1;
			}
			if (this._caps.textureAnisotropicFilterExtension == null || this._caps.textureAnisotropicFilterExtension == false) {
				if (this._glExtensions.indexOf("GL_EXT_texture_filter_anisotropic") != -1) {
					this._caps.textureAnisotropicFilterExtension = { };
					this._caps.textureAnisotropicFilterExtension.TEXTURE_MAX_ANISOTROPY_EXT = 0x84FF;
				}
			}
			if (this._caps.maxRenderTextureSize == 0) {
				this._caps.maxRenderTextureSize = 16384;
			}
			if (this._caps.maxCubemapTextureSize == 0) {
				this._caps.maxCubemapTextureSize = 16384;
			}
			if (this._caps.maxTextureSize == 0) {
				this._caps.maxTextureSize = 16384;
			}
			if (this._caps.uintIndices == null) {
				this._caps.uintIndices = true;
			}
			if (this._caps.standardDerivatives == false) {
				this._caps.standardDerivatives = true;
			}
			if (this._caps.maxAnisotropy == 0) {
				this._caps.maxAnisotropy = 16;
			}
			if (this._caps.textureFloat == false) {
				this._caps.textureFloat = this._glExtensions.indexOf("GL_ARB_texture_float") != -1;
			}
			if (this._caps.fragmentDepthSupported == false) {
				this._caps.fragmentDepthSupported = GL.getExtension("GL_EXT_frag_depth") != null;
			}
			if (this._caps.drawBufferExtension == null) {
				this._caps.drawBufferExtension = GL.getExtension("GL_ARB_draw_buffers");
			}
			if (this._caps.textureFloatLinearFiltering == false) {
				this._caps.textureFloatLinearFiltering = true;
			}
			if (this._caps.textureLOD == false) {
				this._caps.textureLOD = this._glExtensions.indexOf("GL_ARB_shader_texture_lod") != -1;
				if (this._caps.textureLOD) {
					this._caps.textureLODExt = "GL_ARB_shader_texture_lod";
					this._caps.textureCubeLodFnName = "textureCubeLod";
				}
			}
		#end
		#else
		this._caps.maxRenderTextureSize = 16384;
		this._caps.maxCubemapTextureSize = 16384;
		this._caps.maxTextureSize = 16384;
		this._caps.uintIndices = true;
		this._caps.standardDerivatives = true;
		this._caps.maxAnisotropy = 16;
		this._caps.highPrecisionShaderSupported = true;
		this._caps.textureFloat = this._glExtensions.indexOf("GL_ARB_texture_float") != -1;
		this._caps.fragmentDepthSupported = this._glExtensions.indexOf("GL_EXT_frag_depth") != -1;
		this._caps.drawBufferExtension = null;
		this._caps.textureFloatLinearFiltering = false;
		this._caps.textureLOD = this._glExtensions.indexOf("GL_ARB_shader_texture_lod") != -1;
		if (this._caps.textureLOD) {
			this._caps.textureLODExt = "GL_ARB_shader_texture_lod";
			this._caps.textureCubeLodFnName = "textureCubeLod";
		}
		trace(this._caps.textureLODExt);
		this._caps.instancedArrays = null;
		#end
		
		// Depth buffer
		this.setDepthBuffer(true);
		this.setDepthFunctionToLessOrEqual();
		this.setDepthWrite(true);
		
		// Fullscreen
		this.isFullscreen = false;
		
		// Pointer lock
		this.isPointerLock = false;	
		
		this._activeTexturesCache = new Vector<WebGLTexture>(this._maxTextureChannels);
		
		var msg:String = "BabylonHx - Cross-Platform 3D Engine | " + Date.now().getFullYear() + " | www.babylonhx.com";
		msg +=  " | GL version: " + this._glVersion + " | GL vendor: " + this._glVendor + " | GL renderer: " + this._glVendor; 
		trace(msg);
	}
	
	public static function compileShader(source:String, type:String, defines:String):GLShader {
        var shader:GLShader = GL.createShader(type == "vertex" ? GL.VERTEX_SHADER : GL.FRAGMENT_SHADER);
		
        GL.shaderSource(shader, (defines != null ? defines + "\n" : "") + source);
        GL.compileShader(shader);
		
        if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0) {
            throw(GL.getShaderInfoLog(shader));
        }
		
        return shader;
    }
	
	inline public static function getWebGLTextureType(type:Int):Int {
		return (type == Engine.TEXTURETYPE_FLOAT ? GL.FLOAT : GL.UNSIGNED_BYTE);
	}

    public static function getSamplingParameters(samplingMode:Int, generateMipMaps:Bool):Dynamic {
        var magFilter = GL.NEAREST;
        var minFilter = GL.NEAREST;
        if (samplingMode == Texture.BILINEAR_SAMPLINGMODE) {
            magFilter = GL.LINEAR;
            if (generateMipMaps) {
                minFilter = GL.LINEAR_MIPMAP_NEAREST;
            } 
			else {
                minFilter = GL.LINEAR;
            }
        } 
		else if (samplingMode == Texture.TRILINEAR_SAMPLINGMODE) {
            magFilter = GL.LINEAR;
            if (generateMipMaps) {
                minFilter = GL.LINEAR_MIPMAP_LINEAR;
            } 
			else {
                minFilter = GL.LINEAR;
            }
        } 
		else if (samplingMode == Texture.NEAREST_SAMPLINGMODE) {
            magFilter = GL.NEAREST;
            if (generateMipMaps) {
                minFilter = GL.NEAREST_MIPMAP_LINEAR;
            } 
			else {
                minFilter = GL.NEAREST;
            }
        }
		
        return {
            min: minFilter,
            mag: magFilter
        }
    }

    public function prepareTexture(texture:WebGLTexture, scene:Scene, width:Int, height:Int, invertY:Bool, noMipmap:Bool, isCompressed:Bool, processFunction:Int->Int->Void, ?onLoad:Void->Void, samplingMode:Int = Texture.TRILINEAR_SAMPLINGMODE) {
        var engine = scene.getEngine();
        var potWidth = com.babylonhx.math.Tools.GetExponentOfTwo(width, engine.getCaps().maxTextureSize);
        var potHeight = com.babylonhx.math.Tools.GetExponentOfTwo(height, engine.getCaps().maxTextureSize);
		
		if (potWidth != width || potHeight != height) {
			trace("Texture '" + texture.url + "' is not power of two !");
		}
		
        this._bindTextureDirectly(GL.TEXTURE_2D, texture);
		/*#if js
        GL.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, invertY == null ? 1 : (invertY ? 1 : 0));
		#end*/
		
		texture._baseWidth = width;
        texture._baseHeight = height;
        texture._width = potWidth;
        texture._height = potHeight;
        texture.isReady = true;
		
        processFunction(Std.int(potWidth), Std.int(potHeight));
		
        var filters = getSamplingParameters(samplingMode, !noMipmap);
		
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filters.mag);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filters.min);
		
        if (!noMipmap && !isCompressed) {
            GL.generateMipmap(GL.TEXTURE_2D);
        }
		
        this._bindTextureDirectly(GL.TEXTURE_2D, null);
		
        resetTextureCache();        		
        scene._removePendingData(texture);
		
		if (onLoad != null) {
			onLoad();
		}
    }

	public static function partialLoad(url:String, index:Int, loadedImages:Dynamic, scene:Scene, onfinish:Dynamic->Void) {
        /*var img:Dynamic = null;

        var onload = function() {
            loadedImages[index] = img;
            loadedImages._internalCount++;

            scene._removePendingData(img);

            if (loadedImages._internalCount == 6) {
                onfinish(loadedImages);
            }
        };

        var onerror = function() {
            scene._removePendingData(img);
        };

        img = Tools.LoadImage(url, onload, onerror, scene.database);
        scene._addPendingData(img);*/
    }

    public static function cascadeLoad(rootUrl:String, scene:Scene, onfinish:Dynamic->Void, extensions:Array<String>) {
        /*var loadedImages:Array<Dynamic> = [];
        loadedImages._internalCount = 0;

        for (index in 0...6) {
            partialLoad(rootUrl + extensions[index], index, loadedImages, scene, onfinish);
        }*/
    }
	
	public function getExtensions():Array<String> {
		return this._glExtensions;
	}
	
	public function resetTextureCache() {
		for (index in 0...this._maxTextureChannels) {
			this._activeTexturesCache[index] = null;
		}
	}

	public function getAspectRatio(camera:Camera, useScreen:Bool = false):Float {
		var viewport = camera.viewport;
		
		return (this.getRenderWidth(useScreen) * viewport.width) / (this.getRenderHeight(useScreen) * viewport.height);
	}

	public function getRenderWidth(useScreen:Bool = false):Int {
		/*if (!useScreen && this._currentRenderTarget != null) {
			return this._currentRenderTarget._width;
		}*/
		
		return width;
	}

	public function getRenderHeight(useScreen:Bool = false):Int {
		/*if (!useScreen && this._currentRenderTarget != null) {
			return this._currentRenderTarget._height;
		}*/
		
		return height;
	}

	public function getRenderingCanvas():Dynamic {
		return this._renderingCanvas;
	}

	public function setHardwareScalingLevel(level:Float) {
		this._hardwareScalingLevel = level;
		this.resize();
	}

	public function getHardwareScalingLevel():Float {
		return this._hardwareScalingLevel;
	}

	public function getLoadedTexturesCache():Array<WebGLTexture> {
		return this._loadedTexturesCache;
	}

	public function getCaps():EngineCapabilities {
		return this._caps;
	}

	// Methods
	inline public function resetDrawCalls() {
        this._drawCalls = 0;
    }
	
	inline public function setDepthFunctionToGreater() {
		this._depthCullingState.depthFunc = GL.GREATER;
	}

	inline public function setDepthFunctionToGreaterOrEqual() {
		this._depthCullingState.depthFunc = GL.GEQUAL;
	}

	inline public function setDepthFunctionToLess() {
		this._depthCullingState.depthFunc = GL.LESS;
	}

	inline public function setDepthFunctionToLessOrEqual() {
		this._depthCullingState.depthFunc = GL.LEQUAL;
	}

	/**
	 * stop executing a render loop function and remove it from the execution array
	 * @param {Function} [renderFunction] the function to be removed. If not provided all functions will be removed.
	 */
	public function stopRenderLoop(?renderFunction:Void->Void) {
		if (renderFunction == null) {
			this._activeRenderLoops = [];
			return;
		}
		
		var index = this._activeRenderLoops.indexOf(renderFunction);
		
		if (index >= 0) {
			this._activeRenderLoops.splice(index, 1);
		}
	}

	public function _renderLoop(?rect:Dynamic) {
		var shouldRender = true;
		if (!this.renderEvenInBackground && this._windowIsBackground) {
			shouldRender = false;
		}

		if (shouldRender) {
			// Start new frame
			this.beginFrame();

			for (index in 0...this._activeRenderLoops.length) {
				var renderFunction = this._activeRenderLoops[index];

				renderFunction();
			}

			// Present
			this.endFrame();
		}

		#if purejs
		if (this._activeRenderLoops.length > 0) {
			// Register new frame
			Tools.QueueNewFrame(this._renderLoop);
		} else {
			this._renderingQueueLaunched = false;
		}
		#end
	}

	inline public function runRenderLoop(renderFunction:Void->Void) {
		if (this._activeRenderLoops.indexOf(renderFunction) != -1) {
			return;
		}

		this._activeRenderLoops.push(renderFunction);

		#if purejs
		if (!this._renderingQueueLaunched) {
			this._renderingQueueLaunched = true;
			Tools.QueueNewFrame(this._renderLoop);
		}
		#end
	}

	public function switchFullscreen(requestPointerLock:Bool) {
		// TODO
		/*if (this.isFullscreen) {
			Tools.ExitFullscreen();
		} else {
			this._pointerLockRequested = requestPointerLock;
			Tools.RequestFullscreen(this._renderingCanvas);
		}*/
	}

	inline public function clear(color:Dynamic, backBuffer:Bool, depthStencil:Bool) {
		this.applyStates();
		
		if (backBuffer) {
			if(Std.is(color, Color4)) {
				GL.clearColor(color.r, color.g, color.b, color.a);
			} 
			else {
				GL.clearColor(color.r, color.g, color.b, 1.0);
			}
		}
		
		if (depthStencil && this._depthCullingState.depthMask) {
			GL.clearDepth(1.0);
		}
		var mode = 0;
		
		if (backBuffer) {
			mode |= GL.COLOR_BUFFER_BIT;
		}
		
		if (depthStencil && this._depthCullingState.depthMask) {
			mode |= GL.DEPTH_BUFFER_BIT;
		}
		
		GL.clear(mode);
	}
	
	public function scissorClear(x:Int, y:Int, width:Int, height:Int, clearColor:Color4) {
		// Save state
		var curScissor = GL.getParameter(GL.SCISSOR_TEST);
		var curScissorBox = GL.getParameter(GL.SCISSOR_BOX);
		
		// Change state
		GL.enable(GL.SCISSOR_TEST);
		GL.scissor(x, y, width, height);
		
		// Clear
		this.clear(clearColor, true, true);
		
		// Restore state
		GL.scissor(curScissorBox[0], curScissorBox[1], curScissorBox[2], curScissorBox[3]);
		
		if (curScissor == true) {
			GL.enable(GL.SCISSOR_TEST);
		} 
		else {
			GL.disable(GL.SCISSOR_TEST);
		}
	}

	/**
	 * Set the WebGL's viewport
	 * @param {BABYLON.Viewport} viewport - the viewport element to be used.
	 * @param {number} [requiredWidth] - the width required for rendering. If not provided the rendering canvas' width is used.
	 * @param {number} [requiredHeight] - the height required for rendering. If not provided the rendering canvas' height is used.
	 */
	inline public function setViewport(viewport:Viewport, requiredWidth:Float = 0, requiredHeight:Float = 0) {
		var width = requiredWidth == 0 ? getRenderWidth() : requiredWidth;
        var height = requiredHeight == 0 ? getRenderHeight() : requiredHeight;
		
        var x = viewport.x;
        var y = viewport.y;
        
        this._cachedViewport = viewport;
		GL.viewport(Std.int(x * width), Std.int(y * height), Std.int(width * viewport.width), Std.int(height * viewport.height));
	}

	inline public function setDirectViewport(x:Int, y:Int, width:Int, height:Int):Viewport {
		var currentViewport = this._cachedViewport;
		this._cachedViewport = null;
		
		GL.viewport(x, y, width, height);
		
		return currentViewport;
	}

	inline public function beginFrame() {
		this._measureFps();
	}

	inline public function endFrame() {
		//this.flushFramebuffer();
		#if openfl
		// Depth buffer
		//this.setDepthBuffer(true);
		//this.setDepthFunctionToLessOrEqual();
		//this.setDepthWrite(true);		
		//this._activeTexturesCache = new Vector<BaseTexture>(this._maxTextureChannels);
		// Release effects
		#end
	}
	
	// FPS
    inline public function getFps():Float {
        return this.fps;
    }

    inline public function getDeltaTime():Float {
        return this.deltaTime;
    }

    inline private function _measureFps() {
        this.previousFramesDuration.push(Tools.Now());
        var length = this.previousFramesDuration.length;
		
        if (length >= 2) {
            this.deltaTime = this.previousFramesDuration[length - 1] - this.previousFramesDuration[length - 2];
        }
		
        if (length >= this.fpsRange) {
			
            if (length > this.fpsRange) {
                this.previousFramesDuration.splice(0, 1);
                length = this.previousFramesDuration.length;
            }
			
            var sum = 0.0;
            for (id in 0...length - 1) {
                sum += this.previousFramesDuration[id + 1] - this.previousFramesDuration[id];
            }
			
            this.fps = 1000.0 / (sum / (length - 1));
        }
    }

	/**
	 * resize the view according to the canvas' size.
	 * @example
	 *   window.addEventListener("resize", function () {
	 *      engine.resize();
	 *   });
	 */
	public function resize() {
		#if (purejs)
		width = untyped Browser.navigator.isCocoonJS ? Browser.window.innerWidth : this._renderingCanvas.clientWidth;
		height = untyped Browser.navigator.isCocoonJS ? Browser.window.innerHeight : this._renderingCanvas.clientHeight;
		
		this.setSize(Std.int(width / this._hardwareScalingLevel), Std.int(height / this._hardwareScalingLevel));
		#end
		
		for (fn in onResize) {
			fn();
		}
	}
	
	/**
	 * force a specific size of the canvas
	 * @param {number} width - the new canvas' width
	 * @param {number} height - the new canvas' height
	 */
	public function setSize(width:Int, height:Int) {
		#if purejs
		this._renderingCanvas.width = width;
		this._renderingCanvas.height = height;
				
		for (index in 0...this.scenes.length) {
            var scene = this.scenes[index];
			
            for (camIndex in 0...scene.cameras.length) {
                var cam = scene.cameras[camIndex];
                cam._currentRenderId = 0;
            }
        }
		#end
	}

	public function bindFramebuffer(texture:WebGLTexture, faceIndex:Int = 0, ?requiredWidth:Int, ?requiredHeight:Int) {
		this._currentRenderTarget = texture;
		
		this.bindUnboundFramebuffer(texture._framebuffer);
		
		if (texture.isCube) {
            GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_CUBE_MAP_POSITIVE_X + faceIndex, texture.data, 0);
        } 
		else {
            GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture.data, 0);
        }
		
		GL.viewport(0, 0, requiredWidth != null ? requiredWidth : texture._width, requiredHeight != null ? requiredHeight : texture._height);
		
		this.wipeCaches();
	}
	
	inline private function bindUnboundFramebuffer(framebuffer:GLFramebuffer) {
		if (this._currentFramebuffer != framebuffer) {
			GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer);
			this._currentFramebuffer = framebuffer;
		}
	}

	inline public function unBindFramebuffer(texture:WebGLTexture, disableGenerateMipMaps:Bool = false) {
		this._currentRenderTarget = null;
		
		if (texture.generateMipMaps && !disableGenerateMipMaps) {
			this._bindTextureDirectly(GL.TEXTURE_2D, texture);
			GL.generateMipmap(GL.TEXTURE_2D);
			this._bindTextureDirectly(GL.TEXTURE_2D, null);
		}
		
		this.bindUnboundFramebuffer(null);
	}
	
	public function generateMipMapsForCubemap(texture:WebGLTexture) {
        if (texture.generateMipMaps) {
            this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, texture);
            GL.generateMipmap(GL.TEXTURE_CUBE_MAP);
            this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
        }
    }

	inline public function flushFramebuffer() {
		GL.flush();
	}

	inline public function restoreDefaultFramebuffer() {
		this._currentRenderTarget = null;
		this.bindUnboundFramebuffer(null);
		
		this.setViewport(this._cachedViewport);
		
		this.wipeCaches();
	}

	// VBOs
	inline private function _resetVertexBufferBinding() {
		this.bindArrayBuffer(null);
		this._cachedVertexBuffers = null;
	}

	inline public function createVertexBuffer(vertices:Array<Float>):WebGLBuffer {
		var vbo = GL.createBuffer();
		var ret = new WebGLBuffer(vbo);
		this.bindArrayBuffer(ret);
		
		GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(vertices), GL.STATIC_DRAW);
		this._resetVertexBufferBinding();
		ret.references = 1;
		
		return ret;
	}

	inline public function createDynamicVertexBuffer(vertices:Array<Float>):WebGLBuffer {
		var vbo = GL.createBuffer();
		var ret = new WebGLBuffer(vbo);		
		this.bindArrayBuffer(ret);		
		
		GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(vertices), GL.DYNAMIC_DRAW);
		this._resetVertexBufferBinding();
		ret.references = 1;
		
		return ret;
	}

	/*inline public function updateDynamicVertexBuffer(vertexBuffer:WebGLBuffer, vertices:Array<Float>, offset:Int = 0, count:Int = -1) {
		this.bindArrayBuffer(vertexBuffer);
		
		if (count == -1) {
			GL.bufferSubData(GL.ARRAY_BUFFER, offset, new Float32Array(vertices));
		}
		else {
			GL.bufferSubData(GL.ARRAY_BUFFER, 0, new Float32Array(vertices).subarray(offset, offset + count));
		}
		
		this._resetVertexBufferBinding();
	}*/
	
	inline public function updateDynamicVertexBuffer(vertexBuffer:WebGLBuffer, vertices:Array<Float>, offset:Int = 0, count:Int = -1) {
		this.bindArrayBuffer(vertexBuffer);
		
		if (count == -1) {
			GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(vertices), GL.DYNAMIC_DRAW);
		}
		else {
			GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(vertices).subarray(offset, offset + count), GL.DYNAMIC_DRAW);
		}
		
		this._resetVertexBufferBinding();
	}

	inline private function _resetIndexBufferBinding() {
		this.bindIndexBuffer(null);
		this._cachedIndexBuffer = null;
	}

	inline public function createIndexBuffer(indices:Array<Int>):WebGLBuffer {
		var vbo = GL.createBuffer();
		var ret = new WebGLBuffer(vbo);
		
		this.bindIndexBuffer(ret);
		
		// Check for 32 bits indices
		var arrayBuffer:ArrayBufferView = null;
		var need32Bits = false;
		
		if (this._caps.uintIndices) {			
			for (index in 0...indices.length) {
				if (indices[index] > 65535) {
					need32Bits = true;
					break;
				}
			}
			
			arrayBuffer = need32Bits ? new Int32Array(indices) : new Int16Array(indices);
		} 
		else {
			arrayBuffer = new Int16Array(indices);
		}
		
		GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, arrayBuffer, GL.STATIC_DRAW);
		this._resetIndexBufferBinding();
		ret.references = 1;
		ret.is32Bits = need32Bits;
		
		return ret;
	}
	
	inline public function bindArrayBuffer(buffer:WebGLBuffer) {
		this.bindBuffer(buffer, GL.ARRAY_BUFFER);
	}
	
	inline private function bindIndexBuffer(buffer:WebGLBuffer) {
		this.bindBuffer(buffer, GL.ELEMENT_ARRAY_BUFFER);
	}
	
	private function bindBuffer(buffer:WebGLBuffer, target:Int) {
		if (this._currentBoundBuffer[target] != buffer) {
			GL.bindBuffer(target, buffer == null ? null : buffer.buffer);
			this._currentBoundBuffer[target] = (buffer == null ? null : buffer);
		}
	}

	inline public function updateArrayBuffer(data:Float32Array) {
		GL.bufferSubData(GL.ARRAY_BUFFER, 0, data);
	}
	
	private function vertexAttribPointer(buffer:WebGLBuffer, indx:Int, size:Int, type:Int, normalized:Bool, stride:Int, offset:Int) {
		var pointer:BufferPointer = this._currentBufferPointers[indx];
		
		var changed:Bool = false;
		if (pointer == null) {
			changed = true;
			this._currentBufferPointers[indx] = { indx: indx, size: size, type: type, normalized: normalized, stride: stride, offset: offset, buffer: buffer };
		} 
		else {
			if (pointer.buffer != buffer) { 
				pointer.buffer = buffer; 
				changed = true; 
			}
			if (pointer.size != size) { 
				pointer.size = size; 
				changed = true; 
			}
			if (pointer.type != type) { 
				pointer.type = type; 
				changed = true; 
			}
			if (pointer.normalized != normalized) { 
				pointer.normalized = normalized; 
				changed = true; 
			}
			if (pointer.stride != stride) { 
				pointer.stride = stride; 
				changed = true; 
			}
			if (pointer.offset != offset) { 
				pointer.offset = offset; 
				changed = true; 
			}
		}
		
		if (changed) {
			this.bindArrayBuffer(buffer);
			GL.vertexAttribPointer(indx, size, type, normalized, stride, offset);
		}
	}

	public function bindBuffersDirectly(vertexBuffer:WebGLBuffer, indexBuffer:WebGLBuffer, vertexDeclaration:Array<Int>, vertexStrideSize:Int, effect:Effect) {
		if (this._cachedVertexBuffers != vertexBuffer || this._cachedEffectForVertexBuffers != effect) {
			this._cachedVertexBuffers = vertexBuffer;
			this._cachedEffectForVertexBuffers = effect;
			
			var offset:Int = 0;
			for (index in 0...vertexDeclaration.length) {
				var order = effect.getAttributeLocation(index);
				
				if (order >= 0) {
					this.vertexAttribPointer(vertexBuffer, order, vertexDeclaration[index], GL.FLOAT, false, vertexStrideSize, offset);
				}
				offset += vertexDeclaration[index] * 4;
			}
		}
		
		if (this._cachedIndexBuffer != indexBuffer) {
			this._cachedIndexBuffer = indexBuffer;
			this.bindIndexBuffer(indexBuffer);
			this._uintIndicesCurrentlySet = indexBuffer.is32Bits;
		}
	}

	inline public function bindBuffers(vertexBuffers:Map<String, VertexBuffer>, indexBuffer:WebGLBuffer, effect:Effect) {
		if (this._cachedVertexBuffers != vertexBuffers || this._cachedEffectForVertexBuffers != effect) {
			this._cachedVertexBuffers = vertexBuffers;
			this._cachedEffectForVertexBuffers = effect;
			
			var attributes = effect.getAttributesNames();
			
			for (index in 0...attributes.length) {
				var order = effect.getAttributeLocation(index);
				
				if (order >= 0) {
					var vertexBuffer:VertexBuffer = vertexBuffers[attributes[index]];
					if (vertexBuffer == null) {
						continue;
					}
					
					var buffer = vertexBuffer.getBuffer();
					this.vertexAttribPointer(buffer, order, vertexBuffer.getSize(), GL.FLOAT, false, vertexBuffer.getStrideSize() * 4, vertexBuffer.getOffset() * 4);
					
					if (vertexBuffer.getIsInstanced()) {
						this._caps.instancedArrays.vertexAttribDivisorANGLE(order, 1);
						this._currentInstanceLocations.push(order);
						this._currentInstanceBuffers.push(buffer);
					}
				}
			}
		}
		
		if (indexBuffer != null && this._cachedIndexBuffer != indexBuffer) {
			this._cachedIndexBuffer = indexBuffer;
			this.bindIndexBuffer(indexBuffer);
			this._uintIndicesCurrentlySet = indexBuffer.is32Bits;
		}
	}
	
	public function unbindInstanceAttributes() {
		var boundBuffer:WebGLBuffer = null;
		for (i in 0...this._currentInstanceLocations.length) {
			var instancesBuffer = this._currentInstanceBuffers[i];
			if (boundBuffer != instancesBuffer) {
				boundBuffer = instancesBuffer;
				this.bindArrayBuffer(instancesBuffer);
			}
			var offsetLocation = this._currentInstanceLocations[i];
			this._caps.instancedArrays.vertexAttribDivisorANGLE(offsetLocation, 0);
		}
		
		this._currentInstanceBuffers.splice(0, this._currentInstanceBuffers.length - 1);
		this._currentInstanceLocations.splice(0, this._currentInstanceLocations.length - 1);
	}
	
	inline public function _releaseBuffer(buffer:WebGLBuffer):Bool {
		buffer.references--;
		
		if (buffer.references == 0) {
			GL.deleteBuffer(buffer.buffer);
			return true;
		}
		
		return false;
	}

	inline public function createInstancesBuffer(capacity:Int):WebGLBuffer {
		var buffer = new WebGLBuffer(GL.createBuffer());
		
		buffer.capacity = capacity;
		
		GL.bindBuffer(GL.ARRAY_BUFFER, buffer.buffer);
		GL.bufferData(GL.ARRAY_BUFFER, new Float32Array(capacity), GL.DYNAMIC_DRAW);
		
		return buffer;
	}

	public function deleteInstancesBuffer(buffer:WebGLBuffer) {
		GL.deleteBuffer(buffer.buffer);
		buffer = null;
	}
	
	public function updateAndBindInstancesBuffer(instancesBuffer:WebGLBuffer, data: #if (js || html5 || purejs) Float32Array #else Array<Float> #end , offsetLocations:Array<Dynamic>) {
		this.bindArrayBuffer(instancesBuffer);
		
		if (data != null) {
			#if (js || html5 || purejs) 
			GL.bufferSubData(GL.ARRAY_BUFFER, 0, cast data);
			#else
			GL.bufferSubData(GL.ARRAY_BUFFER, 0, new Float32Array(data));
			#end
		}
		
		if (Std.is(offsetLocations[0], InstancingAttributeInfo)) {
			var stride = 0;
			for (i in 0...offsetLocations.length) {
				var ai:InstancingAttributeInfo = offsetLocations[i];
				stride += ai.attributeSize * 4;
			}
			for (i in 0...offsetLocations.length) {
				var ai = offsetLocations[i];
				GL.enableVertexAttribArray(ai.index);
				this.vertexAttribPointer(instancesBuffer, ai.index, ai.attributeSize, ai.attribyteType, ai.normalized, stride, ai.offset);
				this._caps.instancedArrays.vertexAttribDivisorANGLE(ai.index, 1);
				this._currentInstanceLocations.push(ai.index);
				this._currentInstanceBuffers.push(instancesBuffer);
			}
		}
		else {
				for (index in 0...4) {
					var offsetLocation:Int = offsetLocations[index];
					GL.enableVertexAttribArray(offsetLocation);
					this.vertexAttribPointer(instancesBuffer, offsetLocation, 4, GL.FLOAT, false, 64, index * 16);
					this._caps.instancedArrays.vertexAttribDivisorANGLE(offsetLocation, 1);
					this._currentInstanceLocations.push(offsetLocation);
					this._currentInstanceBuffers.push(instancesBuffer);
				}
		}
	}

	public function unBindInstancesBuffer(instancesBuffer:WebGLBuffer, offsetLocations:Array<Int>) {
		GL.bindBuffer(GL.ARRAY_BUFFER, instancesBuffer.buffer);
		for (index in 0...4) {
			var offsetLocation = offsetLocations[index];
			GL.disableVertexAttribArray(offsetLocation);
			
			this._caps.instancedArrays.vertexAttribDivisorANGLE(offsetLocation, 0);
		}
	}

	inline public function applyStates() {
		this._depthCullingState.apply();
		this._alphaState.apply();
	}

	public function draw(useTriangles:Bool, indexStart:Int, indexCount:Int, instancesCount:Int = -1) {
		// Apply states
		this.applyStates();
		
		this._drawCalls++;
		
		// Render
		var indexFormat = this._uintIndicesCurrentlySet ? GL.UNSIGNED_INT : GL.UNSIGNED_SHORT;
		var mult:Int = this._uintIndicesCurrentlySet ? 4 : 2;
		if (instancesCount != -1) {
			this._caps.instancedArrays.drawElementsInstancedANGLE(useTriangles ? GL.TRIANGLES : GL.LINES, indexCount, indexFormat, indexStart * mult, instancesCount);
			
			return;
		}
		
		GL.drawElements(useTriangles ? GL.TRIANGLES : GL.LINES, indexCount, indexFormat, indexStart * mult);		
	}

	public function drawPointClouds(verticesStart:Int, verticesCount:Int, instancesCount:Int = -1) {
		// Apply states
		this.applyStates();
		
		this._drawCalls++;
		
		if (instancesCount != -1) {
			this._caps.instancedArrays.drawArraysInstancedANGLE(GL.POINTS, verticesStart, verticesCount, instancesCount);
			
			return;
		}
		
		GL.drawArrays(GL.POINTS, verticesStart, verticesCount);
	}
	
	public function drawUnIndexed(useTriangles:Bool, verticesStart:Int, verticesCount:Int, instancesCount:Int = -1) {
        // Apply states
        this.applyStates();
		
        this._drawCalls++;
		
        if (instancesCount != -1) {
            this._caps.instancedArrays.drawArraysInstancedANGLE(useTriangles ? GL.TRIANGLES : GL.LINES, verticesStart, verticesCount, instancesCount);
			
            return;
        }
		
        GL.drawArrays(useTriangles ? GL.TRIANGLES : GL.LINES, verticesStart, verticesCount);
    }

	// Shaders
	public function _releaseEffect(effect:Effect) {
		if (this._compiledEffects.exists(effect._key)) {
			this._compiledEffects.remove(effect._key);
			if (effect.getProgram() != null) {
				GL.deleteProgram(effect.getProgram());
			}
		}
	}

	public function createEffect(baseName:Dynamic, attributesNames:Array<String>, uniformsNames:Array<String>, samplers:Array<String>, defines:String, ?fallbacks:EffectFallbacks, ?onCompiled:Effect->Void, ?onError:Effect->String->Void, ?indexParameters:Dynamic):Effect {
		var vertex = baseName.vertexElement != null ? baseName.vertexElement : (baseName.vertex != null ? baseName.vertex : baseName);
		var fragment = baseName.fragmentElement != null ? baseName.fragmentElement : (baseName.fragment != null ? baseName.fragment : baseName);
		
		var name = vertex + "+" + fragment + "@" + defines;
		if (this._compiledEffects.exists(name)) {
            return this._compiledEffects.get(name);
        }
		
		var effect = new Effect(baseName, attributesNames, uniformsNames, samplers, this, defines, fallbacks, onCompiled, onError, indexParameters);
		effect._key = name;
		this._compiledEffects.set(name, effect);
		
		return effect;
	}

	public function createEffectForParticles(fragmentName:String, ?uniformsNames:Array<String>, ?samplers:Array<String>, defines:String = "", ?fallbacks:EffectFallbacks, ?onCompiled:Effect->Void, ?onError:Effect->String->Void):Effect {
		if (uniformsNames == null) {
			uniformsNames = [];
		}
		if (samplers == null) {
			samplers = [];
		}
		
		return this.createEffect(
			{
				vertex: "particles",
				fragment: fragmentName
			},
			["position", "color", "options"],
			["view", "projection"].concat(uniformsNames),
			["diffuseSampler"].concat(samplers), 
			defines, 
			fallbacks, 
			onCompiled, 
			onError
		);
	}

	public function createShaderProgram(vertexCode:String, fragmentCode:String, defines:String):GLProgram {
		var vertexShader = compileShader(vertexCode, "vertex", defines);
		var fragmentShader = compileShader(fragmentCode, "fragment", defines);
		
		var shaderProgram = GL.createProgram();
		GL.attachShader(shaderProgram, vertexShader);
		GL.attachShader(shaderProgram, fragmentShader);
		
		GL.linkProgram(shaderProgram);
		var linked = GL.getProgramParameter(shaderProgram, GL.LINK_STATUS);
		
		if (linked == 0) {
			var error = GL.getProgramInfoLog(shaderProgram);
			if (error != "") {
				throw(error);
			}
		}
		
		GL.deleteShader(vertexShader);
		GL.deleteShader(fragmentShader);
		
		return shaderProgram;
	}

	inline public function getUniforms(shaderProgram:GLProgram, uniformsNames:Array<String>):Map<String, GLUniformLocation> {
		var results:Map<String, GLUniformLocation> = new Map();
		
		for (name in uniformsNames) {
			var uniform = GL.getUniformLocation(shaderProgram, name);
			#if (purejs || js || html5 || web || snow)
			if (uniform != null) {
			#else 
			if (uniform != -1) {
			#end
				results.set(name, uniform);
			}
		}
		
        return results;
	}

	inline public function getAttributes(shaderProgram:GLProgram, attributesNames:Array<String>):Array<Int> {
        var results:Array<Int> = [];
		
        for (index in 0...attributesNames.length) {
            try {
				results.push(GL.getAttribLocation(shaderProgram, attributesNames[index]));
            } 
			catch (e:Dynamic) {
				trace("getAttributes() -> ERROR: " + e);
                results.push(-1);
            }
        }
		
        return results;
    }

	inline public function enableEffect(effect:Effect) {
		if (effect == null || effect.getAttributesCount() == 0 || this._currentEffect == effect) {
			if (effect != null && effect.onBind != null) {
				effect.onBind(effect);
			}
			
			return;
		}
		
		this._vertexAttribArrays = this._vertexAttribArrays != null ? this._vertexAttribArrays : [];
		
		// Use program
		this.setProgram(effect.getProgram());
		
		for (i in 0...this._vertexAttribArrays.length) {
			if (i > GL.VERTEX_ATTRIB_ARRAY_ENABLED || !this._vertexAttribArrays[i]) {
				continue;
			}
			this._vertexAttribArrays[i] = false;
			GL.disableVertexAttribArray(i);
		}
		
		var attributesCount = effect.getAttributesCount();
		for (index in 0...attributesCount) {
			// Attributes
			var order = effect.getAttributeLocation(index);
			if (order >= 0) {
				this._vertexAttribArrays[order] = true;
				GL.enableVertexAttribArray(order);
			}
		}
		
		this._currentEffect = effect;
		
		if (effect.onBind != null) {
			effect.onBind(effect);
		}	
	}
	
	inline public function setArray(uniform:GLUniformLocation, array:Array<Float>) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform1fv(uniform, new Float32Array(array));
	}
	
	inline public function setArray2(uniform:GLUniformLocation, array:Array<Float>) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
        if (array.length % 2 == 0) {
			GL.uniform2fv(uniform, new Float32Array(array));
		}
    }

    inline public function setArray3(uniform:GLUniformLocation, array:Array<Float>) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
        if (array.length % 3 == 0) {			
			GL.uniform3fv(uniform, new Float32Array(array));
		}
    }

    inline public function setArray4(uniform:GLUniformLocation, array:Array<Float>) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
        if (array.length % 4 == 0) {			
			GL.uniform4fv(uniform, new Float32Array(array));
		}
    }

	inline public function setMatrices(uniform:GLUniformLocation, matrices: #if (js || purejs) Float32Array #else Array<Float> #end ) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniformMatrix4fv(uniform, false, #if (js || purejs) matrices #else new Float32Array(matrices) #end);
	}

	inline public function setMatrix(uniform:GLUniformLocation, matrix:Matrix) {	
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniformMatrix4fv(uniform, false, #if (js || purejs) matrix.m #else new Float32Array(matrix.m) #end );
	}
	
	inline public function setMatrix3x3(uniform:GLUniformLocation, matrix:Float32Array) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniformMatrix3fv(uniform, false, matrix);
	}

	inline public function setMatrix2x2(uniform:GLUniformLocation, matrix:Float32Array) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniformMatrix2fv(uniform, false, matrix);
	}

	inline public function setFloat(uniform:GLUniformLocation, value:Float) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform1f(uniform, value);
	}

	inline public function setFloat2(uniform:GLUniformLocation, x:Float, y:Float) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform2f(uniform, x, y);
	}

	inline public function setFloat3(uniform:GLUniformLocation, x:Float, y:Float, z:Float) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform3f(uniform, x, y, z);
	}

	inline public function setBool(uniform:GLUniformLocation, bool:Bool) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform1i(uniform, bool ? 1 : 0);
	}

	public function setFloat4(uniform:GLUniformLocation, x:Float, y:Float, z:Float, w:Float) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform4f(uniform, x, y, z, w);
	}

	inline public function setColor3(uniform:GLUniformLocation, color3:Color3) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform3f(uniform, color3.r, color3.g, color3.b);
	}

	inline public function setColor4(uniform:GLUniformLocation, color3:Color3, alpha:Float) {
		/*#if (cpp && lime)
		if (uniform == 0) return;
		#else
		if (uniform == null) return; 
		#end*/
		GL.uniform4f(uniform, color3.r, color3.g, color3.b, alpha);
	}

	// States
	inline public function setState(culling:Bool, zOffset:Float = 0, force:Bool = false, reverseSide:Bool = false) {
		// Culling        
		var showSide = reverseSide ? GL.FRONT : GL.BACK;
		var hideSide = reverseSide ? GL.BACK : GL.FRONT;
		var cullFace = this.cullBackFaces ? showSide : hideSide;
			
		if (this._depthCullingState.cull != culling || force || this._depthCullingState.cullFace != cullFace) {
			if (culling) {
				this._depthCullingState.cullFace = cullFace;
				this._depthCullingState.cull = true;
			} 
			else {
				this._depthCullingState.cull = false;
			}
		}
		
		// Z offset
		this._depthCullingState.zOffset = zOffset;
	}

	inline public function setDepthBuffer(enable:Bool) {
		this._depthCullingState.depthTest = enable;
	}

	inline public function getDepthWrite():Bool {
		return this._depthCullingState.depthMask;
	}

	inline public function setDepthWrite(enable:Bool) {
		this._depthCullingState.depthMask = enable;
	}

	inline public function setColorWrite(enable:Bool) {
		GL.colorMask(enable, enable, enable, enable);
	}

	inline public function setAlphaMode(mode:Int, noDepthWriteChange:Bool = false) {
		if (this._alphaMode == mode) {
            return;
        }
		
		switch (mode) {
			case Engine.ALPHA_DISABLE:
				this._alphaState.alphaBlend = false;
				
			case Engine.ALPHA_COMBINE:
				this._alphaState.setAlphaBlendFunctionParameters(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE, GL.ONE);
				this._alphaState.alphaBlend = true;
				
			case Engine.ALPHA_ONEONE:
				this._alphaState.setAlphaBlendFunctionParameters(GL.ONE, GL.ONE, GL.ZERO, GL.ONE);
				this._alphaState.alphaBlend = true;
				
			case Engine.ALPHA_ADD:
				this._alphaState.setAlphaBlendFunctionParameters(GL.SRC_ALPHA, GL.ONE, GL.ZERO, GL.ONE);
				this._alphaState.alphaBlend = true;
				
			case Engine.ALPHA_SUBTRACT:
				this._alphaState.setAlphaBlendFunctionParameters(GL.ZERO, GL.ONE_MINUS_SRC_COLOR, GL.ONE, GL.ONE);
				this._alphaState.alphaBlend = true;
				
			case Engine.ALPHA_MULTIPLY:
				this._alphaState.setAlphaBlendFunctionParameters(GL.DST_COLOR, GL.ZERO, GL.ONE, GL.ONE);
				this._alphaState.alphaBlend = true;
				
			case Engine.ALPHA_MAXIMIZED:
				this._alphaState.setAlphaBlendFunctionParameters(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_COLOR, GL.ONE, GL.ONE);
				this._alphaState.alphaBlend = true;
				
		}
		
		if (!noDepthWriteChange) {
			this.setDepthWrite(mode == Engine.ALPHA_DISABLE);
		}
		
		this._alphaMode = mode;
	}
	
	inline public function getAlphaMode():Int {
        return this._alphaMode;
    }

	inline public function setAlphaTesting(enable:Bool) {
		this._alphaTest = enable;
	}

	inline public function getAlphaTesting():Bool {
		return this._alphaTest;
	}

	// Textures
	public function wipeCaches() {
		this.resetTextureCache();
		this._currentEffect = null;
		
		this._depthCullingState.reset();
		this.setDepthFunctionToLessOrEqual();
		this._alphaState.reset();
		
		this._cachedVertexBuffers = null;
		this._cachedIndexBuffer = null;
		this._cachedEffectForVertexBuffers = null;
	}

	inline public function setSamplingMode(texture:WebGLTexture, samplingMode:Int) {
		this._bindTextureDirectly(GL.TEXTURE_2D, texture);
		
		var magFilter = GL.NEAREST;
		var minFilter = GL.NEAREST;
		
		if (samplingMode == Texture.BILINEAR_SAMPLINGMODE) {
			magFilter = GL.LINEAR;
			minFilter = GL.LINEAR;
		} 
		else if (samplingMode == Texture.TRILINEAR_SAMPLINGMODE) {
			magFilter = GL.LINEAR;
			minFilter = GL.LINEAR_MIPMAP_LINEAR;
		}
		
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, magFilter);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, minFilter);
		
		this._bindTextureDirectly(GL.TEXTURE_2D, null);
		
		texture.samplingMode = samplingMode;
	}
	
	public function createTexture(url:String, noMipmap:Bool, invertY:Bool, scene:Scene, samplingMode:Int = Texture.TRILINEAR_SAMPLINGMODE, onLoad:Void->Void = null, onError:Void->Void = null, buffer:Dynamic = null):WebGLTexture {
		
		var texture = new WebGLTexture(url, GL.createTexture());
		
		var extension:String = "";
		var fromData:Dynamic = null;
		if (url.substr(0, 5) == "data:") {
			fromData = true;
		}
		
		if (fromData == null) {
			extension = url.substr(url.length - 4, 4).toLowerCase();
		}
		else {
			var oldUrl = url;
			fromData = oldUrl.split(':');
			url = oldUrl;
			extension = fromData[1].substr(fromData[1].length - 4, 4).toLowerCase();
		}
		
		var isDDS = this.getCaps().s3tc && (extension == ".dds");
		var isTGA = (extension == ".tga");
		
		scene._addPendingData(texture);
		texture.url = url;
		texture.noMipmap = noMipmap;
		texture.references = 1;
		texture.samplingMode = samplingMode;
		this._loadedTexturesCache.push(texture);
		
		var onerror = function(e:Dynamic) {
			scene._removePendingData(texture);
			
			if (onError != null) {
				onError();
			}
		};
		
		if (isTGA) {
			/*var callback = function(arrayBuffer:Dynamic) {
				var data = new UInt8Array(arrayBuffer);
				
				var header = Internals.TGATools.GetTGAHeader(data);
				
				prepareTexture(texture, scene, header.width, header.height, invertY, noMipmap, false, () => {
					Internals.TGATools.UploadContent(GL, data);
					
					if (onLoad) {
						onLoad();
					}
				}, samplingMode);
			};
			
			if (!(fromData instanceof Array))
				Tools.LoadFile(url, arrayBuffer => {
					callback(arrayBuffer);
				}, onerror, scene.database, true);
			else
				callback(buffer);*/
				
		} else if (isDDS) {
			/*var callback = function(data:Dynamic) {
				var info = Internals.DDSTools.GetDDSInfo(data);
				
				var loadMipmap = (info.isRGB || info.isLuminance || info.mipmapCount > 1) && !noMipmap && ((info.width >> (info.mipmapCount - 1)) == 1);
				prepareTexture(texture, scene, info.width, info.height, invertY, !loadMipmap, info.isFourCC, () => {
				
					Internals.DDSTools.UploadDDSLevels(GL, this.getCaps().s3tc, data, info, loadMipmap, 1);
					
					if (onLoad) {
						onLoad();
					}
				}, samplingMode);
			};
			
			if (!(fromData instanceof Array))
				Tools.LoadFile(url, data => {
					callback(data);
				}, onerror, scene.database, true);
			else
				callback(buffer);*/
				
		} 
		else {
			var onload = function(img:Image) {
				prepareTexture(texture, scene, img.width, img.height, invertY, noMipmap, false, function(potWidth:Int, potHeight:Int) {	
					GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, potWidth, potHeight, 0, GL.RGBA, GL.UNSIGNED_BYTE, img.data);
					
					if (onLoad != null) {
						onLoad();
					}
				}, samplingMode);				
			};
			
			if (!Std.is(fromData, Array)) {
				Tools.LoadImage(url, onload, onerror, scene.database);
			}
			else {
				Tools.LoadImage(buffer, onload, onerror, scene.database);
			}
		}
		
		return texture;
	}
	
	/*function flipBitmapData(bd:BitmapData, axis:String = "y"):BitmapData {
		var matrix:openfl.geom.Matrix = if(axis == "x") {
		    new openfl.geom.Matrix( -1, 0, 0, 1, bd.width, 0);
		} else {
			new openfl.geom.Matrix( 1, 0, 0, -1, 0, bd.height);
		}
		
		bd.draw(bd, matrix, null, null, null, true);
		
		return bd;
	}*/
	
	public function updateTextureSize(texture:WebGLTexture, width:Int, height:Int) {
		texture._width = width;
		texture._height = height;
		texture._size = width * height;
		texture._baseWidth = width;
		texture._baseHeight = height;
	}
	
	public function createRawCubeTexture(url:String, scene:Scene, size:Int, format:Int, type:Int, noMipmap:Bool = false, callback:ArrayBuffer->Array<ArrayBufferView>, mipmmapGenerator:Array<ArrayBufferView>->Array<Array<ArrayBufferView>>):WebGLTexture {
		var texture = new WebGLTexture("", GL.createTexture());
		scene._addPendingData(texture);
		texture.isCube = true;
		texture.references = 1;
		texture.url = url;
		
		var internalFormat = this._getInternalFormat(format);
		
		var textureType = GL.UNSIGNED_BYTE;
		if (type == Engine.TEXTURETYPE_FLOAT) {
			textureType = GL.FLOAT;
		}
		
		var width = size;
		var height = width;
		var isPot = (com.babylonhx.math.Tools.IsExponentOfTwo(width) && com.babylonhx.math.Tools.IsExponentOfTwo(height));
		
		texture._width = width;
		texture._height = height;
		
		var onerror:Void->Void = function() {
			scene._removePendingData(texture);
		};
		
		var internalCallback = function(data:Dynamic) {
			var rgbeDataArrays = callback(data);
			
			var facesIndex = [
				GL.TEXTURE_CUBE_MAP_POSITIVE_X, GL.TEXTURE_CUBE_MAP_POSITIVE_Y, GL.TEXTURE_CUBE_MAP_POSITIVE_Z,
				GL.TEXTURE_CUBE_MAP_NEGATIVE_X, GL.TEXTURE_CUBE_MAP_NEGATIVE_Y, GL.TEXTURE_CUBE_MAP_NEGATIVE_Z
			];
			
			width = texture._width;
			height = texture._height;
			isPot = (com.babylonhx.math.Tools.IsExponentOfTwo(width) && com.babylonhx.math.Tools.IsExponentOfTwo(height));
			
			this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, texture);
			//GL.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
			
			if (!noMipmap && isPot) {
				if (mipmmapGenerator != null) {
					var arrayTemp:Array<ArrayBufferView> = [];
					// Data are known to be in +X +Y +Z -X -Y -Z
					// mipmmapGenerator data is expected to be order in +X -X +Y -Y +Z -Z
					arrayTemp.push(rgbeDataArrays[0]); // +X
					arrayTemp.push(rgbeDataArrays[3]); // -X
					arrayTemp.push(rgbeDataArrays[1]); // +Y
					arrayTemp.push(rgbeDataArrays[4]); // -Y
					arrayTemp.push(rgbeDataArrays[2]); // +Z
					arrayTemp.push(rgbeDataArrays[5]); // -Z
					
					var mipData = mipmmapGenerator(arrayTemp);
					for (level in 0...mipData.length) {
						var mipSize = width >> level;
						
						// mipData is order in +X -X +Y -Y +Z -Z
						GL.texImage2D(facesIndex[0], level, internalFormat, mipSize, mipSize, 0, internalFormat, textureType, mipData[level][0]);
						GL.texImage2D(facesIndex[1], level, internalFormat, mipSize, mipSize, 0, internalFormat, textureType, mipData[level][2]);
						GL.texImage2D(facesIndex[2], level, internalFormat, mipSize, mipSize, 0, internalFormat, textureType, mipData[level][4]);
						GL.texImage2D(facesIndex[3], level, internalFormat, mipSize, mipSize, 0, internalFormat, textureType, mipData[level][1]);
						GL.texImage2D(facesIndex[4], level, internalFormat, mipSize, mipSize, 0, internalFormat, textureType, mipData[level][3]);
						GL.texImage2D(facesIndex[5], level, internalFormat, mipSize, mipSize, 0, internalFormat, textureType, mipData[level][5]);
					}
				}
				else {
					// Data are known to be in +X +Y +Z -X -Y -Z
					for (index in 0...facesIndex.length) {
						var faceData = rgbeDataArrays[index];
						GL.texImage2D(facesIndex[index], 0, internalFormat, width, height, 0, internalFormat, textureType, faceData);
					}
					
					GL.generateMipmap(GL.TEXTURE_CUBE_MAP);
				}
			}
			else {
				noMipmap = true;
			}
			
			if (textureType == GL.FLOAT && !this._caps.textureFloatLinearFiltering) {
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
			}
			else {
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MIN_FILTER, noMipmap ? GL.LINEAR : GL.LINEAR_MIPMAP_LINEAR);
			}
			
			GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
			GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
			this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
			
			texture.isReady = true;
			
			this.resetTextureCache();
			scene._removePendingData(texture);
		};
		
		Tools.LoadFile(url, function(data:Dynamic) {
			internalCallback(data);
		}, "hdr");
		
		return texture;
	}
		
	public function createRawTexture(data:ArrayBufferView, width:Int, height:Int, format:Int, generateMipMaps:Bool, invertY:Bool, samplingMode:Int, compression:String = ""):WebGLTexture {
		
		var texture = new WebGLTexture("", GL.createTexture());
		texture._baseWidth = width;
		texture._baseHeight = height;
		texture._width = width;
		texture._height = height;
		texture.generateMipMaps = generateMipMaps;
		texture.samplingMode = samplingMode;
		texture.references = 1;
		
		this.updateRawTexture(texture, data, format, invertY, compression);
		
		this._loadedTexturesCache.push(texture);
		
		return texture;
	}
	
	private function _getInternalFormat(format:Int):Int {
		var internalFormat = GL.RGBA;
		switch (format) {
			case Engine.TEXTUREFORMAT_ALPHA:
				internalFormat = GL.ALPHA;
				
			case Engine.TEXTUREFORMAT_LUMINANCE:
				internalFormat = GL.LUMINANCE;
				
			case Engine.TEXTUREFORMAT_LUMINANCE_ALPHA:
				internalFormat = GL.LUMINANCE_ALPHA;
				
			case Engine.TEXTUREFORMAT_RGB:
				internalFormat = GL.RGB;
				
			case Engine.TEXTUREFORMAT_RGBA:
				internalFormat = GL.RGBA;
				
		}
		
		return internalFormat;
	}
	
	inline public function updateRawTexture(texture:WebGLTexture, data:ArrayBufferView, format:Int, invertY:Bool = false, compression:String = "") {
		var internalFormat = this._getInternalFormat(format);
		
		this._bindTextureDirectly(GL.TEXTURE_2D, texture);
		//GL.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, invertY ? 1 : 0);      
		
		if (texture._width % 4 != 0) {
            GL.pixelStorei(GL.UNPACK_ALIGNMENT, 1);
        }
		
		if (compression != "") {
            GL.compressedTexImage2D(GL.TEXTURE_2D, 0, Reflect.getProperty(this.getCaps().s3tc, compression), texture._width, texture._height, 0, data);
        } 
		else {
            GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, texture._width, texture._height, 0, internalFormat, GL.UNSIGNED_BYTE, data);
        }
		
		// Filters
		var filters = getSamplingParameters(texture.samplingMode, texture.generateMipMaps);		
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filters.mag);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filters.min);
		
		if (texture.generateMipMaps) {
			GL.generateMipmap(GL.TEXTURE_2D);
		}
		
		this._bindTextureDirectly(GL.TEXTURE_2D, null);
		this.resetTextureCache();
		texture.isReady = true;
	}

	public function createDynamicTexture(width:Int, height:Int, generateMipMaps:Bool, samplingMode:Int):WebGLTexture {
		var texture = new WebGLTexture("", GL.createTexture());
		
		texture._baseWidth = width;
		texture._baseHeight = height;
		
        if (generateMipMaps) {
		    width = com.babylonhx.math.Tools.GetExponentOfTwo(width, this._caps.maxTextureSize);
		    height = com.babylonhx.math.Tools.GetExponentOfTwo(height, this._caps.maxTextureSize);
        }
		
		this.resetTextureCache();		
		texture._width = width;
		texture._height = height;
		texture.isReady = false;
		texture.generateMipMaps = generateMipMaps;
		texture.references = 1;
		texture.samplingMode = samplingMode;
		
		this.updateTextureSamplingMode(samplingMode, texture);
		
		this._loadedTexturesCache.push(texture);
		
		return texture;
	}
	
	inline public function updateDynamicTexture(texture:WebGLTexture, canvas:Image, invertY:Bool, premulAlpha:Bool = false) {
		this._bindTextureDirectly(GL.TEXTURE_2D, texture);
		//GL.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, invertY ? 1 : 0);
		if (premulAlpha) {
            GL.pixelStorei(GL.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
        }
		GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, canvas.width, canvas.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, cast canvas.data);
		if (texture.generateMipMaps) {
			GL.generateMipmap(GL.TEXTURE_2D);
		}
		this._bindTextureDirectly(GL.TEXTURE_2D, null);
		this.resetTextureCache();
		texture.isReady = true;
	}
	
	inline public function updateTextureSamplingMode(samplingMode:Int, texture:WebGLTexture) {
		var filters = getSamplingParameters(samplingMode, texture.generateMipMaps);
		
		if (texture.isCube) {
			this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, texture);
			
			GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MAG_FILTER, filters.mag);
            GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MIN_FILTER, filters.min);
            this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
		}
		else {
			this._bindTextureDirectly(GL.TEXTURE_2D, texture);
			
			GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filters.mag);
			GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filters.min);
			this._bindTextureDirectly(GL.TEXTURE_2D, null);
		}
	}

	public function updateVideoTexture(texture:WebGLTexture, video:Dynamic, invertY:Bool) {
        #if (html5 || js || web || purejs)
		
        if (texture._isDisabled) {
            return;
		}
		
        this._bindTextureDirectly(GL.TEXTURE_2D, texture);
        GL.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, invertY ? 0 : 1); // Video are upside down by default
		
        try {
            // Testing video texture support
            if(_videoTextureSupported == null) {
                untyped GL.context.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, video);
                if(GL.getError() != 0) {
                    _videoTextureSupported = false;
				}
                else {
                    _videoTextureSupported = true;
				}
            }
			
            // Copy video through the current working canvas if video texture is not supported
            if (!_videoTextureSupported) {
                if(texture._workingCanvas == null) {
                    texture._workingCanvas = cast(Browser.document.createElement("canvas"), js.html.CanvasElement);
                    texture._workingContext = texture._workingCanvas.getContext("2d");
                    texture._workingCanvas.width = texture._width;
                    texture._workingCanvas.height = texture._height;
                }
				
                texture._workingContext.drawImage(video, 0, 0, video.videoWidth, video.videoHeight, 0, 0, texture._width, texture._height);
				
                untyped GL.context.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, texture._workingCanvas);
            }
            else {
                untyped GL.context.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, cast(video, js.html.VideoElement));
            }
			
            if(texture.generateMipMaps) {
                GL.generateMipmap(GL.TEXTURE_2D);
            }
			
            this._bindTextureDirectly(GL.TEXTURE_2D, null);
            resetTextureCache();
            texture.isReady = true;
        }
        catch(e:Dynamic) {
            // Something unexpected
            // Let's disable the texture
            texture._isDisabled = true;
        }
		
        #end
	}

	public function createRenderTargetTexture(size:Dynamic, options:Dynamic):WebGLTexture {
		// old version had a "generateMipMaps" arg instead of options.
		// if options.generateMipMaps is undefined, consider that options itself if the generateMipmaps value
		// in the same way, generateDepthBuffer is defaulted to true
		var generateMipMaps = false;
		var generateDepthBuffer = true;
		var type = Engine.TEXTURETYPE_UNSIGNED_INT;
		var samplingMode = Texture.TRILINEAR_SAMPLINGMODE;
		if (options != null) {
            generateMipMaps = options.generateMipMaps != null ? options.generateMipMaps : options;
            generateDepthBuffer = options.generateDepthBuffer != null ? options.generateDepthBuffer : true;
			type = options.type == null ? type : options.type;
            if (options.samplingMode != null) {
                samplingMode = options.samplingMode;
            }
			if (type == Engine.TEXTURETYPE_FLOAT) {
				// if floating point (gl.FLOAT) then force to NEAREST_SAMPLINGMODE
				samplingMode = Texture.NEAREST_SAMPLINGMODE;
			}
        }
		
		var texture = new WebGLTexture("", GL.createTexture());
		this._bindTextureDirectly(GL.TEXTURE_2D, texture);
		
		var width:Int = size.width != null ? size.width : size;
        var height:Int = size.height != null ? size.height : size;
		
		var filters = getSamplingParameters(samplingMode, generateMipMaps);
		
		if (type == Engine.TEXTURETYPE_FLOAT && !this._caps.textureFloat) {
			type = Engine.TEXTURETYPE_UNSIGNED_INT;
			trace("Float textures are not supported. Render target forced to TEXTURETYPE_UNSIGNED_BYTE type");
		}
		
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filters.mag);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filters.min);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		
		#if (snow && cpp)
		var arrBuffEmpty:ArrayBufferView = null;
		GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, getWebGLTextureType(type), arrBuffEmpty);
		#else
		GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, getWebGLTextureType(type), null);
		#end
		
		var depthBuffer:GLRenderbuffer = null;
		// Create the depth buffer
		if (generateDepthBuffer) {
			depthBuffer = GL.createRenderbuffer();
			GL.bindRenderbuffer(GL.RENDERBUFFER, depthBuffer);
			GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, width, height);
		}
		// Create the framebuffer
		var framebuffer = GL.createFramebuffer();
		this.bindUnboundFramebuffer(framebuffer);
		if (generateDepthBuffer) {
			GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, depthBuffer);
		}
		
		if (generateMipMaps) {
			GL.generateMipmap(GL.TEXTURE_2D);
		}
		
		// Unbind
		this._bindTextureDirectly(GL.TEXTURE_2D, null);
		GL.bindRenderbuffer(GL.RENDERBUFFER, null);
		this.bindUnboundFramebuffer(null);
		
		texture._framebuffer = framebuffer;
		if (generateDepthBuffer) {
			texture._depthBuffer = depthBuffer;
		}
		texture._baseWidth = width;
		texture._baseHeight = height;
		texture._width = width;
		texture._height = height;
		texture.isReady = true;
		texture.generateMipMaps = generateMipMaps;
		texture.references = 1;
		texture.samplingMode = samplingMode;
		texture.type = type;
		this.resetTextureCache();
		
		this._loadedTexturesCache.push(texture);
		
		return texture;
	}
	
	public function createRenderTargetCubeTexture(size:Dynamic, ?options:Dynamic):WebGLTexture {
		var texture = new WebGLTexture("", GL.createTexture());
		
		var generateMipMaps:Bool = true;
		var samplingMode:Int = Texture.TRILINEAR_SAMPLINGMODE;
		if (options != null) {
			generateMipMaps = options.generateMipMaps == null ? options : options.generateMipMaps;
			if (options.samplingMode != null) {
				samplingMode = options.samplingMode;
			}
		}
		
		texture.isCube = true;
		texture.references = 1;
		texture.generateMipMaps = generateMipMaps;
		texture.references = 1;
		texture.samplingMode = samplingMode;
		
		var filters = getSamplingParameters(samplingMode, generateMipMaps);
		
		this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, texture);
		
		for (face in 0...6) {
			#if (snow && cpp)
			var arrBuffEmtpy:ArrayBufferView = null;
			GL.texImage2D(GL.TEXTURE_CUBE_MAP_POSITIVE_X + face, 0, GL.RGBA, size.width, size.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, arrBuffEmtpy);
			#else
			GL.texImage2D(GL.TEXTURE_CUBE_MAP_POSITIVE_X + face, 0, GL.RGBA, size.width, size.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
			#end
		}
		
		GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MAG_FILTER, filters.mag);
		GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MIN_FILTER, filters.min);
		GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		
		// Create the depth buffer
		var depthBuffer = GL.createRenderbuffer();
		GL.bindRenderbuffer(GL.RENDERBUFFER, depthBuffer);
		GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, size.width, size.height);
		
		// Create the framebuffer
		var framebuffer = GL.createFramebuffer();
		this.bindUnboundFramebuffer(framebuffer);
		GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, depthBuffer);
		
		// Mipmaps
        if (texture.generateMipMaps) {
            this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, texture);
            GL.generateMipmap(GL.TEXTURE_CUBE_MAP);
        }
		
		// Unbind
		this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
		GL.bindRenderbuffer(GL.RENDERBUFFER, null);
		this.bindUnboundFramebuffer(null);
		
		texture._framebuffer = framebuffer;
		texture._depthBuffer = depthBuffer;
		
		this.resetTextureCache();
		
		texture._width = size.width;
		texture._height = size.height;
		texture.isReady = true;
		
		return texture;
	}

	public function createCubeTexture(rootUrl:String, scene:Scene, files:Array<String> = null, noMipmap:Bool = false):WebGLTexture {
		var texture = new WebGLTexture(rootUrl, GL.createTexture());
		texture.isCube = true;
		texture.url = rootUrl;
		texture.references = 1;
		//this._loadedTexturesCache.push(texture);
		
		var extension = rootUrl.substr(rootUrl.length - 4, 4).toLowerCase();
		var isDDS = this.getCaps().s3tc && (extension == ".dds");
		
		if (isDDS) {
			/*Tools.LoadFile(rootUrl, data => {
				var info = Internals.DDSTools.GetDDSInfo(data);
				
				var loadMipmap = (info.isRGB || info.isLuminance || info.mipmapCount > 1) && !noMipmap;
				
				gl.bindTexture(gl.TEXTURE_CUBE_MAP, texture);
				gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1);
				
				Internals.DDSTools.UploadDDSLevels(GL, this.getCaps().s3tc, data, info, loadMipmap, 6);
				
				if (!noMipmap && !info.isFourCC && info.mipmapCount == 1) {
					gl.generateMipmap(gl.TEXTURE_CUBE_MAP);
				}
				
				gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
				gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, loadMipmap ? gl.LINEAR_MIPMAP_LINEAR :gl.LINEAR);
				gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
				gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
				
				gl.bindTexture(gl.TEXTURE_CUBE_MAP, null);
				
				this._activeTexturesCache = [];
				
				texture._width = info.width;
				texture._height = info.height;
				texture.isReady = true;
			}, null, null, true);*/
		} 
		else {
			
			var faces = [
				GL.TEXTURE_CUBE_MAP_POSITIVE_X, GL.TEXTURE_CUBE_MAP_POSITIVE_Y, GL.TEXTURE_CUBE_MAP_POSITIVE_Z,
				GL.TEXTURE_CUBE_MAP_NEGATIVE_X, GL.TEXTURE_CUBE_MAP_NEGATIVE_Y, GL.TEXTURE_CUBE_MAP_NEGATIVE_Z
			];
			
			var imgs:Array<Image> = [];
			
			function _setTex(img:Image, index:Int) {					
				/*var potWidth = Tools.GetExponantOfTwo(img.image.width, this._caps.maxTextureSize);
				var potHeight = Tools.GetExponantOfTwo(img.image.height, this._caps.maxTextureSize);
				var isPot = (img.image.width == potWidth && img.image.height == potHeight);*/
				this._workingCanvas = img;
					
				GL.texImage2D(faces[index], 0, GL.RGBA, this._workingCanvas.width, this._workingCanvas.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, img.data);
			}
			
			function generate() {
				var width = com.babylonhx.math.Tools.GetExponentOfTwo(imgs[0].width, this._caps.maxCubemapTextureSize);
				var height = width;
				
				this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, texture);
				
				/*#if js
				GL.pixelStorei(GL.UNPACK_FLIP_Y_WEBGL, 0);
				#end*/
					
				for (index in 0...faces.length) {
					_setTex(imgs[index], index);
				}
				
				if (!noMipmap) {
					GL.generateMipmap(GL.TEXTURE_CUBE_MAP);
				}
				
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_MIN_FILTER, noMipmap ? GL.LINEAR :GL.LINEAR_MIPMAP_LINEAR);
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
				
				this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
				
				this.resetTextureCache();
				
				texture._width = width;
				texture._height = height;
				texture.isReady = true;
			}
			
			var i:Int = 0;
			
			function loadImage() {
				Tools.LoadImage(files[i], function(bd:Image) {
					imgs.push(bd);
					if (++i == files.length) {
						generate();
					} 
					else {
						loadImage();
					}
				});
			}
			
			loadImage();
		}
		
		return texture;
	}

	public function _releaseTexture(texture:WebGLTexture) {
		if (texture._framebuffer != null) {
			GL.deleteFramebuffer(texture._framebuffer);
		}
		
		if (texture._depthBuffer != null) {
			GL.deleteRenderbuffer(texture._depthBuffer);
		}
		
		GL.deleteTexture(texture.data);
		
		// Unbind channels
		this.unbindAllTextures();		
		
		var index = this._loadedTexturesCache.indexOf(texture);
		if (index != -1) {
			this._loadedTexturesCache.splice(index, 1);
		}
		
		texture = null;
	}
	
	public function unbindAllTextures() {
		for (channel in 0...this._caps.maxTexturesImageUnits) {
			this.activateTexture(getGLTexture(channel));
            this._bindTextureDirectly(GL.TEXTURE_2D, null);
            this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
		}
	}
	
	inline function getGLTexture(channel:Int):Int {
		return GL.TEXTURE0 + channel;
	}
	
	inline function setProgram(program:GLProgram) {
        if (this._currentProgram != program) {
            GL.useProgram(program);
            this._currentProgram = program;
        }
    }

	inline public function bindSamplers(effect:Effect) {
		this.setProgram(effect.getProgram());
		var samplers = effect.getSamplers();
		
		for (index in 0...samplers.length) {
			var uniform = effect.getUniform(samplers[index]);
			GL.uniform1i(uniform, index);
		}
		this._currentEffect = null;
	}
	
	inline private function activateTexture(texture:Int) {
        if (this._activeTexture != texture - GL.TEXTURE0) {
            GL.activeTexture(texture);
            this._activeTexture = texture - GL.TEXTURE0;
        }
    }

    inline public function _bindTextureDirectly(target:Int, texture:WebGLTexture = null) {
        if (this._activeTexturesCache[this._activeTexture] != texture) {
            texture != null ? GL.bindTexture(target, texture.data) : GL.bindTexture(target, null);
            this._activeTexturesCache[this._activeTexture] = texture;
        }
    }

	inline public function _bindTexture(channel:Int, texture:WebGLTexture) {
		if (channel < 0) {
			return;
		}
		
		this.activateTexture(getGLTexture(channel));
		this._bindTextureDirectly(GL.TEXTURE_2D, texture);
	}

	inline public function setTextureFromPostProcess(channel:Int, postProcess:PostProcess) {
		if (postProcess._textures.length > 0) {
			this._bindTexture(channel, postProcess._textures.data[postProcess._currentRenderTextureInd]);
		}
	}

	public function setTexture(channel:Int, uniform:GLUniformLocation, texture:BaseTexture) {
		if (channel < 0) {
			return;
		}
		
		GL.uniform1i(uniform, channel);
		this._setTexture(channel, texture);
	}
	
	private function _setTexture(channel:Int, texture:BaseTexture) {
		// Not ready?
		if (texture == null || !texture.isReady()) {
			if (this._activeTexturesCache[channel] != null) {
				this.activateTexture(getGLTexture(channel));
                this._bindTextureDirectly(GL.TEXTURE_2D, null);
                this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, null);
			}
			
			return;
		}
		
		// Video
        var alreadyActivated = false;
		if (Std.is(texture, VideoTexture)) {
            this.activateTexture(getGLTexture(channel));
            alreadyActivated = true;
            cast(texture, VideoTexture).update();
		} 
		else if (texture.delayLoadState == Engine.DELAYLOADSTATE_NOTLOADED) { // Delay loading
			texture.delayLoad();
			return;
		}
		
		var internalTexture = texture.getInternalTexture();
		
		if (this._activeTexturesCache[channel] == internalTexture) {
			return;
		}
		
        if(!alreadyActivated) {
            this.activateTexture(getGLTexture(channel));
        }
		
		if (internalTexture.isCube) {
			this._bindTextureDirectly(GL.TEXTURE_CUBE_MAP, internalTexture);
			
			if (internalTexture._cachedCoordinatesMode != texture.coordinatesMode) {
				internalTexture._cachedCoordinatesMode = texture.coordinatesMode;
				// CUBIC_MODE and SKYBOX_MODE both require CLAMP_TO_EDGE.  All other modes use REPEAT.
				var textureWrapMode = (texture.coordinatesMode != Texture.CUBIC_MODE && texture.coordinatesMode != Texture.SKYBOX_MODE) ? GL.REPEAT : GL.CLAMP_TO_EDGE;
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_S, textureWrapMode);
				GL.texParameteri(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_WRAP_T, textureWrapMode);
			}
			
			this._setAnisotropicLevel(GL.TEXTURE_CUBE_MAP, texture);
		} 
		else {
			this._bindTextureDirectly(GL.TEXTURE_2D, internalTexture);
			
			if (internalTexture._cachedWrapU != texture.wrapU) {
				internalTexture._cachedWrapU = texture.wrapU;
				
				switch (texture.wrapU) {
					case Texture.WRAP_ADDRESSMODE:
						GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT);
						
					case Texture.CLAMP_ADDRESSMODE:
						GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
						
					case Texture.MIRROR_ADDRESSMODE:
						GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.MIRRORED_REPEAT);
						
				}
			}
			
			if (internalTexture._cachedWrapV != texture.wrapV) {
				internalTexture._cachedWrapV = texture.wrapV;
				switch (texture.wrapV) {
					case Texture.WRAP_ADDRESSMODE:
						GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT);
						
					case Texture.CLAMP_ADDRESSMODE:
						GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
						
					case Texture.MIRROR_ADDRESSMODE:
						GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.MIRRORED_REPEAT);
						
				}
			}
			
			this._setAnisotropicLevel(GL.TEXTURE_2D, texture);
		}
	}
	
	public function setTextureArray(channel:Int, uniform:GLUniformLocation, textures:Array<BaseTexture>) {
		if (channel < 0) {
			return;
		}
		
		if (this._textureUnits == null || this._textureUnits.length != textures.length) {
			this._textureUnits = new Int32Array(textures.length);
		}
		for (i in 0...textures.length) {
			this._textureUnits[i] = channel + i;
		}
		GL.uniform1iv(uniform, this._textureUnits);
		
		for (index in 0...textures.length) {
			this._setTexture(channel + index, textures[index]);
		}
	}

	public function _setAnisotropicLevel(key:Int, texture:BaseTexture) {
		var anisotropicFilterExtension = this._caps.textureAnisotropicFilterExtension;
		
		var value = texture.anisotropicFilteringLevel;
		
		if (texture.getInternalTexture().samplingMode == Texture.NEAREST_SAMPLINGMODE) {
			value = 1;
		}
		
		if (anisotropicFilterExtension != null && texture._cachedAnisotropicFilteringLevel != value) {
			GL.texParameterf(key, anisotropicFilterExtension.TEXTURE_MAX_ANISOTROPY_EXT, Math.min(texture.anisotropicFilteringLevel, this._caps.maxAnisotropy));
			texture._cachedAnisotropicFilteringLevel = value;
		}
	}

	inline public function readPixels(x:Int, y:Int, width:Int, height:Int): #if (js || purejs) UInt8Array #else Array<Int> #end {
		var data = #if (js || purejs) new UInt8Array(height * width * 4) #else [] #end ;
		GL.readPixels(x, y, width, height, GL.RGBA, GL.UNSIGNED_BYTE, cast data);
		
		return data;
	}

	// Dispose
	public function dispose() {
		// TODO
		//this.hideLoadingUI();
		
		this.stopRenderLoop();
		
		// Release scenes
		while (this.scenes.length > 0) {
			this.scenes[0].dispose();
			this.scenes[0] = null;
			this.scenes.shift();
		}
		
		// Release effects
		for (name in this._compiledEffects.keys()) {
			GL.deleteProgram(this._compiledEffects[name]._program);
		}
	}
	
	#if purejs
	// Statics
	public static function isSupported():Bool {
		try {
			// Avoid creating an unsized context for CocoonJS, since size determined on first creation.  Is not resizable
			if (untyped Browser.navigator.isCocoonJS) {
				return true;
			}
			var tempcanvas = Browser.document.createElement("canvas");
			var gl = untyped tempcanvas.getContext("webgl") || tempcanvas.getContext("experimental-webgl");
			
			return gl != null && untyped !!window.WebGLRenderingContext;
		} 
		catch (e:Dynamic) {
			return false;
		}
	}
	#end
}
