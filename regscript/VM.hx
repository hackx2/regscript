package regscript;

import haxe.ds.Vector;
import haxe.ds.StringMap;

import regscript.utils.Error;
import regscript.types.Instruction;

typedef NativeFunction = Array<Dynamic> -> Dynamic;

// based on luas register vm

//@:nullSafety(Strict) todo
class VM {
	// make a cls file for this???
    // should every instance be able to modify there own versions of these?
    
	inline static final MAX_CONSTS = 1 << 15;
	inline static final MAX_GLOBALS = 1 << 11;
	inline static final NUM_REGISTERS = 1 << 16;

	inline static final REGISTERS_START:Int = MAX_CONSTS + MAX_GLOBALS;
	inline static final TOTAL_SLOTS:Int = REGISTERS_START + NUM_REGISTERS;
	inline static final MAX_CALL_DEPTH:Int = 2048;

	// ----

	/**
	 * Holds the slot position to the actual value.
	 * If for example you're looking for a float global
	 * it's slot number will be held here, and it's actual value
	 * will be held in `this.floats[slot]`
	 */
	var globals = new StringMap<Int>();

	var kinds = new Vector<ValueKind>(TOTAL_SLOTS);
	var floats = new Vector<Float>(TOTAL_SLOTS);
	var ints = new Vector<Int>(TOTAL_SLOTS);
	var objs = new Vector<Dynamic>(TOTAL_SLOTS);

	// ----

	var nextConstantSlot = 0;
	var nextGlobalSlot = MAX_CONSTS;

	var currentClosure:Closure;

	var openUpvalues:Array<Upvalue> = [];

	var instructions:Vector<Int>;
	var constantsStart:Int = 0;
	var firstRegister:Int = 0;
	var pc:Int = 0;

	var callDepth:Int = 0;

	var savedFirstRegister:Vector<Int>;
	var savedPc:Vector<Int>;
	var savedResultSlot:Vector<Int>;
	var savedClosure:Vector<Closure>;

	public function new(?globals:Map<String, Dynamic>) {
		this.savedFirstRegister = new Vector<Int>(MAX_CALL_DEPTH);
		this.savedPc = new Vector<Int>(MAX_CALL_DEPTH);
		this.savedResultSlot = new Vector<Int>(MAX_CALL_DEPTH);
		this.savedClosure = new Vector<Closure>(MAX_CALL_DEPTH);

		// load da globals
		if(globals != null) for (n => v in globals) this._setGlobal(n, v);
	}

	/** Read a slot (duh) **/
	inline function readSlot(slot:Int):Dynamic {
		return switch kinds[slot] {
			case KIND_BOOL: ints[slot] != 0;
			case KIND_NULL: null;
			case KIND_FLOAT: floats[slot];
			case KIND_INT: ints[slot];
			case _: objs[slot];
		}
	}

	inline function writeSlot(slot:Int, val:Dynamic):Void {
		switch Type.typeof(val) {
			case TNull:
				_nullSlot(slot);
			case TInt:
				kinds[slot] = KIND_INT;
				ints[slot] = (val : Int);
			case TFloat:
				kinds[slot] = KIND_FLOAT;
				floats[slot] = (val : Float);
			case TBool:
				kinds[slot] = KIND_BOOL;
				ints[slot] = (val : Bool) ? 1 : 0;
			case _:
				kinds[slot] = KIND_OBJ;
				objs[slot] = val;
		}
	}

	inline function copySlot(to:Int, from:Int):Void {
		final kind = this.kinds[from]; this.kinds[to] = kind;
		this.ints[to] = this.ints[from];
		this.floats[to] = this.floats[from];
		this.objs[to] = this.objs[from];
	}

	inline function isTruthy(slot:Int):Bool {
		final kind:ValueKind = this.kinds[slot];
		return switch kind {
			case KIND_NULL: false;
			case KIND_BOOL: this.ints[slot] != 0;
			case _: true;
		}
	}

	/** can't find? create the slot then lol **/
	@:noCompletion inline function _findFallbackSlot(name:String):Int {
		var slot = this.globals.get(name);
		if(slot == null) {
			if(this.nextGlobalSlot >= REGISTERS_START) this.error("Too many globals");
			slot = this.nextGlobalSlot++;
			this.globals.set(name, slot);
		}
		return slot;
	}

	/** can't find? throw an error **/
	@:noCompletion inline function _findSlot(name:String):Int {
		final slot = this.globals.get(name);
		if (slot == null) {
			this.error('Unknown identifier: ${name}');
		}
		return slot;
	}

	var loadedProtos:Array<FunctionProto> = [];
	function loadConstants(fn:FunctionProto):FunctionProto {
		if (fn.constantsStart >= 0) return fn;
		if (this.nextConstantSlot + fn.constants.length > MAX_CONSTS) this.error("Too many constants");

		fn.constantsStart = this.nextConstantSlot;
		loadedProtos.push(fn);
		this.nextConstantSlot += fn.constants.length;

		for (i in 0...fn.constants.length) {
			final v:Dynamic = fn.constants[i];
			this.writeSlot(fn.constantsStart + i, v);
			if (v is FunctionProto) {
				// recurse
				this.loadConstants((cast v : FunctionProto));
			}
		}

		return fn;
	}

	inline function slotOf(operand:Int):Int {
		final fco = Instruction.FIRST_CONST_OPERAND;

		return operand >= fco
			? this.constantsStart + operand - fco
			: this.firstRegister + operand;
	}

	/** Runtime error :3 **/
	public function error(msg:String) {
		if(currentClosure == null) #if hscriptPos
			throw new Error(msg, "vm", 0,0);
		#else
			throw new Error(msg, "vm");
		#end

		final fileName = this.currentClosure?.proto.name; // current proto name
		// should we make a filename variable instead?
		
		#if hscriptPos
		// the instruction index
		final index = this.pc - 1;

		final line = (index >= 0 && index < this.currentClosure?.proto.lines.length) ? this.currentClosure?.proto.lines[index] : 0;
		final col = (index >= 0 && index < this.currentClosure?.proto.cols.length) ? this.currentClosure?.proto.cols[index] : 0;

		throw new Error(msg, fileName, line, col);
		#else
		throw new Error(msg, fileName);
		#end
	}

	/** Switches the current frame **/
	inline function switchFrame(closure:Closure, firstRegister:Int, pc:Int):Void {
		final func = closure.proto;
		this.currentClosure = closure;
		this.instructions = func.instructions;
		this.constantsStart = func.constantsStart;
		this.firstRegister = firstRegister;
		this.pc = pc;
	}

	inline function pushFrame(resSlot:Int):Void {
		final frame = this.callDepth++;
		this.savedClosure[frame] = this.currentClosure;
		this.savedFirstRegister[frame] = this.firstRegister;
		this.savedPc[frame] = this.pc;
		this.savedResultSlot[frame] = resSlot;
	}

	function popFrame(hasValue:Bool, registerSlot:Int):Void {
		final frame = --this.callDepth;
		final slot = this.savedResultSlot[frame];

		if (hasValue) {
			this.copySlot(slot, registerSlot);
		} else {
			this._nullSlot(slot);
		}
		this.switchFrame(this.savedClosure[frame], this.savedFirstRegister[frame], this.savedPc[frame]);
		this.savedClosure[frame] = null;
	}

	inline function storeUpvalue(uv:Upvalue, slot:Int):Void {
		uv.kind = kinds[slot];
		uv.int = ints[slot];
		uv.float = floats[slot];
		uv.obj = objs[slot];
	}

	inline function loadUpvalue(slot:Int, uv:Upvalue):Void {
		kinds[slot] = uv.kind;
		ints[slot] = uv.int;
		floats[slot] = uv.float;
		objs[slot] = uv.obj;
	}

	/**resolve or create an upvalue **/
	function captureUpvalue(slot:Int):Upvalue {
		var i = openUpvalues.length;
		while (i > 0 && openUpvalues[i - 1].slot > slot) i --;
		if(i > 0 && openUpvalues[i - 1].slot == slot) return openUpvalues[i -1];

		final uv = new Upvalue(slot);
		openUpvalues.insert(i, uv);
		return uv;
	}

	/**close all upvalues up until ``slot`**/
	function closeUpvalues(slot:Int) while (openUpvalues.length > 0) {
		final uv = openUpvalues[openUpvalues.length-1];
		if(uv.slot < slot) break;

		storeUpvalue(uv, uv.slot);

		uv.close();
		openUpvalues.pop();
	}

	inline function readUpvalue(slot:Int, uv:Upvalue):Void uv.state == OPEN ? copySlot(slot, uv.slot) : loadUpvalue(slot, uv);
	inline function writeUpvalue(uv:Upvalue, slot:Int):Void uv.state == OPEN ? copySlot(uv.slot, slot) : storeUpvalue(uv, slot);

	inline function _nullSlot(slot:Int):Void {
		kinds[slot] = KIND_NULL;
		ints[slot] = 0;
		floats[slot] = 0.0;
		objs[slot] = null;
	}

	inline function isEqual(slotL:Int, slotR:Int):Bool {
		final kindL = this.kinds[slotL];
		final kindR = this.kinds[slotR];

		if (kindL == kindR) {
			return switch kindL {
				case KIND_NULL: true;
				case KIND_BOOL, KIND_INT: this.ints[slotL] == this.ints[slotR];
				case KIND_FLOAT: this.floats[slotL] == this.floats[slotR];
				case KIND_OBJ: this.objs[slotL] == this.objs[slotR];
			};
		}

		return bothNumbers(slotL, slotR) && numFromSlot(slotL) == numFromSlot(slotR);
	}

	inline function isNumber(slot:Int):Bool {
		final k = this.kinds[slot];
		return k == KIND_INT || k == KIND_FLOAT;
	}

	inline function bothNumbers(l:Int, r:Int):Bool
		return isNumber(l) && isNumber(r);

	inline function bothInts(l:Int, r:Int):Bool
		return this.kinds[l] == KIND_INT && this.kinds[r] == KIND_INT;

	/** gets a number from the given num slot, returning it as a float **/
	inline function numFromSlot(slot:Int):Float
		return this.kinds[slot] == KIND_INT ? this.ints[slot] : this.floats[slot];

	inline function setInt(slot:Int, v:Int):Void {
		this.kinds[slot] = KIND_INT;
		this.ints[slot] = v;
	}

	inline function setFloat(slot:Int, v:Float):Void {
		this.kinds[slot] = KIND_FLOAT;
		this.floats[slot] = v;
	}

	inline function setBool(slot:Int, v:Bool):Void {
		this.kinds[slot] = KIND_BOOL;
		this.ints[slot] = v ? 1 : 0;
	}

	/** Resolves slot of arg b**/
	inline function slotOfB(instruction:Int):Int return slotOf(Instruction.argumentB(instruction));
	/** Resolves slot of arg c **/
	inline function slotOfC(instruction:Int):Int return slotOf(Instruction.argumentC(instruction));

	/** for `div` and `mod`. if given arg is 0, throw :3**/
	inline function nonZero<T>(v:T):T { // generics :D
		if ((cast v : Float) == 0) this.error("division by zero");
		return v;
	}
	
	function binaryFallback(op:Op, slotA:Int, slotL:Int, slotR:Int):Void {
		final l = this.readSlot(slotL), r = this.readSlot(slotR);

		switch op {
			case ADD:
				this.writeSlot(slotA, Std.string(l) + Std.string(r));
				return;
			case _:
		}

		this.error('Cannot perform arithmetic on $l and $r');
	}

	function undoCallClosure(depth:Int, first:Int, oldClosure:Closure, oldFirst:Int, oldPc:Int):Void {
		this.closeUpvalues(first);
		while (this.callDepth > depth)
			this.savedClosure[--this.callDepth] = null;

		if (oldClosure != null) {
			this.switchFrame(oldClosure, oldFirst, oldPc);
		} else {
			this.currentClosure = null;
		}
	}

    inline function checkClosureCall(proto:FunctionProto, arity:Int, firstReg:Int):Void {
        // actually enforcing arity when calling a closure
        // oh wait, we should impl rest. y'know, the (...args) stuffs
		if (arity != proto.arity) {
			this.error('${proto.name} expects ${proto.arity} arg(s), got $arity');
		}

		if (this.callDepth >= MAX_CALL_DEPTH || firstReg + proto.registersNeeded > TOTAL_SLOTS) {
			this.error("stack overflow");
		}
    }

	var nativeTop = 0;
	function callClosure(closure:Closure, args:Array<Dynamic>):Dynamic {
		final proto = closure.proto;
		this.loadConstants(proto);

		final base = this.currentClosure?.proto != null ? this.nativeTop : REGISTERS_START;
		final first = base + 1;

        this.checkClosureCall(proto, args.length, first);

        // func = reg x
        // reg x (x + 1 ... x+b)
        // b is basically the max argument thing
		for (i in 0...args.length) this.writeSlot(first + i, args[i]);

		final depth = this.callDepth;

		final oldClosure = this.currentClosure;
		final oldFirst = this.firstRegister;
		final oldPc = this.pc;
		final oldTop = this.nativeTop;

		var res:Dynamic = null;

        try {
			this.switchFrame(closure, first, 0);
			res = this.run(depth);
		} catch (e:Dynamic) {
			this.nativeTop = oldTop;
			this.undoCallClosure(depth, first, oldClosure, oldFirst, oldPc);
			Error.rethrow(e);
		}
		
        this.nativeTop = oldTop;
		this.undoCallClosure(depth, first, oldClosure, oldFirst, oldPc);

		return res;
	}

	function callValue(fn:Dynamic, args:Array<Dynamic>):Dynamic { // allow rest args?
		if(fn is Closure) return this.callClosure(cast fn, args);
		if(fn is FunctionProto) return this.callClosure(new Closure(cast fn, []), args);
		if(Reflect.isFunction(fn)) return Reflect.callMethod(null, fn, args);

		this.error("cant call "+fn);

		return null;
	}

	// scary macro funcs below :3
	// not 100% on how macro functions work, but i think we can still use this class inside of a macro... 
	// not too sure on why you'd even want to do such a thing... lol

	// 25.11.2026 - okay what if i combine all these arith macro funcs
	// into one single function with a few boolean toggles?
	// exactly how it was before but, y'know, more organized.
	macro static function arith(expr) return macro {
		final slotL = slotOfB(instruction);
		final slotR = slotOfC(instruction);

		if (bothInts(slotL, slotR)) {
			final l = ints[slotL];
			final r = ints[slotR];
			setInt(slotA, $expr);
		} else if (bothNumbers(slotL, slotR)) {
			final l = numFromSlot(slotL);
			final r = numFromSlot(slotR);
			setFloat(slotA, $expr);
		} else {
			binaryFallback(op, slotA, slotL, slotR);
		}
	}

	macro static function floatArith(expr) return macro {
		final slotL = slotOfB(instruction);
		final slotR = slotOfC(instruction);

		if (bothNumbers(slotL, slotR)) {
			final l = numFromSlot(slotL);
			final r = numFromSlot(slotR);
			setFloat(slotA, $expr);
		} else {
			binaryFallback(op, slotA, slotL, slotR);
		}
	}

	macro static function intArith(expr) return macro {
		final slotL = slotOfB(instruction);
		final slotR = slotOfC(instruction);

		if (bothInts(slotL, slotR)) {
			final l = ints[slotL];
			final r = ints[slotR];
			setInt(slotA, $expr);
		} else {
			binaryFallback(op, slotA, slotL, slotR);
		}
	}

	macro static function relationalOp(expr) return macro {
		final slotL = slotOfB(instruction);
		final slotR = slotOfC(instruction);

		if (bothNumbers(slotL, slotR)) {
			final l = numFromSlot(slotL);
			final r = numFromSlot(slotR);
			setBool(slotA, $expr);
		} else {
			binaryFallback(op, slotA, slotL, slotR);
		}
	}

	///

	inline function protectRegisters(topAlternative:Int = 0):Void {
		final reg = this.firstRegister + this.currentClosure.proto.registersNeeded;
		this.nativeTop = reg > topAlternative ? reg : topAlternative;
	}

	function getField(obj:Dynamic, field:String):Dynamic {
		if(obj == null) this.error('Invalid access to field $field');
		// :bypassAccessor stuff would go here :3
		return Reflect.getProperty(obj, field);
	}

	function setField(obj:Dynamic, field:String, value:Dynamic):Void {
		if(obj==null) this.error('Invalid access to field $field');
		Reflect.setProperty(obj, field, value);
	}

	function callField(obj:Dynamic, field:String, args:Array<Dynamic>):Dynamic {
		if(obj==null) this.error('Invalid access to field $field');

		final prop = Reflect.getProperty(obj, field);
		final func:Dynamic = this._toHaxe(prop);

		if(!Reflect.isFunction(func)) this.error('$field is not a function');

		return Reflect.callMethod(obj, func, args);
	}

	function run(depth:Int):Dynamic {
		while (true) {
			final instruction = this.instructions[pc++];
			final op:Op = Instruction.opcodeOf(instruction);
			final slotA = this.firstRegister + Instruction.argumentA(instruction);

			switch op {
				case MOVE: // copy one slot to another
					final argB = Instruction.argumentB(instruction);
					this.copySlot(slotA, this.firstRegister + argB);

				case LOAD_CONST:
					final argBig = Instruction.argumentBig(instruction);
					this.copySlot(slotA, this.constantsStart + argBig);

				case LOAD_BOOL: setBool(slotA, Instruction.argumentB(instruction) != 0);
				case LOAD_NULL: _nullSlot(slotA);

				case NEW_OBJECT: this.writeSlot(slotA, {});
				case NEW_CLOSURE:
					final argBig = Instruction.argumentBig(instruction);
					final proto:FunctionProto = objs[constantsStart+argBig];
					final upvals:Array<Upvalue> = [];

					for(desc in proto.upvalueDecs) {
						final slot = firstRegister+desc.parentSlot;
						upvals.push(desc.fromParent ? captureUpvalue(slot) : currentClosure.upvalues[desc.parentSlot]);
					}
					this.writeSlot(slotA, new Closure(proto, upvals));
					
				case JUMP: this.pc += Instruction.argumentJump(instruction);
				case JUMP_IF_FALSE: if (!isTruthy(slotA)) this.pc += Instruction.argumentJump(instruction);
				case JUMP_IF_TRUE: if(isTruthy(slotA)) this.pc += Instruction.argumentJump(instruction);

				case GET_FIELD:
					final slotB = slotOfB(instruction);
					final fieldName = objs[slotOfC(instruction)];

					this.protectRegisters();
					this.writeSlot(slotA, this.getField(this.readSlot(slotB), fieldName));
				case SET_FIELD:
					final fieldName = objs[slotOfB(instruction)];
					final slotC = slotOfC(instruction);
					
					this.protectRegisters();
					this.setField(this.readSlot(slotA), fieldName, this._toHaxe(this.readSlot(slotC)));
				case CALL_FIELD:
					final fieldName = objs[slotOfB(instruction)];
					final argC = Instruction.argumentC(instruction);

					this.protectRegisters(slotA + argC + 1);

					final obj = this.readSlot(slotA);
					final args:Array<Dynamic> = [for(i in 1...argC+1) this._toHaxe(this.readSlot(slotA + i))];
					this.writeSlot(slotA, this.callField(obj, fieldName, args));

				case GET_UPVALUE: readUpvalue(slotA, currentClosure.upvalues[Instruction.argumentB(instruction)]);
				case SET_UPVALUE: writeUpvalue(currentClosure.upvalues[Instruction.argumentB(instruction)], slotA);
				case CLOSE_UPVALUES: closeUpvalues(slotA);

				// global stuff
				case GET_GLOBAL: this.copySlot(slotA, this._findSlot(objs[constantsStart+Instruction.argumentBig(instruction)]));
				case SET_GLOBAL: this.copySlot(this._findFallbackSlot(objs[constantsStart+Instruction.argumentBig(instruction)]), slotA);

				// arithmetic operations (USING MACROS :DDDDDDD)
				case ADD: arith(l + r);
				case SUB: arith(l - r);
				case MUL: arith(l * r);
				case MOD: arith(l % nonZero(r));
				case DIV: floatArith(l / nonZero(r));
				case NEG: // -val
					final slotB = slotOfB(instruction);
					switch kinds[slotB] {
						case KIND_INT: setInt(slotA, -ints[slotB]);
						case KIND_FLOAT: setFloat(slotA, -floats[slotB]);
						case _: this.error('Cannot negate ${readSlot(slotB)}');
					}
				
				// bitwise ops
				case BAND: intArith(l & r);
				case BOR: intArith(l | r);
				case BXOR: intArith(l ^ r);
				case SHL: intArith(l << r);
				case SHR: intArith(l >> r);
				case USHR: intArith(l >>> r);
				case BNOT:
					final slotB = slotOfB(instruction);
					if (kinds[slotB] == KIND_INT) setInt(slotA, ~ints[slotB]);
					else this.error('Cannot bitwise not ${readSlot(slotB)}');

				// comparison ops
				case EQ:  setBool(slotA, isEqual(slotOfB(instruction), slotOfC(instruction)));
				case NEQ: setBool(slotA, !isEqual(slotOfB(instruction), slotOfC(instruction)));
				case NOT: setBool(slotA, !isTruthy(slotOfB(instruction)));
				case LT:  relationalOp(l < r);
				case LTE: relationalOp(l <= r);
				case GT:  relationalOp(l > r);
				case GTE: relationalOp(l >= r);

				case CALL:
					final argB = Instruction.argumentB(instruction);
					final callee:Dynamic = (this.kinds[slotA] == KIND_OBJ) ? this.objs[slotA] : null;

					var closure:Closure = null;
					if(callee is Closure) {
						closure = cast callee;
					} else if(callee is FunctionProto) {
						closure = new Closure(cast callee, []);
					}

					if (closure != null) {
						final proto:FunctionProto = closure.proto;
						this.loadConstants(proto);
                        final firstArgPos = slotA+1;
                        this.checkClosureCall(proto, argB, firstArgPos);
						this.pushFrame(slotA);
						this.switchFrame(closure, firstArgPos, 0);
					} else if (Reflect.isFunction(callee)) {
						final regTop = this.firstRegister + this.currentClosure?.proto.registersNeeded;
						final argTop = slotA + argB + 1;
						this.nativeTop = regTop > argTop ? regTop : argTop;

						final native:NativeFunction = callee;
						final args:Array<Dynamic> = [for (i in 1...argB + 1) this._toHaxe(this.readSlot(slotA + i))];
						this.writeSlot(slotA, native(args));
					} else {
						this.error('Cannot call ${this.readSlot(slotA)}');
					}
				
				case RETURN:
					final hasVal = Instruction.argumentB(instruction) != 0;
					this.closeUpvalues(this.firstRegister);
					if(this.callDepth == depth) return hasVal ? this.readSlot(slotA) : null;
					this.popFrame(hasVal, slotA);

				case _: this.error('unknown opcode ~ $op');
			}
		}
	}

	/** converts the given `v` into something YOU (not a vm) can use :3 **/
	inline function _toHaxe(v:Dynamic):Dynamic {
		if(v is FunctionProto) v = new Closure(cast v, []);
		if(v is Closure) {
			final c:Closure = cast v; // todo: make a proxy class
			return c.__cacheHostFunc ??= Reflect.makeVarArgs((args:Array<Dynamic>) -> {
				return this._toHaxe(this.callClosure(c,args));
			});
		}
		return v;
	}

	inline function _setGlobal(name:String, val:Dynamic):Void {
		this.writeSlot(this._findFallbackSlot(name), val);
		if (val is FunctionProto) this.loadConstants((cast val : FunctionProto));
	}

	inline function _getGlobal(name:String):Dynamic {
		return this.readSlot(this._findSlot(name));
	}

	// actual public api thing

	public function execute(main:FunctionProto):Dynamic { // copying hscript cuz (DUH)
		final main = new Closure(main, []);
		return this._toHaxe(this.callClosure(main, []));
	}

	/** call `name` with `?args` **/
	public function call(name:String, ?args:Array<Dynamic>):Dynamic {
		return this._toHaxe(this.callValue(this._getGlobal(name), args ?? []));
	}

	/** set `name` to `val` **/
	public function set(name:String, val:Dynamic):Void {
		this._setGlobal(name, val);
	}

	/** get `name` **/
	public function get(name:String):Dynamic { // `getGlobal` throws, while this doesn't...
		final slot = this.globals.get(name);
		return slot == null ? null : this._toHaxe(this.readSlot(slot));
	}

	/** returns with `name` exists within the globals table**/
	public function exists(name:String):Bool {
		return this.globals.exists(name);
	}

	/** Reset the vm (duh) **/
	public function reset() { // todo: test me
		for (i in 0...nextConstantSlot) _nullSlot(i);
		nextConstantSlot = 0;
		
		for (i in MAX_CONSTS...nextGlobalSlot) _nullSlot(i);
		globals.clear();
		nextGlobalSlot = MAX_CONSTS;

		openUpvalues = [];
		currentClosure = null;
		for(p in loadedProtos) p.constantsStart = -1;
		loadedProtos = [];
		nativeTop = 0;
		currentClosure = null;

		callDepth = 0;
		pc = 0;
	}
}