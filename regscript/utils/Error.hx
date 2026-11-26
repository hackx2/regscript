package regscript.utils;

import haxe.Exception;

@:nullSafety(Strict)
final class Error {
	public final msg:String;
	public final fileName:Null<String>;

	#if hscriptPos
	public final line:Int;
	public final col:Int;
	#end

	public function new(msg:String, fileName:String #if hscriptPos, line:Int, col:Int #end) {
		this.msg = msg;
		this.fileName = fileName;

		#if hscriptPos
		this.line = line;
		this.col = col;
		#end
	}

	public function toString():String {
		final file = fileName ?? '<unknown>';
		// pos -> script.hx:5:20: ...
		// no pos -> script.hx: ...
		return '$file${#if hscriptPos ":" + line + ":" + col + #end ": " + msg}';
	}

	public inline static function rethrow(e:Dynamic):Void { // fine here?
		#if hl
		hl.Api.rethrow(e);
		#else
		throw e;
		#end
	}
}
