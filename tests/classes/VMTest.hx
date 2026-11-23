package tests.classes;

import haxe.ds.StringMap;
import haxe.ds.Vector;
import haxe.PosInfos;
import utest.Assert;
import utest.Test;
import regscript.VM;

enum abstract ThrowAssertType(String) to String from String {
	var DivideZero = "division by zero";
}

final class VMTest extends Test {
	/**
	 * By default, this function will return register `0`, so,
	 * make sure whatever result you want to compare is on register `0`. 
	 */
	@:ignore function assertInstructions(expected:Dynamic, instructions:Array<Op>, ?constants:Array<Dynamic>, ?globals:StringMap<Dynamic>, ?pos:PosInfos):Void {
		instructions = instructions.concat([Instruction.makeInstruction(RETURN, 0, 1)]);

		final fn = new FunctionProto(Vector.fromArrayCopy(instructions), constants??[], 0, 1, "hiii [waves]", [], []);

		final result:Dynamic = new VM(globals).run(fn);

		// to check if our add op is correctly returning an int (if int + int), or a float (if float + float or float + int)
		switch Type.typeof(expected) {
			case TFloat:
				Assert.floatEquals(expected, result, null, null, pos);
			case _:
				Assert.equals(expected, result, null, pos);
		}
	}

	@:ignore function assertError(expectedMsgPart:String, instructions:Array<Op>, constants:Array<Dynamic>, ?globals:StringMap<Dynamic>, ?pos:PosInfos):Void {
		instructions = instructions.concat([Instruction.makeInstruction(RETURN, 0, 1)]);

		final fn = new FunctionProto(Vector.fromArrayCopy(instructions), constants, 0, 2, "main", [], []);

		var caught:Dynamic = null;
		try {
			new VM(globals).run(fn);
		} catch (e:Dynamic) {
			caught = e;
		}

		Assert.notNull(caught, "expected an error ", pos);

		final contains:Bool = Std.string(caught).indexOf(expectedMsgPart) != -1;
		Assert.isTrue(contains, 'expected given error to contain "$expectedMsgPart", got "$caught"', pos);
	}

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
		assertInstructions(0xA >> 0xB, [
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
}
