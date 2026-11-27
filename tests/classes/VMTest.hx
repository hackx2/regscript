package tests.classes;

import regscript.types.Instruction;
import haxe.ds.StringMap;
import haxe.ds.Vector;
import haxe.PosInfos;
import utest.Assert;
import utest.Test;
import regscript.VM;

enum abstract ThrowAssertType(String) to String from String {
	var DivideZero = "division by zero";
}
// check the todo 
final class VMTest extends Test {
	@:ignore function proto(
		instructions:Array<Op>, constants:Array<Dynamic>, 
		arity:Int, regs:Int, name:String, ?upvals:Array<UpvalueDesc>
	) {
		return new FunctionProto(Vector.fromArrayCopy(instructions), constants, arity, regs, name, [], [], upvals);
	}

	@:ignore function runInstructions(instructions:Array<Op>, constants:Array<Dynamic>, ?globals:StringMap<Dynamic>):Dynamic {
		instructions = instructions.concat([Instruction.makeInstruction(RETURN, 0, 1)]);
		final fn = proto(instructions, constants ?? [], 0, 1, "hiii [waves]", []);
		return new VM(globals).execute(fn);
	}

	/**
	 * By default, this function will return register `0`, so,
	 * make sure whatever result you want to compare is on register `0`. 
	 */
	@:ignore function assertInstructions(expected:Dynamic, instructions:Array<Op>, ?constants:Array<Dynamic>, ?globals:StringMap<Dynamic>, ?pos:PosInfos):Void {
		final result:Dynamic = runInstructions(instructions, constants, globals);

		// to check if our add op is correctly returning an int (if int + int), or a float (if float + float or float + int)
		switch Type.typeof(expected) {
			case TFloat:
				Assert.floatEquals(expected, result, null, null, pos);
			case _:
				Assert.equals(expected, result, null, pos);
		}
	}

	@:ignore function assertError(expectedMsgPart:String, instructions:Array<Op>, constants:Array<Dynamic>, ?globals:StringMap<Dynamic>, ?pos:PosInfos):Void {
		var caught:Dynamic = null;
		try {
			runInstructions(instructions, constants, globals);
		} catch (e:Dynamic) {
			caught = e;
		}

		Assert.notNull(caught, "expected an error ", pos);

		final contains:Bool = Std.string(caught).indexOf(expectedMsgPart) != -1;
		Assert.isTrue(contains, 'expected given error to contain "$expectedMsgPart", got "$caught"', pos);
	}

	/////////////////////

	function testAdd() {
		// int
		assertInstructions(1221821 + 21902912, [
			// don't mind these interesting numbers
			Instruction.makeInstruction(ADD, 0, Instruction.constant(0), Instruction.constant(1))
		], [1221821, 21902912]);

		// float
		assertInstructions(4.29, [
			Instruction.makeInstruction(ADD, 0, Instruction.constant(0), Instruction.constant(1))
		], [2.2, 2.09]);

		// int + float
		assertInstructions(1.8912, [
			Instruction.makeInstruction(ADD, 0, Instruction.constant(0), Instruction.constant(1))
		], [1, .8912]);

		// string + string
		assertInstructions("hi, meow!", [
			Instruction.makeInstruction(ADD, 0, Instruction.constant(0), Instruction.constant(1))
		], ["hi", ", meow!"]);
	}

	function testSub() {
		// int
		assertInstructions(5, [
			Instruction.makeInstruction(SUB, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 5]);

		// float
		assertInstructions(.11, [
			Instruction.makeInstruction(SUB, 0, Instruction.constant(0), Instruction.constant(1))
		], [2.2, 2.09]);

		// int + float
		assertInstructions(.5, [
			Instruction.makeInstruction(SUB, 0, Instruction.constant(0), Instruction.constant(1))
		], [1, .5]);
	}

	function testMul() {
		// int
		assertInstructions(15, [
			Instruction.makeInstruction(MUL, 0, Instruction.constant(0), Instruction.constant(1))
		], [5, 3]);

		// float
		assertInstructions(19.25, [
			Instruction.makeInstruction(MUL, 0, Instruction.constant(0), Instruction.constant(1))
		], [5.5, 3.5]);

		// int + float
		assertInstructions(16.5, [
			Instruction.makeInstruction(MUL, 0, Instruction.constant(0), Instruction.constant(1))
		], [3, 5.5]);
	}

	function testMod() {
		// int
		assertInstructions(1, [
			Instruction.makeInstruction(MOD, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 3]);

		// float
		assertInstructions(1.5, [
			Instruction.makeInstruction(MOD, 0, Instruction.constant(0), Instruction.constant(1))
		], [10.5, 3.0]);

		// float + int
		assertInstructions(1, [
			Instruction.makeInstruction(MOD, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 3.0]);

		assertInstructions(-1, [
			Instruction.makeInstruction(MOD, 0, Instruction.constant(0), Instruction.constant(1))
		], [-7, -3]);

		assertError(ThrowAssertType.DivideZero, [
			Instruction.makeInstruction(MOD, 0, Instruction.constant(0), Instruction.constant(1))
		], [3, 0]);
	}

	function testDiv() {
		// int
		assertInstructions(5, [
			Instruction.makeInstruction(DIV, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 2]);

		// float + int
		assertInstructions(2.75, [
			Instruction.makeInstruction(DIV, 0, Instruction.constant(0), Instruction.constant(1))
		], [5.5, 2]);

		// float
		assertInstructions(3, [
			Instruction.makeInstruction(DIV, 0, Instruction.constant(0), Instruction.constant(1))
		], [7.5, 2.5]);

		assertError(ThrowAssertType.DivideZero, [
			Instruction.makeInstruction(DIV, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 0]);
	}

	function testNegate():Void {
		// positive -> negative
		assertInstructions(-22, [Instruction.makeInstruction(NEG, 0, Instruction.constant(0))], [22]);
		assertInstructions(-22.3, [Instruction.makeInstruction(NEG, 0, Instruction.constant(0))], [22.3]);

		// negative -> positive
		assertInstructions(22, [Instruction.makeInstruction(NEG, 0, Instruction.constant(0))], [-22]);
		assertInstructions(22.3, [Instruction.makeInstruction(NEG, 0, Instruction.constant(0))], [-22.3]);
	}

	function testBitwise() {
		// and
		assertInstructions(0xA & 0xB, [
			Instruction.makeInstruction(BAND, 0, Instruction.constant(0), Instruction.constant(1))
		], [0xA, 0xB]);	

		// or
		assertInstructions(0xA | 0xB, [
			Instruction.makeInstruction(BOR, 0, Instruction.constant(0), Instruction.constant(1))
		], [0xA, 0xB]);	

		// xor
		assertInstructions(0xA ^ 0xB, [
			Instruction.makeInstruction(BXOR, 0, Instruction.constant(0), Instruction.constant(1))
		], [0xA, 0xB]);	

		// shift left
		assertInstructions(0xA << 0xB, [
			Instruction.makeInstruction(SHL, 0, Instruction.constant(0), Instruction.constant(1))
		], [0xA, 0xB]);	

		// shift right
		assertInstructions(0xA >> 0xB, [
			Instruction.makeInstruction(SHR, 0, Instruction.constant(0), Instruction.constant(1))
		], [0xA, 0xB]);	

		// unsigned shift right
		assertInstructions(0xA >>> 0xB, [
			Instruction.makeInstruction(USHR, 0, Instruction.constant(0), Instruction.constant(1))
		], [0xA, 0xB]);	

		// not
		assertInstructions(~0xA, [
			Instruction.makeInstruction(BNOT, 0, Instruction.constant(0))
		], [0xA]);	
	}

	function testComparison() {
		// not
		assertInstructions(0, [
			Instruction.makeInstruction(LOAD_BOOL, 1, 1), //load true
			Instruction.makeInstruction(NOT, 0, 1)
		]);

		// eq
		assertInstructions(true, [
			Instruction.makeInstruction(EQ, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 10]);

		assertInstructions(true, [
			Instruction.makeInstruction(EQ, 0, Instruction.constant(0), Instruction.constant(1))
		], [10.0, 10.0]);

		assertInstructions(true, [
			Instruction.makeInstruction(LOAD_BOOL, 1, 1),
			Instruction.makeInstruction(LOAD_BOOL, 2, 1),
			Instruction.makeInstruction(EQ, 0, 1, 2)
		]);

		assertInstructions(false, [
			Instruction.makeInstruction(LOAD_BOOL, 1, 1),
			Instruction.makeInstruction(LOAD_BOOL, 2, 0),
			Instruction.makeInstruction(EQ, 0, 1, 2)
		]);

		assertInstructions(true, [
			Instruction.makeInstruction(LOAD_NULL, 1),
			Instruction.makeInstruction(LOAD_NULL, 2),
			Instruction.makeInstruction(EQ, 0, 1, 2)
		]);

		assertInstructions(false, [
			Instruction.makeInstruction(LOAD_NULL, 1),
			Instruction.makeInstruction(EQ, 0, 1, Instruction.constant(0))
		], ["sure"]);

		// neq
		assertInstructions(true, [
			Instruction.makeInstruction(NEQ, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 20]);

		assertInstructions(false, [
			Instruction.makeInstruction(NEQ, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 10]);

		// less than
		assertInstructions(true, [
			Instruction.makeInstruction(LT, 0, Instruction.constant(0), Instruction.constant(1))
		], [10, 20]);

		assertInstructions(true, [ // less than equals
			Instruction.makeInstruction(LTE, 0, Instruction.constant(0), Instruction.constant(1))
		], [20, 20]);

		// greater than
		assertInstructions(true, [
			Instruction.makeInstruction(GT, 0, Instruction.constant(0), Instruction.constant(1))
		], [20, 10]);

		assertInstructions(true, [ // greater than equals
			Instruction.makeInstruction(GTE, 0, Instruction.constant(0), Instruction.constant(1))
		], [20, 20]);
	}

	function testGlobals():Void {
		assertInstructions(100, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1), // load const 1 (100) from register 0
			Instruction.makeInstructionBig(SET_GLOBAL, 0, 0), // set global 0 to val from register 0
			Instruction.makeInstruction(LOAD_NULL, 0), // set register zero to null
			Instruction.makeInstructionBig(GET_GLOBAL, 0, 0) // get global 0, returns 100
		], ["hiii", 100]);

		assertInstructions(50, [
			Instruction.makeInstructionBig(GET_GLOBAL, 0, 0),
			Instruction.makeInstruction(ADD, 0, 0, Instruction.constant(1))
		], [":3", 10], [":3" => 40]);

		assertInstructions(22, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1),
			Instruction.makeInstructionBig(SET_GLOBAL, 0, 0),
			Instruction.makeInstructionBig(GET_GLOBAL, 0, 0)
		], ["hi", 22], ["hi" => 0]);
	}

	function testMove() {
		assertInstructions(true, [
			Instruction.makeInstruction(LOAD_BOOL, 4, 1),
			Instruction.makeInstruction(MOVE, 0, 4)
		]);
	}

	function testJumps() {
		// JUMP
		assertInstructions(0, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1),
			Instruction.makeJump(1), // skip past the next instruction
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
		], [1, 0]);

		// JUMP IF FALSE
		assertInstructions(2, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstruction(LOAD_BOOL, 1, 0), // false
			Instruction.makeConditionalJump(JUMP_IF_FALSE, 1, 1),
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1)
		], [2, -1]);

		// JUMP IF TRUE
		assertInstructions(2, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstruction(LOAD_BOOL, 1, 1), // true
			Instruction.makeConditionalJump(JUMP_IF_TRUE, 1, 1),
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1)
		], [2, -1]);
	}

	function testLoop() {
		assertInstructions(25, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstructionBig(LOAD_CONST, 1, 1),
			Instruction.makeInstruction(EQ, 2, 1, Instruction.constant(0)),
			Instruction.makeConditionalJump(JUMP_IF_TRUE, 2, 3),
			Instruction.makeInstruction(ADD, 0, 0, Instruction.constant(1)),
			Instruction.makeInstruction(SUB, 1, 1, Instruction.constant(2)),
			Instruction.makeJump(-5)
		], [0, 5, 1]);
	}

	function testCall() {
		assertInstructions(null, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstructionBig(LOAD_CONST, 1, 1),
			Instruction.makeInstruction(CALL, 0, 1)
		], [
			((args:Array<Dynamic>) -> {
				trace('hewwo!! ${args.join(",")}');
				return null;
			} : NativeFunction),
			"orbl :3"
		]);
	}

	function testCallFunProto() {
		final proto = new FunctionProto(Vector.fromArrayCopy([
			Instruction.makeInstruction(ADD, 0, 0, 1),
			Instruction.makeInstruction(RETURN, 0, 1)
		]), [], 2, 2, "addTwo", [], []);

		assertInstructions(55, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstructionBig(LOAD_CONST, 1, 1), // dis arg 1 (50)
			Instruction.makeInstructionBig(LOAD_CONST, 2, 2), // dis arg 2 (5)
			Instruction.makeInstruction(CALL, 0, 2)
		], [proto, 50, 5]);

		assertError("expects 2 arg(s), got 1", [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstructionBig(LOAD_CONST, 1, 1),
			Instruction.makeInstruction(CALL, 0, 1)
		], [proto, 3]);
	}

	function testNewObj() {
		final obj:Dynamic = runInstructions([Instruction.makeInstruction(NEW_OBJECT, 0)], []);
		Assert.notNull(obj);
		Assert.equals(0, Reflect.fields(obj).length);
	}

	function testClosureNoUpvals() {
		final protogen = proto([
			Instruction.makeInstructionBig(LOAD_CONST, 0,0),
			Instruction.makeInstruction(RETURN, 0,1)
		], [22], 0, 1, "protogen h-heh");

		assertInstructions(22, [
			Instruction.makeInstructionBig(NEW_CLOSURE, 0,0),
			Instruction.makeInstruction(CALL, 0,0)
		], [protogen]);
	}

	function testGETUpvalueOpen() {
		final up = proto([
			Instruction.makeInstruction(GET_UPVALUE, 0,0),
			Instruction.makeInstruction(RETURN, 0, 1)
		], [], 0, 1, "up :3", [new UpvalueDesc(true, 0)]);

		assertInstructions(621, [
			Instruction.makeInstructionBig(LOAD_CONST, 0,1), // reg0 = 621
			Instruction.makeInstructionBig(NEW_CLOSURE, 1, 0), // capture reg0
			Instruction.makeInstruction(CALL, 1, 0), // call reg1, return res in reg 0
			Instruction.makeInstruction(MOVE, 0,1),
			Instruction.makeInstruction(LOAD_NULL, 1)
		], [up, 621]);
	}

	function testSETUpvalueOpen() {
		final up = proto([
			Instruction.makeInstructionBig(LOAD_CONST, 0,0),
			Instruction.makeInstruction(SET_UPVALUE, 0,0),
			Instruction.makeInstruction(RETURN, 0, 0)
		], [621], 0, 1, "up :3", [new UpvalueDesc(true, 0)]);

		assertInstructions(621, [
			Instruction.makeInstruction(LOAD_NULL, 0),
			Instruction.makeInstructionBig(NEW_CLOSURE, 1, 0),
			Instruction.makeInstruction(CALL, 1, 0)
		], [up]);
	}

	function testUpvalueLifetime() {
		final index = proto([
			Instruction.makeInstruction(GET_UPVALUE, 0, 0),
			Instruction.makeInstruction(ADD, 0, 0, Instruction.constant(0)),
			Instruction.makeInstruction(SET_UPVALUE, 0, 0),
			Instruction.makeInstruction(RETURN, 0, 1)
		], [1], 0, 1, "index", [new UpvalueDesc(true, 0)]);

		final makeIndexTrackThing = proto([
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0), // index = 0
			Instruction.makeInstructionBig(NEW_CLOSURE, 1, 1),
			Instruction.makeInstruction(RETURN, 1, 1)
		], [0, index], 0, 2, "makeIndexTrackThing");

		assertInstructions(3, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstruction(CALL, 0, 0), // reg0 is index closure
			// MOVE as CALL overwrites its own reg
			Instruction.makeInstruction(MOVE, 1, 0), Instruction.makeInstruction(CALL, 1, 0), // 1
			Instruction.makeInstruction(MOVE, 1, 0), Instruction.makeInstruction(CALL, 1, 0), // 2
			Instruction.makeInstruction(MOVE, 1, 0), Instruction.makeInstruction(CALL, 1, 0), // 3
			Instruction.makeInstruction(MOVE, 0, 1)
		], [makeIndexTrackThing]);
	}

	function testSharedUpvalue() {
		final increment = proto([
			Instruction.makeInstruction(GET_UPVALUE, 0, 0),
			Instruction.makeInstruction(ADD, 0, 0,Instruction.constant(0)),
			Instruction.makeInstruction(SET_UPVALUE, 0, 0),
			Instruction.makeInstruction(RETURN, 0, 0)
		], [1], 0, 1, "increment", [new UpvalueDesc(true, 0)]);

		final get = proto([
			Instruction.makeInstruction(GET_UPVALUE, 0, 0),
			Instruction.makeInstruction(RETURN, 0, 1)
		], [], 0, 1, "get", [new UpvalueDesc(true, 0)]);

		assertInstructions(2, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 2),
			Instruction.makeInstructionBig(NEW_CLOSURE,1,0), // increment
			Instruction.makeInstructionBig(NEW_CLOSURE,2,1), // get
			Instruction.makeInstruction(MOVE, 3, 1), Instruction.makeInstruction(CALL, 3, 0), // increment
			Instruction.makeInstruction(MOVE, 3, 1), Instruction.makeInstruction(CALL, 3, 0), // increment
			Instruction.makeInstruction(MOVE, 3, 2), Instruction.makeInstruction(CALL, 3, 0), // get
			Instruction.makeInstruction(MOVE, 0, 3)
		], [increment, get, 0]);
	}
	
	function testNestedUpvalue() {
		/**
		function main() {
			var i = 5;
			
			function func1(){
				function func2(){
					return i;	
				}
				return func2();
			}

			return func1(); // should return 5
		}
		**/
		final func2 = proto([
			Instruction.makeInstruction(GET_UPVALUE, 0, 0),
			Instruction.makeInstruction(RETURN, 0, 1)
		], [], 0, 1, "func2", [new UpvalueDesc(false, 0)]);

		final func1 = proto([
			Instruction.makeInstructionBig(NEW_CLOSURE, 0, 0),
			Instruction.makeInstruction(CALL, 0, 0),
			Instruction.makeInstruction(RETURN, 0, 1)
		], [func2], 0, 1, "func1", [new UpvalueDesc(true, 0)]);

		assertInstructions(5, [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1), // reg0 = 5
			Instruction.makeInstructionBig(NEW_CLOSURE, 1, 0),
			Instruction.makeInstruction(CALL, 1, 0),
			Instruction.makeInstruction(MOVE, 0, 1)
		], [func1, 5]);
	}

	function testCloseUpvalues() {
		final get = proto([
			Instruction.makeInstruction(GET_UPVALUE, 0,0),
			Instruction.makeInstruction(RETURN, 0,1)
		], [], 0,1,"g", [new UpvalueDesc(true, 0)]);

		// closed
		assertInstructions(1, [
			Instruction.makeInstructionBig(LOAD_CONST, 0,1),//1
			Instruction.makeInstructionBig(NEW_CLOSURE, 1,0),
			Instruction.makeInstruction(CLOSE_UPVALUES, 0),
			Instruction.makeInstructionBig(LOAD_CONST, 0,2),//2
			Instruction.makeInstruction(CALL,1,0),
			Instruction.makeInstruction(MOVE, 0,1)
		], [get,1,2]);

		// not closed.. closure can see updated reg val
		assertInstructions(2, [
			Instruction.makeInstructionBig(LOAD_CONST, 0,1),//1
			Instruction.makeInstructionBig(NEW_CLOSURE, 1,0),
			Instruction.makeInstructionBig(LOAD_CONST, 0,2),//2
			Instruction.makeInstruction(CALL,1,0),
			Instruction.makeInstruction(MOVE, 0,1)
		], [get,1,2]);

		// close reg1+... reg0 is unaffected
		// meaning: our get closure can still see the updated val
		assertInstructions(2, [
			Instruction.makeInstructionBig(LOAD_CONST, 0,1),//1
			Instruction.makeInstructionBig(NEW_CLOSURE, 1,0),
			Instruction.makeInstruction(CLOSE_UPVALUES, 1),
			Instruction.makeInstructionBig(LOAD_CONST, 0,2),//2
			Instruction.makeInstruction(CALL,1,0),
			Instruction.makeInstruction(MOVE, 0,1)
		], [get,1,2]);
	}

	function testReturnNoVal() {
		final doesNothing = proto([
			Instruction.makeInstruction(RETURN,0,0)
		], [], 0,1, "hi");

		assertInstructions(null, [
			Instruction.makeInstructionBig(LOAD_CONST, 0,0),
			Instruction.makeInstruction(CALL,0,0)
		], [doesNothing]);
	}

	function testRecursion() {
		// sum(n) = n == 0 ? 0 : n + sum(n - 1)
		final sum = proto([
			Instruction.makeInstruction(EQ, 1, 0, Instruction.constant(1)),
			Instruction.makeConditionalJump(JUMP_IF_FALSE, 1, 1),
			Instruction.makeInstruction(RETURN, 0, 1),
			Instruction.makeInstructionBig(GET_GLOBAL, 2, 0),
			Instruction.makeInstruction(SUB, 3, 0, Instruction.constant(2)),
			Instruction.makeInstruction(CALL, 2, 1),
			Instruction.makeInstruction(ADD, 0, 0, 2),
			Instruction.makeInstruction(RETURN, 0, 1)
		], ["sum", 0, 1], 1, 4, "sumFunc");

		function _sum(n:Int):Int {
			return n == 0 ? 0 : n + _sum(n-1);
		}
	
		assertInstructions(_sum(621), [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstructionBig(SET_GLOBAL, 0, 1),
			Instruction.makeInstructionBig(LOAD_CONST, 1, 2),
			Instruction.makeInstruction(CALL, 0, 1)
		], [sum, "sum", 621]);
	}

	function testErrorStackOverflow() {
		final f = proto([
			Instruction.makeInstructionBig(GET_GLOBAL, 0, 0),
			Instruction.makeInstruction(CALL, 0, 0),
			Instruction.makeInstruction(RETURN, 0, 0)
		], ["f"], 0, 1, "f");

		assertError("stack overflow", [
			Instruction.makeInstructionBig(LOAD_CONST, 0, 0),
			Instruction.makeInstructionBig(SET_GLOBAL, 0, 1),
			Instruction.makeInstruction(CALL, 0, 0)
		], [f, "f"]);
	}

	function testErrorCall() {
		final func = proto([
			Instruction.makeInstruction(RETURN, 0,0)
		], [], 1, 1, "func");

		assertError("func expects 1 arg(s), got 0", [
			Instruction.makeInstructionBig(NEW_CLOSURE, 0,0),
			Instruction.makeInstruction(CALL, 0,0)
		], [func]);

		// call a non func
		assertError("Cannot call 621", [
			Instruction.makeInstructionBig(LOAD_CONST, 0,0),
			Instruction.makeInstruction(CALL,0,0)
		], [621]);
	}

	function testReset() {
		final vm = new VM();

		final idk = proto([
			Instruction.makeInstructionBig(LOAD_CONST, 0,0),
			Instruction.makeInstruction(RETURN,0,1)
		], [621], 0,1, "idk");

		Assert.equals(621, vm.execute(idk));
		vm.reset();
		Assert.equals(621, vm.execute(idk));
	}

	function testAddToPreSetGlobal() {
		final vm = new VM();
		vm.set('val', 22);

		final protogen = proto([
			Instruction.makeInstructionBig(GET_GLOBAL,0,0),
			Instruction.makeInstruction(ADD, 0,0,  Instruction.constant(1)),
			Instruction.makeInstruction(RETURN,0,1)
		], ["val", 34], 0, 1, "testVarSet");

		Assert.equals(56, vm.execute(protogen));
	}

	function testSetVar() {
		final vm = new VM();
		vm.set('val', 1);

		final protogen = proto([
			Instruction.makeInstructionBig(LOAD_CONST, 0, 1),
			Instruction.makeInstructionBig(SET_GLOBAL,0,0),
			Instruction.makeInstruction(LOAD_NULL,0),
			Instruction.makeInstructionBig(GET_GLOBAL,0,0),
			Instruction.makeInstruction(RETURN,0,1)
		], ["val", 33], 0, 1, "testSetVar");

		Assert.equals(33, vm.execute(protogen));
	}

	function testSetAnonObj() {
		final vm = new VM();
		final obj = {hi: "meow!"};
		vm.set("obj", obj);
		final get = vm.get("obj");
		Assert.equals(obj, get);
		Assert.equals(obj.hi, get.hi);
	}

	function testNullVar() {
		final vm = new VM();
		Assert.isNull(vm.get("eee"));
		Assert.isFalse(vm.exists("eee"));
	}

	function testVarExists() {
		final vm = new VM();
		Assert.isFalse(vm.exists("hi"));
		vm.set("hi", "hii");
		Assert.isTrue(vm.exists("hi"));
		Assert.isFalse(vm.exists("_hi"));
	}

	function testVarExistsFromNewGlobals() {
		final vm = new VM([":3" => 621]);
		Assert.isTrue(vm.exists(":3"));
		Assert.equals(621, vm.get(":3"));
	}

	function testCallNativeThruPublicApiThing() {
		final vm = new VM();
		vm.set("len", Reflect.makeVarArgs((args:Array<Dynamic>) -> (args[0]:String).length));
		Assert.equals(5, vm.call("len", ["meow!"]));
	}

	function testGetCallable() {
		inline function _double() {
			return proto([
				Instruction.makeInstruction(MUL, 0, 0, Instruction.constant(0)),
				Instruction.makeInstruction(RETURN, 0,1)
			], [2], 1,2, "double");
		}

		final vm = new VM();
		vm.set('double', _double());

		final func = vm.get("double");
		Assert.isTrue(Reflect.isFunction(func));
		Assert.equals(20, Reflect.callMethod(null, func, [10]));
	}

	function testResetClearsGlobals() {
		final vm = new VM();
		vm.set('val', 22);
		vm.reset();

		Assert.isFalse(vm.exists("val"));
		Assert.isNull(vm.get("val"));
	}

	function testGetField() {
		final cls = new DummyCls();

		// str
		assertInstructions("mrraow!", [
			Instruction.makeInstruction(GET_FIELD, 0, Instruction.constant(0), Instruction.constant(1))
		], [cls, "str"]);

		// int
		assertInstructions(621, [
			Instruction.makeInstruction(GET_FIELD, 0,Instruction.constant(0), Instruction.constant(1))
		], [cls, "int"]);

		// float
		assertInstructions(6.21, [
			Instruction.makeInstruction(GET_FIELD, 0,Instruction.constant(0), Instruction.constant(1))
		], [cls, "float"]);

		// bool
		assertInstructions(false, [
			Instruction.makeInstruction(GET_FIELD, 0,Instruction.constant(0), Instruction.constant(1))
		], [cls, "bool"]);

		// obj in obj
		assertInstructions("hewwo!!", [
			Instruction.makeInstruction(GET_FIELD, 1,Instruction.constant(0), Instruction.constant(1)),
			Instruction.makeInstruction(GET_FIELD, 0,1, Instruction.constant(2))
		], [cls, "obj", "hi"]);

		// null var
		assertInstructions(null, [
			Instruction.makeInstruction(GET_FIELD, 0,Instruction.constant(0), Instruction.constant(1))
		], [cls, "nul"]);
	}

	function testSetField() {
		final cls = new DummyCls();

		// set str
		runInstructions([
			Instruction.makeInstructionBig(LOAD_CONST, 1, 0),
			Instruction.makeInstruction(SET_FIELD, 1, Instruction.constant(1), Instruction.constant(2))
		], [cls, "str", "meow..."]);
		Assert.equals("meow...", cls.str);

		// set int
		runInstructions([
			Instruction.makeInstructionBig(LOAD_CONST, 1, 0),
			Instruction.makeInstruction(SET_FIELD, 1, Instruction.constant(1), Instruction.constant(2))
		], [cls, "int", 21]);
		Assert.equals(21, cls.int);

		// set float
		runInstructions([
			Instruction.makeInstructionBig(LOAD_CONST, 1, 0),
			Instruction.makeInstruction(SET_FIELD, 1, Instruction.constant(1), Instruction.constant(2))
		], [cls, "float", 21.2]);
		Assert.equals(21.2, cls.float);

		// set float true
		runInstructions([
			Instruction.makeInstructionBig(LOAD_CONST, 1, 0),
			Instruction.makeInstruction(LOAD_BOOL, 2, 1),
			Instruction.makeInstruction(SET_FIELD, 1, Instruction.constant(1), 2)
		], [cls, "bool"]);
		Assert.isTrue(cls.bool);

		// set null
		runInstructions([
			Instruction.makeInstructionBig(LOAD_CONST, 1, 0),
			Instruction.makeInstruction(LOAD_NULL, 2),
			Instruction.makeInstruction(SET_FIELD, 1, Instruction.constant(1), 2)
		], [cls, "str"]);
		Assert.isNull(cls.str);
	}
}

// for testin' get/set field op codes
@:keep class DummyCls {
	public var str:Null<String> = "mrraow!";
	public var int:Int = 621;
	public var float:Float = 6.21;
	public var bool:Bool = false;
	public var obj:Dynamic = { hi: "hewwo!!" };
	public var nul = null;

	function func() {} // todo

	public function new() {}
}
