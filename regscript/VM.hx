package regscript;

import haxe.ds.Vector;
import haxe.ds.StringMap;
import haxe.macro.Expr.ExprOf;

// Reg = Register (duh)
// RC = Register or Constant
enum abstract Op(Int) from Int to Int {
	var MOVE = 0x00;    // Reg(A) = Reg(B)
	var CALL;			// Reg(A) = Reg(A)(Reg(A+1)...Reg(A+B))
	var RETURN;			// return B != 0 ? Reg(A) : null

	var LOAD_CONST;     // Reg(A) = Const(Big)
	var LOAD_BOOL;		// Reg(A) = 1 (true) or 0 (false)
	var LOAD_NULL;		// Reg(A) = null

	var GET_GLOBAL;		// Reg(A) = Globals[Const(Big)]
	var SET_GLOBAL;		// Globals[Const(Big)] = Reg(A)

	var JUMP;			// pc += (Reg(B) + Jump Offset)
	var JUMP_IF_FALSE;	// if(!Reg(A)) pc += (Reg(B) + Jump Offset)
	var JUMP_IF_TRUE;	// if(Reg(A)) pc += (Reg(B) + Jump Offset)

	var ADD;        	// Reg(A) = RC(B) + RC(C)
	var SUB;			// Reg(A) = RC(B) - RC(C) 
	var MUL;			// Reg(A) = RC(B) * RC(C)
	var MOD;			// Reg(A) = RC(B) % RC(C)
	var DIV;			// Reg(A) = RC(B) / RC(C)
	var NEG;   			// Reg(A) = -RC(B)

	var BAND;			// Reg(A) = RC(B) & RC(C)
	var BOR;			// Reg(A) = RC(B) | RC(C)
	var BXOR;			// Reg(A) = RC(B) ^ RC(C)
	var SHL;			// Reg(A) = RC(B) << RC(C)
	var SHR;			// Reg(A) = RC(B) >> RC(C)
	var USHR;			// Reg(A) = RC(B) >>> RC(C)
	var BNOT;			// Reg(A) = ~RC(B)

	var NOT;			// Reg(A) = !RC(B)
	var EQ;				// Reg(A) = RC(B) == RC(C)
	var NEQ;			// Reg(A) = RC(B) != RC(C)
	var LT;				// Reg(A) = RC(B) < RC(C)
	var LTE;			// Reg(A) = RC(B) <= RC(C)
	var GT;				// Reg(A) = RC(B) > RC(C)
	var GTE;			// Reg(A) = RC(B) >= RC(C)
}

enum abstract ConditionalJumpOp(Int) to Op to Int { // i like strictly typing things :3
	var JUMP_IF_FALSE = Op.JUMP_IF_FALSE;
	var JUMP_IF_TRUE = Op.JUMP_IF_TRUE;
}

@:publicFields
final class Instruction {
	// -- encoding :3
	
	// let's us support both positive and negative numbers (when jumping)
	// JUMP_OFFSET is the new 0 (automatically deducted by the VM at runtime).
	// compiler is gonna basically auto add the offset; for example,
	// we're given the number 5 by the ast, compiler adds `JUMP_OFFSET` to that
	// amount, so it can be packed into a jump instruction
	inline static var JUMP_OFFSET = (1<<17)-1;

	/**
	 * both `b` and `c` are unsigned 9-bit values (0...511)
	 * 
	 * @param op    Op code (6 bits; 0..63)
	 * @param a     usually a register index (8 bits; 0..255)
	 * @param b     0..255 = register slot | 256..511 = constant
	 * @param c     0..255 = register slot | 256..511 = constant
	 */
	@:pure inline static function makeInstruction(op:Op, a:Int = 0, b:Int = 0, c:Int = 0):Int {
		return ((
			(op & 0x3F /* 63 */)
			| ((a & 0xFF /* 255 */) << 6)
			| ((b & 0x1FF /* 511 */) << 14)
			| ((c & 0x1FF /* 511 */) << 23)
		) | 0);
	}
	

	/**
	 * used for anything that needs to exceed `makeInstruction`'s 256 cap
	 * 
	 * @param op    Op code (6 bits; 0..63)
	 * @param a     usually a register index (8 bits; 0..255)
	 * @param big   unsigned int (18 bits; 0..262143)
	 * 
	 * @return 32-bit instruction int [straight faced emoji] lol
	 */
	@:pure inline static function makeInstructionBig(op:Op, a:Int, big:Int):Int {
		return ((
			(op & 0x3F /* 63 */)
			| ((a & 0xFF /* 255 */) << 6)
			| ((big & 0x3FFFF /* 262143 */) << 14)
		) | 0);
	}

	/**
	 * uh jumping an instruction..? (im so buns at explaining, sorry)
	 * 
	 * @param distance  jump distance
	 * @return          32-bit instruction int [straight faced emoji] lol
	 */
	inline static function makeJump(distance:Int):Int {
		// jump distance, as previously stated, basically just ensures
		// we're able to negatively jump backwards, while still allowing us
		// to pack the distance into the instruction int.
		return makeInstructionBig(Op.JUMP, 0, distance + JUMP_OFFSET);
	}

	/**
	 * uh jumping an instruction based on whether the conditional has been met or not..? (im so buns at explaining, sorry)
	 * 
	 * @param op        the conditional jump operation (jump if false / true)
	 * @param register  the register that contains the condition value
	 * @param distance  jump distance
	 * @return          32-bit instruction int [straight faced emoji] lol
	 */
	inline static function makeConditionalJump(op:ConditionalJumpOp, register:Int, distance:Int):Int {
		return makeInstructionBig(op, register, distance + JUMP_OFFSET);
	}
	
	// for constant or register operations (e.g. ADD)
	// 0..255 is a register slot
	// 256..511(largest num that can fit within 9 bits)
	inline static var FIRST_CONST_OPERAND = 256;

	/**
	 * Get a constant from constants array (duh)
	 * 
	 * @param index right
	 */
	@:pure inline static function constant(index:Int):Int {
		return FIRST_CONST_OPERAND + index;
	}

	// -- decoding :3

	@:pure inline static function opcodeOf(instruction:Int):Op {
		return (instruction & 0x3F);
	}

	@:pure inline static function argumentA(instruction:Int):Int {
		return (instruction >>> 6) & 0xFF;
	}

	@:pure inline static function argumentB(instruction:Int):Int {
		return (instruction >>> 14) & 0x1FF;
	}

	@:pure inline static function argumentC(instruction:Int):Int {
		return (instruction >>> 23) & 0x1FF;
	}

	@:pure inline static function argumentBig(instruction:Int):Int {
		return (instruction >>> 14) & 0x3FFFF;
	}

	inline static function argumentJump(instruction:Int) {
		return argumentBig(instruction) - JUMP_OFFSET;
	}
}

enum abstract ValueKind(Int) from Int to Int {
	var KIND_NULL = 0x00;
	var KIND_BOOL;
	var KIND_INT;
	var KIND_FLOAT;
	var KIND_OBJ; // anything that isn't a float, bool or int
}

typedef NativeFunction = Array<Dynamic> -> Dynamic;

@:publicFields
final class FunctionProto {
	var instructions:Vector<Int>;
	var constants:Array<Dynamic>;
	var registersNeeded:Int;

	/** How many arguments this proto declares **/
	var arity:Int; // think smart

	var name:String;
	var constantsStart:Int = -1;

	#if hscriptPos
	var cols:Array<Int>;
	var lines:Array<Int>;
	#end

	function new(
		instructions:Vector<Int>, constants:Array<Dynamic>,
		arity:Int, registersNeeded:Int, name:String = "<fn>",
		lines:Array<Int>, cols:Array<Int>
	) {
		this.instructions = instructions;
		this.constants = constants;
		this.registersNeeded = registersNeeded;
		this.name = name;
		this.arity = arity;

		#if hscriptPos
		this.lines = lines ?? [];
		this.cols = cols ?? [];
		#end
	}
}

// based on luas register vm

//@:nullSafety(Strict) todo
class VM {
	// make a cls file for this???
	inline static final MAX_CONSTS = 1 << 12;
	inline static final MAX_GLOBALS = 1 << 9;
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

	var current:FunctionProto;
	var instructions:Vector<Int>;
	var constantsStart:Int = 0;
	var firstRegister:Int = 0;
	var pc:Int = 0;

	var callDepth:Int = 0;

	var savedFunction:Vector<FunctionProto>;
	var savedFirstRegister:Vector<Int>;
	var savedPc:Vector<Int>;
	var savedResultSlot:Vector<Int>;

	public function new(?globals:Map<String, Dynamic>) {
		this.savedFunction = new Vector<FunctionProto>(MAX_CALL_DEPTH);
		this.savedFirstRegister = new Vector<Int>(MAX_CALL_DEPTH);
		this.savedPc = new Vector<Int>(MAX_CALL_DEPTH);
		this.savedResultSlot = new Vector<Int>(MAX_CALL_DEPTH);

		if(globals != null) for (n => v in globals) {
			this.setGlobal(n, v);
		}
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
				__nullifySlot(slot);
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

	public function setGlobal(name:String, val:Dynamic):Void {
		this.writeSlot(this.__findOrCreateGlobal(name), val);
		if (val is FunctionProto) this.loadConstants((cast val : FunctionProto));
	}

	public function getGlobal(name:String):Dynamic {
		return this.readSlot(this.__findGlobalSlot(name));
	}

	@:noCompletion function __findOrCreateGlobal(name:String):Int {
		var slot = this.globals.get(name);
		if(slot == null) {
			if(this.nextGlobalSlot >= REGISTERS_START) this.error("Too many globals");
			slot = this.nextGlobalSlot++;
			this.globals.set(name, slot);
		}
		return slot;
	}

	@:noCompletion function __findGlobalSlot(name:String):Int {
		final slot = this.globals.get(name);
		if (slot == null) {
			this.error('Unknown identifier: ${name}');
		}
		return slot;
	}

	function loadConstants(fn:FunctionProto):FunctionProto {
		if (fn.constantsStart >= 0) return fn;
		if (this.nextConstantSlot + fn.constants.length > MAX_CONSTS) {
			this.error("Too many constants");
		}
		fn.constantsStart = this.nextConstantSlot;
		this.nextConstantSlot += fn.constants.length;
		for (idx in 0...fn.constants.length) {
			final v:Dynamic = fn.constants[idx];
			this.writeSlot(fn.constantsStart + idx, v);
			if (v is FunctionProto) this.loadConstants((cast v : FunctionProto));
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
		final fileName = this.current.name;
		
		#if hscriptPos
		// the instruction index
		final index = this.pc - 1;

		final line = (index >= 0 && index < this.current.lines.length) ? this.current.lines[index] : 0;
		final col = (index >= 0 && index < this.current.cols.length) ? this.current.cols[index] : 0;

		throw new Error(msg, fileName, line, col);
		#else
		throw new Error(msg, fileName);
		#end
	}

	/** Switches the current frame **/
	function switchFrame(func:FunctionProto, firstRegister:Int, pc:Int):Void {
		this.current = func;
		this.instructions = func.instructions;
		this.constantsStart = func.constantsStart;
		this.firstRegister = firstRegister;
		this.pc = pc;
	}

	inline function pushFrame(resSlot:Int):Void {
		final frame = this.callDepth++;

		this.savedFunction[frame] = this.current;
		this.savedFirstRegister[frame] = this.firstRegister;
		this.savedPc[frame] = this.pc;
		this.savedResultSlot[frame] = resSlot;
	}

	function popFrame(hasValue:Bool, registerSlot:Int):Void {
		final frame = --this.callDepth;
		final dest = this.savedResultSlot[frame];

		if (hasValue) {
			this.copySlot(dest, registerSlot);
		} else {
			this.kinds[dest] = KIND_NULL; // heh
			this.objs[dest] = null;
		}
		this.switchFrame(this.savedFunction[frame], this.savedFirstRegister[frame], this.savedPc[frame]);
	}

	@:noCompletion
	inline function __nullifySlot(slot:Int):Void {
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

	// scary macro funcs below :3
	// not 100% on how macro functions work, but i think we can still use this class inside of a macro... 
	// not too sure on why you'd even want to do such a thing... lol

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

	public function run(main:FunctionProto):Dynamic {
		this.loadConstants(main);
		this.callDepth = 0;
		this.switchFrame(main, REGISTERS_START +1, 0);

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
				case LOAD_NULL: __nullifySlot(slotA);

				case JUMP: this.pc += Instruction.argumentJump(instruction);
				case JUMP_IF_FALSE: if (!isTruthy(slotA)) this.pc += Instruction.argumentJump(instruction);
				case JUMP_IF_TRUE: if(isTruthy(slotA)) this.pc += Instruction.argumentJump(instruction);

				// global stuff
				case GET_GLOBAL:
					final big = Instruction.argumentBig(instruction);
					final name = objs[constantsStart+big];
					this.copySlot(slotA, this.__findGlobalSlot(name));

				case SET_GLOBAL:
					final big = Instruction.argumentBig(instruction);
					final name = objs[constantsStart+big];
					this.copySlot(this.__findOrCreateGlobal(name), slotA);

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

					if (callee is FunctionProto) {
						final proto:FunctionProto = cast callee;
						if (argB != proto.arity) {
							this.error('${proto.name} expects ${proto.arity} arg(s), got $argB');
						}

						final calleeFirstArg = (slotA + 1);
						if (this.callDepth >= MAX_CALL_DEPTH || calleeFirstArg + proto.registersNeeded > TOTAL_SLOTS) {
							this.error("stack overflow");
						}

						this.pushFrame(slotA);
						this.switchFrame(proto, calleeFirstArg, 0);
					} else if (Reflect.isFunction(callee)) {
						final native:NativeFunction = callee;
						final args:Array<Dynamic> = [for (i in 1...argB + 1) this.readSlot(slotA + i)];
						this.writeSlot(slotA, native(args));
					} else {
						this.error('Cannot call ${this.readSlot(slotA)}');
					}
				
				case RETURN:
					final hasVal = Instruction.argumentB(instruction) != 0;
					if(this.callDepth == 0) return hasVal ? this.readSlot(slotA) : null;
					this.popFrame(hasVal, slotA);

				case _: this.error('unknown opcode ~ $op');
			}
		}
	}

	/** Reset the vm (duh) **/
	public function reset() { // todo: test me
		for (i in 0...nextConstantSlot) __nullifySlot(i);
		nextConstantSlot = 0;
		
		for (i in MAX_CONSTS...nextGlobalSlot) __nullifySlot(i);
		globals.clear();
		nextGlobalSlot = MAX_CONSTS;

		callDepth = 0;
		pc = 0;
	}
}