package tests.classes;

import utest.Test;
import utest.Assert;
import haxe.PosInfos;
import regscript.Lexer;

function tokenize(src:String):Array<TokenType> {
	final tokens:Array<TokenType> = [];

	final lexer = new Lexer(src);
	while (true) {
		final type = lexer.nextToken().type;
		if (type == Eof) break;
		tokens.push(type);
	}

	return tokens;
}

class LexerTest extends Test {
	function check(src:String, expected:Array<TokenType>, ?pos:PosInfos) {
		Assert.equals(expected.toString(), tokenize(src).toString(), pos);
	}

	function fails(src:String, ?pos:PosInfos) {
		var threw = false;

		try tokenize(src)
		catch (_) threw = true;
		
		Assert.isTrue(threw, null, pos);
	}

	function testNumbers() {
		// int
		check('1', [LInt]);
		check('-1', [Minus, LInt]);
		check('1...5', [LInt, Ellipsis, LInt]);
		// float
		check('1.0', [LFloat]);
		check('-1.0', [Minus, LFloat]);
		check('.1', [LFloat]);
		check('-.1', [Minus, LFloat]);
		// scientific notation
		check('1e2', [LFloat]);
		check('1E2', [LFloat]);
		check('1e-2', [LFloat]);
		// hex
		check('0xFF', [LInt]);
		check('0xA', [LInt]);
		// dot access lexing test
		check('10.toString()', [LInt, Dot, Identifier, LeftParen, RightParen]);
		check('1.0.toString()', [LFloat, Dot, Identifier, LeftParen, RightParen]);
		// invalid number things
		fails('123meow');
		fails('0x');
		fails('6.2.1');
		fails('0xG');
	}

	function testOperators() {
		check('a?.b', [Identifier, NullSafeDot, Identifier]);
		check('a?.5:1', [Identifier, Question, LFloat, Colon, LInt]); // ternary op
		check('a??b', [Identifier, NullCoalesce, Identifier]);
		check('a??=b', [Identifier, AssignNullCoalesce, Identifier]);
		check('a=>b', [Identifier, ChunkyArrow, Identifier]);
		check('a->b', [Identifier, SkinnyArrow, Identifier]);
		check('a==b', [Identifier, Equals, Identifier]);
		check('a:Int', [Identifier, Colon, Identifier]);
		check('@:noUsing', [At, Colon, Identifier]);
		check('$', [Dollar]); // string interpo
		check('a-->b', [Identifier, Decrement, GreaterThan, Identifier]);
		check('a+++b', [Identifier, Increment, Plus, Identifier]);
		check('<= >= == != * % < >', [LessEquals, GreaterEquals, Equals, NotEquals, Star, Percent, LessThan, GreaterThan]);
		check('++ --', [Increment, Decrement]);
		check('<< >> >>>', [ShiftLeft, ShiftRight, UShiftRight]);
		check('<<= >>= >>>=', [AssignShl, AssignShr, AssignUShr]);
		check('&& || & | ^ ~ !', [LogicalAnd, LogicalOr, BitAnd, BitOr, BitXor, BitNot, Not]);
		check('+= -= *= /= %= &= |= ^=', [AssignAdd, AssignSub, AssignMul, AssignDiv, AssignMod, AssignBitAnd, AssignBitOr, AssignBitXor]);
		check('()[]{},;.', [LeftParen,RightParen,LeftBracket,RightBracket,LeftBrace,RightBrace,Comma,Semicolon,Dot]);
		check('sure ?', [Identifier, Question]);
		check('sure =', [Identifier, Assign]);
		check('sure >>', [Identifier, ShiftRight]);
		// invalid ops
		fails('..');
		fails('a..b');
		fails('`');
		fails('\\');
	}

	function testStrings() {
		check("'hi'", [LString]);
		check('"hi"', [LString]);
		check("'meow' 'nods'", [LString, LString]);
		check("'meow\\'s'", [LString]); // escaped
		check("'\\\\'", [LString]);
		check("'${meow}'", [LString]); // string interop
		check("'${meow[\"hi\"]}'", [LString]);
		check("'${ {a: 1}.a }'", [LString]);
		check("'${'x${y}'}'", [LString]);
		check("'$$'", [LString]);
		check("'$'", [LString]);
		check("\"${\"", [LString]);
		check("'a\nb' x", [LString, Identifier]); // multiline
		check("'café'", [LString]);
		// invalid strings
		fails('"hii');
		fails("'hii");
		fails("'\\'");
		fails("'${hii'");
		fails("'${");
	}

	// comments are ignored btw
	function testComments() {
		check('a // comment', [Identifier]);
		check('a // comment\nb', [Identifier, Identifier]);
		check('a /* x */ b', [Identifier, Identifier]);
		check('a /* x\ny */ b', [Identifier, Identifier]);
		check('/**/ a', [Identifier]);
		check('/* // */ a', [Identifier]);
		check('// /* \n a', [Identifier]);
		check("'// hello'", [LString]); // string not comment <3
		check("'/* nuh uh */'", [LString]);
		check('a/b', [Identifier, Slash, Identifier]);
		check('a/=b', [Identifier, AssignDiv, Identifier]);
		check('// é', []); // special char comment - should ignore
		// invalid comments
		fails('/*');
		fails('/*/');
		fails('a /* hewwo'); // unclosed comment
	}

	// so #if #else #end #elseif
	function testCompilerConditionals() {
		check('#if sure', [CIf, Identifier]);
		check('#elseif sure', [CElseIf, Identifier]);
		check('#else', [CElse]);
		check('#end', [CEnd]);
		check('#if(sure&&yes)', [CIf, LeftParen, Identifier, LogicalAnd, Identifier, RightParen]);
		check('#elseif(sure&&yes)', [CElseIf, LeftParen, Identifier, LogicalAnd, Identifier, RightParen]);
		check('#if ver <= 5', [CIf, Identifier, LessEquals, LInt]);
		check('#if (windows || debug)', [CIf, LeftParen, Identifier, LogicalOr, Identifier, RightParen]);
		fails('#');
		fails('# if');
		fails('#hi');
		fails('#if_');
		fails('#end_');
	}

	function testRegex() {
		check('~/a/', [LEReg]);
		check('~/a/gi', [LEReg]);
		check('~/a\\/b/', [LEReg]); // escaped
		check('~/a/g x', [LEReg, Identifier]);
		check('~a', [BitNot, Identifier]);
		fails('~/abc');
		fails('~/abc\n/');
		fails('~/a\\');
	}

	function testIdentifiers() {
		for (s in ['_', 'a', 'a1']) {
			check(s, [Identifier]);
		}

		check('', []); // lol
		check(' \t\r\n ', []); // ignore escapes & whitespace
		fails('é');
		fails('¬');
	}

	function testKeywords() {
		final keywords:Map<String, TokenType> = [
			'typedef' => KwTypedef, 'package' => KwPackage, 'var' => KwVar, 'final' => KwFinal,
			'public' => KwPublic, 'private' => KwPrivate, 'static' => KwStatic, 'inline' => KwInline,
			'override' => KwOverride, 'abstract' => KwAbstract, 'interface' => KwInterface,
			'dynamic' => KwDynamic, 'untyped' => KwUntyped, 'enum' => KwEnum,
			'function' => KwFunction, 'class' => KwClass, 'extends' => KwExtends, 'implements' => KwImplements,
			'if' => KwIf, 'else' => KwElse, 'switch' => KwSwitch, 'case' => KwCase, 'default' => KwDefault,
			'while' => KwWhile, 'do' => KwDo, 'for' => KwFor, 'in' => KwIn,
			'break' => KwBreak, 'continue' => KwContinue, 'return' => KwReturn,
			'new' => KwNew, 'import' => KwImport, 'using' => KwUsing,
			'try' => KwTry, 'catch' => KwCatch, 'throw' => KwThrow,
			'this' => KwThis, 'super' => KwSuper, 'cast' => KwCast, 'as' => KwAs, 'is' => KwIs,
			'true' => LBool, 'false' => LBool, 'null' => LNull
		];

		for (keyword => token in keywords) {
			check(keyword, [token]); // ensure they are matched correctly
			// keywords as variable names
			check('${keyword}_', [Identifier]);
			check('_$keyword', [Identifier]);
			check(keyword.toUpperCase(), [Identifier]);
		}
	}

	function testMaps() {
		check("['a'=>1, \"b\"=>2]", [LeftBracket, LString, ChunkyArrow, LInt, Comma, LString, ChunkyArrow, LInt, RightBracket]);
		check('[1=>"a", 2=>\'b\']', [LeftBracket, LInt, ChunkyArrow, LString, Comma, LInt, ChunkyArrow, LString, RightBracket]);
	}

	function testSwitchCase() {
		check('switch num { case 1: default: }', [KwSwitch, Identifier, LeftBrace, KwCase, LInt, Colon, KwDefault, Colon, RightBrace]);
		check('case 1 | 2:', [KwCase, LInt, BitOr, LInt, Colon]);
		check('case _:', [KwCase, Identifier, Colon]);
		check('default:', [KwDefault, Colon]);
		check('case num:', [KwCase, Identifier, Colon]);
		check('case var num:', [KwCase, KwVar, Identifier, Colon]);
	}

	#if hscriptPos
	// todo: add more hscritpPos tests
	function testPositions() {
		/// consume both the sure & nods, ignore "hewwo"
		final l = new Lexer("sure\n  /* hewwo\n */ nods");
		l.nextToken();// consume sure
		final t = l.nextToken(); // consume nods

		Assert.equals(3, t.line);
		Assert.equals(5, t.col); // comments mustn't break col
	}
	#end
}
