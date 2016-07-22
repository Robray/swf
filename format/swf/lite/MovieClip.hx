package format.swf.lite;


import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.Graphics;
import flash.display.PixelSnapping;
import flash.display.Shape;
import flash.events.Event;
import flash.filters.*;
import flash.Lib;
import format.swf.lite.symbols.BitmapSymbol;
import format.swf.lite.symbols.ButtonSymbol;
import format.swf.lite.symbols.DynamicTextSymbol;
import format.swf.lite.symbols.ShapeSymbol;
import format.swf.lite.symbols.SpriteSymbol;
import format.swf.lite.symbols.StaticTextSymbol;
import format.swf.lite.timeline.FrameObject;
import format.swf.lite.timeline.FrameObjectType;
import format.swf.lite.SWFLite;
import openfl.display.BitmapDataChannel;
import openfl.display.FrameLabel;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl._internal.renderer.RenderSession;

#if openfl
import openfl.Assets;
#end

#if (lime && !openfl_legacy)
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.ImageChannel;
import lime.math.Vector2;
import lime.Assets in LimeAssets;
#end


class MovieClip extends flash.display.MovieClip {


	@:noCompletion private var __frameTime:Int;
	@:noCompletion private var __lastUpdate:Int;
	@:noCompletion private var __objects:Map<Int, DisplayObject>;
	@:noCompletion private var __playing:Bool;
	@:noCompletion private var __swf:SWFLite;
	@:noCompletion private var __symbol:SpriteSymbol;
	@:noCompletion private var __timeElapsed:Int;
	@:noCompletion private var __zeroSymbol:Int;
	@:noCompletion private var __drawingBitmapData:Bool;

	#if flash
	@:noCompletion private var __currentFrame:Int;
	@:noCompletion private var __previousTime:Int;
	@:noCompletion private var __totalFrames:Int;
	@:noCompletion private var __currentLabels:Array<FrameLabel>;
	#end

	private var __9SliceBitmap:BitmapData;

	private var __SWFDepthData:Map<DisplayObject, Int>;
	private var __maskData:Map<DisplayObject, Int>;

	public function new (swf:SWFLite, symbol:SpriteSymbol) {

		super ();

		__swf = swf;
		__symbol = symbol;

		__lastUpdate = 1;
		__objects = new Map ();
		__zeroSymbol = -1;
		__drawingBitmapData = false;

		__currentFrame = 1;
		__totalFrames = __symbol.frames.length;

		__SWFDepthData = new Map();
		__maskData = new Map();

		__currentLabels = [];

		for (i in 0...__symbol.frames.length) {

			if (__symbol.frames[i].label != null) {

				__currentLabels.push (new FrameLabel (__symbol.frames[i].label, i + 1));

			}

		}

		#if (!flash && openfl && !openfl_legacy)
		__setRenderDirty();
		#end

		if (__totalFrames > 1) {

			#if flash
			__previousTime = Lib.getTimer ();
			Lib.current.stage.addEventListener (Event.ENTER_FRAME, stage_onEnterFrame, false, 0, true);
			play ();
			#elseif (openfl && !openfl_legacy)
			play ();
			#end

		}

		__renderFrame (0);

	}


	/*public override function flatten ():Void {

		var bounds = getBounds (this);
		var bitmapData = null;

		if (bounds.width > 0 && bounds.height > 0) {

			bitmapData = new BitmapData (Std.int (bounds.width), Std.int (bounds.height), true, #if neko { a: 0, rgb: 0x000000 } #else 0x00000000 #end);
			var matrix = new Matrix ();
			matrix.translate (-bounds.left, -bounds.top);
			bitmapData.draw (this, matrix);

		}

		for (i in 0...numChildren) {

			var child = getChildAt (0);

			if (Std.is (child, MovieClip)) {

				untyped child.stop ();

			}

			removeChildAt (0);

		}

		if (bounds.width > 0 && bounds.height > 0) {

			var bitmap = new Bitmap (bitmapData);
			bitmap.smoothing = true;
			bitmap.x = bounds.left;
			bitmap.y = bounds.top;
			addChild (bitmap);

		}

	}*/


	public override function gotoAndPlay (frame:#if flash flash.utils.Object #else Dynamic #end, scene:String = null):Void {

		play ();			
		var target = __getFrame (frame);
		
		do{
			__currentFrame = target;
			__updateFrame ();
		} while(target != __currentFrame);
			
	}


	public override function gotoAndStop (frame:#if flash flash.utils.Object #else Dynamic #end, scene:String = null):Void {

		play ();
		var target = __getFrame (frame);
		
		do{
			__currentFrame = target;
			__updateFrame ();
		} while(target != __currentFrame);
		
		stop ();

	}


	public override function nextFrame ():Void {

		var next = __currentFrame + 1;

		if (next > __totalFrames) {

			next = __totalFrames;

		}

		gotoAndStop (next);

	}


	public override function play ():Void {

		if (!__playing && __totalFrames > 1) {

			__playing = true;

			#if !swflite_parent_fps
			__frameTime = Std.int (1000 / __swf.frameRate);
			__timeElapsed = 0;
			#end

		}

	}


	public override function prevFrame ():Void {

		var previous = __currentFrame - 1;

		if (previous < 1) {

			previous = 1;

		}

		gotoAndStop (previous);

	}


	public override function stop ():Void {

		if (__playing) {

			__playing = false;

		}

	}


	#if flash
	@:getter(currentLabels)
	private function get_currentLabels():Array<FrameLabel> {

		return __currentLabels;

	}
	#end


	public function unflatten ():Void {

		__lastUpdate = 0;
		__updateFrame ();

	}


	@:noCompletion private inline function __applyTween (start:Float, end:Float, ratio:Float):Float {

		return start + ((end - start) * ratio);

	}


	@:noCompletion private function __createObject (object:FrameObject):DisplayObject {

		var displayObject:DisplayObject = null;

		if (__swf.symbols.exists (object.symbol)) {

			var symbol = __swf.symbols.get (object.symbol);

			if( symbol.className != null)
			{
				var _class: Class<Dynamic> = __swf.classes.get(symbol.className);

				if( _class != null )
				{
					return Type.createInstance( _class, [ __swf, symbol]);
				}
			}

			if( __swf.classes_id.exists( object.symbol ))
			{
				var _class: Class<Dynamic> = __swf.classes_id.get(object.symbol);

				if( _class != null )
				{
					return Type.createInstance( _class, [ __swf, symbol]);
				}
			}

			if (Std.is (symbol, SpriteSymbol)) {

				displayObject = new MovieClip (__swf, cast symbol);

			} else if (Std.is (symbol, ShapeSymbol)) {

				displayObject = __createShape (cast symbol);

			} else if (Std.is (symbol, BitmapSymbol)) {

				displayObject = new Bitmap (__getBitmap (cast symbol), PixelSnapping.AUTO, true);

			} else if (Std.is (symbol, DynamicTextSymbol)) {

				displayObject = new DynamicTextField (__swf, cast symbol);

			} else if (Std.is (symbol, StaticTextSymbol)) {

				displayObject = new StaticTextField (__swf, cast symbol);

			} else if (Std.is (symbol, ButtonSymbol)) {

				displayObject = new SimpleButton (__swf, cast symbol);

			}

		}

		return displayObject;

	}


	@:noCompletion private function __createShape (symbol:ShapeSymbol):Shape {

		var shape = new Shape ();
		var graphics = shape.graphics;

		for (command in symbol.commands) {

			switch (command) {

				case BeginFill (color, alpha):

					graphics.beginFill (color, alpha);

				case BeginBitmapFill (bitmapID, matrix, repeat, smooth):

					#if openfl

					var bitmap:BitmapSymbol = cast __swf.symbols.get (bitmapID);

					if (bitmap != null && bitmap.path != "") {

						graphics.beginBitmapFill (__getBitmap (bitmap), matrix, repeat, smooth);

					}

					#end

				case BeginGradientFill (fillType, colors, alphas, ratios, matrix, spreadMethod, interpolationMethod, focalPointRatio):

					#if (cpp || neko)
					shape.cacheAsBitmap = true;
					#end
					graphics.beginGradientFill (fillType, colors, alphas, ratios, matrix, spreadMethod, interpolationMethod, focalPointRatio);

				case CurveTo (controlX, controlY, anchorX, anchorY):

					#if (cpp || neko)
					shape.cacheAsBitmap = true;
					#end
					graphics.curveTo (controlX, controlY, anchorX, anchorY);

				case EndFill:

					graphics.endFill ();

				case LineStyle (thickness, color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit):

					if (thickness != null) {

						graphics.lineStyle (thickness, color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit);

					} else {

						graphics.lineStyle ();

					}

				case LineTo (x, y):

					graphics.lineTo (x, y);

				case MoveTo (x, y):

					graphics.moveTo (x, y);

			}

		}

		return shape;

	}


	@:noCompletion @:dox(hide) public #if (!flash && openfl && !openfl_legacy) override #end function __enterFrame (deltaTime:Int):Void {

		if (__playing) {

			#if !swflite_parent_fps
			__timeElapsed += deltaTime;
			var advanceFrames = Math.floor (__timeElapsed / __frameTime);
			__timeElapsed = (__timeElapsed % __frameTime);
			#else
			var advanceFrames = (__lastUpdate == __currentFrame) ? 1 : 0;
			#end

			__currentFrame += advanceFrames;

			while (__currentFrame > __totalFrames) {

				__currentFrame -= __totalFrames;

			}

			__updateFrame ();

		}

		#if (!flash && openfl && !openfl_legacy)
		super.__enterFrame (deltaTime);
		#end

	}


	@:noCompletion private function __getBitmap (symbol:BitmapSymbol):BitmapData {

		#if openfl

		if (Assets.cache.hasBitmapData (symbol.path)) {

			return Assets.cache.getBitmapData (symbol.path);

		} else {

			#if !openfl_legacy

			var source = LimeAssets.getImage (symbol.path, false);

			if (source != null && symbol.alpha != null && symbol.alpha != "") {

				#if flash
				var cache = source;
				var buffer = new ImageBuffer (null, source.width, source.height);
				buffer.src = new BitmapData (source.width, source.height, true, 0);
				source = new Image (buffer);
				source.copyPixels (cache, cache.rect, new Vector2 (), null, null, false);
				#end

				var alpha = LimeAssets.getImage (symbol.alpha, false);
				source.copyChannel (alpha, alpha.rect, new Vector2 (), ImageChannel.RED, ImageChannel.ALPHA);
				
				//symbol.alpha = null;
				source.buffer.premultiplied = true;
				
				#if !sys
				source.premultiplied = false;
				#end
				
			}

			#if !flash
			var bitmapData = BitmapData.fromImage (source);
			#else
			var bitmapData = source.src;
			#end

			Assets.cache.setBitmapData (symbol.path, bitmapData);
			return bitmapData;

			#else

			var bitmapData = Assets.getBitmapData (symbol.path, false);

			if (bitmapData != null && symbol.alpha != null && symbol.alpha != "") {

				var cache = bitmapData;
				bitmapData = new BitmapData (cache.width, cache.height, true, 0);
				bitmapData.copyPixels (cache, cache.rect, new Point (), null, null, false);

				var alpha = Assets.getBitmapData (symbol.alpha, false);
				bitmapData.copyChannel (alpha, alpha.rect, new Point (), BitmapDataChannel.RED, BitmapDataChannel.ALPHA);
				//symbol.alpha = null;

				bitmapData.unmultiplyAlpha ();

			}

			Assets.cache.setBitmapData (symbol.path, bitmapData);
			return bitmapData;

			#end

		}

		#else

		return null;

		#end

	}


	@:noCompletion private function __getFrame (frame:Dynamic):Int {

		var index:Int = 0;
		
		var index:Int = 0;	
		
		if (Std.is (frame, Int)) {

			index = cast frame;

		} else if (Std.is (frame, String)) {

			var label:String = cast frame;

			for (i in 0...__symbol.frames.length) {

				if (__symbol.frames[i].label == label) {

					index = i + 1;
					break;
				}

			}

		}

		if (index < 1){
			index = 1;
		} else if (index > __totalFrames){
			index = __totalFrames;
		}
		
		return index;
	}


	@:noCompletion private function __placeObject (displayObject:DisplayObject, frameObject:FrameObject):Void {

		if (frameObject.name != null) {

			displayObject.name = frameObject.name;

		}

		if (frameObject.matrix != null) {
		
			displayObject.transform.matrix = frameObject.matrix;
			
			var dynamicTextField:DynamicTextField;
			
			if (Std.is (displayObject, DynamicTextField)) {
				
				dynamicTextField = cast displayObject;
				
				displayObject.x += dynamicTextField.symbol.x;
				displayObject.y += dynamicTextField.symbol.y #if flash + 4 #end;

			}
		}

		if (frameObject.colorTransform != null) {

			displayObject.transform.colorTransform = frameObject.colorTransform;

		}

		if (frameObject.blendMode != null) {
			displayObject.blendMode = frameObject.blendMode;
		}

		if (frameObject.filters != null) {

			var filters:Array<BitmapFilter> = [];

			for (filter in frameObject.filters) {

				switch (filter) {

					case BlurFilter (blurX, blurY, quality):

						filters.push (new BlurFilter (blurX, blurY, quality));

					case ColorMatrixFilter (matrix):

						filters.push (new ColorMatrixFilter (matrix));

					case DropShadowFilter (distance, angle, color, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject):

						filters.push (new DropShadowFilter (distance, angle, color, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject));

					case GlowFilter (color, alpha, blurX, blurY, strength, quality, inner, knockout):

						filters.push (new GlowFilter (color, alpha, blurX, blurY, strength, quality, inner, knockout));

				}

			}

			displayObject.filters = filters;

		}

		Reflect.setField (this, displayObject.name, displayObject);

	}

	public override function __update (transformOnly:Bool, updateChildren:Bool, ?maskGraphics:Graphics = null):Void {
		super.__update(transformOnly, updateChildren, maskGraphics);

		// :TODO: should be in a prerender phase
		// :TODO: use dirty flag if need to update __9SliceBitmap

		if (__symbol.scalingGridRect != null && __9SliceBitmap == null) {
				var bounds:Rectangle = new Rectangle();
				__getRenderBounds(bounds, @:privateAccess Matrix.__identity);

				if (bounds.width <= 0 && bounds.height <= 0) {
					throw 'Error creating a cached bitmap. The texture size is ${bounds.width}x${bounds.height}';
				}

				var matrix:Matrix = new Matrix();
				matrix.translate(-bounds.x, -bounds.y);
				__9SliceBitmap = new BitmapData (Math.ceil(bounds.width), Math.ceil(bounds.height), true, 0);
				__drawingBitmapData = true;
				__9SliceBitmap.draw (this, matrix);
				__drawingBitmapData = false;
		}
	}

	@:noCompletion private function drawScale9Bitmap(renderSession:RenderSession, bitmap:BitmapData, drawWidth:Float, drawHeight:Float, scale9Rect:Rectangle):Void {

		var matrix = new Matrix();
		var cols = [0, scale9Rect.left, drawWidth - (bitmap.width - scale9Rect.right), drawWidth];
		var rows = [0, scale9Rect.top, drawHeight - (bitmap.height - scale9Rect.bottom), drawHeight];
		var us = [0, scale9Rect.left / bitmap.width, scale9Rect.right / bitmap.width, 1];
		var vs = [0, scale9Rect.top / bitmap.height, scale9Rect.bottom/ bitmap.height, 1];
		var uvs:TextureUvs = new TextureUvs();

		var bitmapDataUvs = @:privateAccess bitmap.__uvData;
		var u_scale = bitmapDataUvs.x1 - bitmapDataUvs.x0;
		var v_scale = bitmapDataUvs.y2 - bitmapDataUvs.y0;

		for(row in 0...3) {
			for(col in 0...3) {

				var sourceX = cols[col];
				var sourceY = rows[row];
				var w = cols[col+1] - cols[col];
				var h = rows[row+1] - rows[row];

				matrix.identity();
				matrix.translate(sourceX + __worldTransform.tx, sourceY + __worldTransform.ty);

				uvs.x0 = uvs.x3 = us[col] * u_scale;
				uvs.x1 = uvs.x2 = us[col+1] * u_scale;
				uvs.y0 = uvs.y1 = vs[row] * v_scale;
				uvs.y2 = uvs.y3 = vs[row+1] * v_scale;

				renderSession.spriteBatch.renderBitmapDataEx(__9SliceBitmap, w, h, uvs, true, matrix, __worldColorTransform, __worldColorTransform.alphaMultiplier, __blendMode, __shader, null);

			}
		}
	}

	public override function __renderGL (renderSession:RenderSession):Void {
		if (!__drawingBitmapData && __symbol.scalingGridRect != null) {
			if (!__renderable || __worldAlpha <= 0) return;

			drawScale9Bitmap(renderSession, __9SliceBitmap, width, height ,__symbol.scalingGridRect);
		}
		else {
			super.__renderGL (renderSession);
		}
	}

	private function frame0ChildrenUpdate():Void {

		var frame = __symbol.frames[0];

		for( object_id in __objects.keys() ){
			
			var remove:Bool = true;
			
			for (frameObject in frame.objects){
				
					if( frameObject.id == object_id ){
						
							remove = false;
							break;
					}
			}

			if(remove){
				
					var displayObject = __objects.get (object_id);

					if(displayObject != null){
						
							removeChild(displayObject);

							__maskData.remove(displayObject);
							__SWFDepthData.remove(displayObject);
					}

				__objects.remove (object_id);
			}
		}
	}

	@:noCompletion private function __renderFrame (index:Int):Bool {

		if (index == 0) {
			frame0ChildrenUpdate();
		}

		var frame, displayObject, depth;
		var update_transform = true;

		frame = __symbol.frames[index];

		for (frameObject in frame.objects) {

			if (frameObject.type != FrameObjectType.DESTROY) {

				if (frameObject.id == 0 && frameObject.symbol != __zeroSymbol) {

					displayObject = __objects.get (0);

					if (displayObject != null && displayObject.parent == this) {

						removeChild (displayObject);
						__SWFDepthData.remove(displayObject);
						__maskData.remove(displayObject);

					}

					__objects.remove (0);
					displayObject = null;
					__zeroSymbol = frameObject.symbol;

				}

				if (!__objects.exists (frameObject.id)) {

					displayObject = __createObject (frameObject);

					if (displayObject != null) {

						__addChildAtSwfDepth (displayObject, frameObject.depth);
						__objects.set (frameObject.id, displayObject);

					}

				} else {

					if( frameObject.type == FrameObjectType.CREATE )
					{
						update_transform = false;
					}

					displayObject = __objects.get (frameObject.id);

					if( frameObject.type == FrameObjectType.UPDATE_CHARACTER ){

						var oldObject : DisplayObject = displayObject;

						var clipDepth = __maskData.get(displayObject);
						__maskData.remove(displayObject);
						__SWFDepthData.remove(displayObject);
						removeChild(displayObject);

						displayObject = __createObject (frameObject);

						displayObject.name = oldObject.name;
						displayObject.transform.matrix = oldObject.transform.matrix;
						displayObject.transform.colorTransform = oldObject.transform.colorTransform;
						displayObject.filters = oldObject.filters;

						if( clipDepth != null ) {
							__maskData.set( displayObject, clipDepth );
						}

						__addChildAtSwfDepth (displayObject, frameObject.depth);
						__objects.set (frameObject.id, displayObject);
					}

				}

				if (displayObject != null) {

					__placeObject (displayObject, frameObject, update_transform);

					if (frameObject.clipDepth != 0 #if neko && frameObject.clipDepth != null #end) {

						displayObject.visible = false;

						__maskData.set( displayObject, frameObject.clipDepth );
					}

				}

			} else {

				if (__objects.exists (frameObject.id)) {

					displayObject = __objects.get (frameObject.id);

					if (displayObject != null && displayObject.parent == this) {

						removeChild (displayObject);
						__SWFDepthData.remove(displayObject);
						__maskData.remove(displayObject);

					}

					__objects.remove (frameObject.id);

				}

			}

		}

		for( mask in __maskData.keys() ){
			var maskIndex = getChildIndex( mask );

			var depthValue = __maskData.get(mask);

			var result = numChildren;
			for( i in maskIndex ... numChildren ){
				var sibling = getChildAt(i);
				if( __SWFDepthData.get(sibling) > depthValue){
					result = i;
					break;
				}
			}

			mask.__clipDepth = result - maskIndex - 1;
		}

		__currentFrame = index + 1;
		__lastUpdate = index + 1;

		#if (!flash && openfl && !openfl_legacy)
		if (__frameScripts != null) {

			if (__frameScripts.exists (index)) {
				__currentLabel = __symbol.frames[index].label;
				__frameScripts.get (index) ();

				if(index  + 1 != __currentFrame){
					return true;
				}
			}

		}
		#end

		return false;

	}


	@:noCompletion private function __updateFrame ():Void {

		if (__currentFrame != __lastUpdate) {

			var scriptHasChangedFlow : Bool;

			if( __currentFrame < __lastUpdate ){
				var cacheCurrentFrame = __currentFrame;
				for( frameIndex in ( __lastUpdate ... __totalFrames ) ){
					scriptHasChangedFlow = __renderFrame (frameIndex);
					if (!__playing || scriptHasChangedFlow)
					{
						break;
					}
				}
				if (__playing){
					for( frameIndex in ( 0 ... cacheCurrentFrame ) ){
						scriptHasChangedFlow = __renderFrame (frameIndex);
						if (!__playing || scriptHasChangedFlow)
						{
							break;
						}
					}
				}
			} else {

				for( frameIndex in ( __lastUpdate ... __currentFrame ) ){
					scriptHasChangedFlow = __renderFrame (frameIndex);
					if (!__playing || scriptHasChangedFlow)
					{
						break;
					}
				}
			}

			#if (!flash && openfl && !openfl_legacy)
			__setRenderDirty();
			#end

		}

	}

	@:noCompletion private function __addChildAtSwfDepth(displayObject: DisplayObject, targetDepth:Int):Void{

		__SWFDepthData.set(displayObject, targetDepth);

		for( i in 0 ... numChildren ){
			if( __SWFDepthData.get(getChildAt(i)) > targetDepth){
				addChildAt (displayObject, i);

				return;
			}
		}

		addChild (displayObject);
	}


	@:noCompletion override private function __releaseResources(){

		super.__releaseResources();

		if(__9SliceBitmap != null ){
			__9SliceBitmap.dispose();
			__9SliceBitmap = null;
		}

	}

	@:noCompletion private function __debugPrintChildren( parentSymbolID: Int = -1 ):Void {
		
		var print :Bool = false;
		if(parentSymbolID < 0 || parentSymbolID == __symbol.id){
			print = true;
		}
		
		if(print){
		
			for( objectID in __objects.keys() ){
				
				var object = __objects.get(objectID);
				
				var maxNameLength = 20;
				var objectName = object.name;
				var isMask = __maskData.exists(object);
				
				if(objectName.length < maxNameLength){
					
					var spaceNumber = maxNameLength - objectName.length;
					
					for (i in 0...spaceNumber){
						objectName += " ";
					}
				}
				
				switch (isMask) {
					
					case true:
						trace("parent (" + __symbol.id + ")\t\t\t | " + "mask   \t " + objectName + "\t\t\t | depth = " + __SWFDepthData.get(object) + "\t | mask = " + __maskData.get(object));	
					case false:
						trace("parent (" + __symbol.id + ")\t\t\t | " + "object \t " + objectName + "\t\t\t | depth = " + __SWFDepthData.get(object) + "\t |");
				}
			}
			
			trace("-");
		}
	}

	// Get & Set Methods




	#if flash
	@:noCompletion @:getter public function get_currentFrame():Int {

		return __currentFrame;

	}


	@:noCompletion @:getter public function get___totalFrames():Int {

		return __totalFrames;

	}
	#end




	// Event Handlers




	#if flash
	@:noCompletion private function stage_onEnterFrame (event:Event):Void {

		var currentTime = Lib.getTimer ();
		var deltaTime = currentTime - __previousTime;

		__enterFrame (deltaTime);

		__previousTime = currentTime;

	}
	#end


}
