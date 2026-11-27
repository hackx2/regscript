package regscript.types;

import haxe.ds.Vector;

// Reg = Register (duh)
// RC = Register or Constant
enum abstract Op(Int) from Int to Int {
	var MOVE = 0x00;    // Reg(A) = Reg(B)
	var CALL;			// Reg(A) = Reg(A)(Reg(A+1)...Reg(A+B))
	var RETURN;			// return B != 0 ? Reg(A) : null

	var LOAD_CONST;     // Reg(A) = Const(Big)
	var LOAD_BOOL;		// Reg(A) = 1 (true) or 0 (false)
	var LOAD_NULL;		// Reg(A) = null
	
	var NEW_OBJECT;		// Reg(A) = {}

	var NEW_CLOSURE; 	// Reg(A) = new Closure(Const(Big) as FunctionProto)
	var CLOSE_UPVALUES;	// close ever upvalue on Reg(A) or above 

	var GET_UPVALUE;	// Reg(A) = Upvalue(B)
	var SET_UPVALUE;	// Upvalue(B) = Reg(A)
	var GET_GLOBAL;		// Reg(A) = Globals[Const(Big)]
	var SET_GLOBAL;		// Globals[Const(Big)] = Reg(A)
	var GET_FIELD; 		// Reg(A) = Reg(B).Const(C)
	var SET_FIELD;		// Reg(A).Const(B) = Reg(B)

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

abstract UpvalueDesc(Int) {
	public inline function new(fromParent:Bool, parentSlot:Int) {
		this = (parentSlot <<1) | (fromParent ? 1 : 0);
	}

	/** 
	 * if true, capture a local register 
	 * if false, reuse an enclosing funcs upvals
	 */
	public var fromParent(get,never):Bool;
	inline function get_fromParent() {
		return (this & 1) != 0;
	}

	/** The parent slot the upvalue is tracking **/
	public var parentSlot(get,never):Int;
	inline function get_parentSlot() {
		return this >>> 1;
	}
}

enum abstract UpvalueState(Int) from Int to Int {
	var OPEN = 0x00;
	var CLOSED;
}

@:publicFields
final class Upvalue {
	/** slot pos **/
	var slot:Int;
	/** upvalue state **/
	var state:UpvalueState = OPEN;

	var kind:ValueKind = KIND_NULL;
	var int:Int = 0;
	var float:Float = 0.0;
	var obj:Dynamic = null;

	inline function new(slot:Int) {
		this.slot = slot;
	}

	/** close the upvalue **/
	inline function close() {
		state = CLOSED;
		slot = -1;
	}
}

@:publicFields
final class Closure {
	var proto:FunctionProto;
	var upvalues:Array<Upvalue>; // turn into a vector?
	var __cacheHostFunc:Dynamic = null;

	function new(proto:FunctionProto, upvalues:Array<Upvalue>) {
		this.proto = proto;
		this.upvalues = upvalues;
	}
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

	var upvalueDecs:Array<UpvalueDesc>;

	function new(
		instructions:Vector<Int>, constants:Array<Dynamic>,
		arity:Int, registersNeeded:Int, name:String = "<fn>",
		lines:Array<Int>, cols:Array<Int>,
		?uDescs:Array<UpvalueDesc>
	) {
		this.instructions = instructions;
		this.constants = constants;
		this.registersNeeded = registersNeeded;
		this.name = name;
		this.arity = arity;
		this.upvalueDecs = uDescs ?? [];

		#if hscriptPos
		this.lines = lines ?? [];
		this.cols = cols ?? [];
		#end
	}
}