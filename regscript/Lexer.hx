package regscript;

import StringTools.fastCodeAt;

enum abstract TokenType(Int) from Int to Int {
	var Eof = 0x00;

	// Literals
	var LInt;
	var LFloat;
	var LString;
	var LBool;
	var LNull;
	var LEReg; // ~/../..

	// Keywords
	var KwVar;
	var KwFinal;
	var KwFunction;
	var KwClass;
	var KwExtends;
	var KwIf;
	var KwElse;
	var KwSwitch;
	var KwCase;
	var KwDefault;
	var KwWhile;
	var KwDo;
	var KwFor;
	var KwIn;
	var KwBreak;
	var KwContinue;
	var KwReturn;
	var KwNew;
	var KwImport;
	var KwUsing;
	var KwPublic;
	var KwPrivate;
	var KwStatic;
	var KwInline;
	var KwOverride;
	var KwTry;
	var KwCatch;
	var KwThrow;
	var KwThis;
	var KwSuper;
	var KwCast;
	var KwAs; // as (idk as Int) ~ import stuff
	var KwIs; // is (type check ~ var is Int)
	var KwImplements;
	var KwTypedef;
	var KwPackage;
	var KwAbstract;
	var KwEnum;
	var KwInterface;
	var KwDynamic;
	var KwUntyped;

	// Operators, Punctuation & Other stuffs
	var Comma; // ,
	var Semicolon; // ;
	var Colon; // :
	var Dot; // .
	var Ellipsis; // ... (for i in 0...20)
	var ChunkyArrow; // =>
	var SkinnyArrow; // ->
	var At; // @ (for metadata)
	var Identifier;
	var NullSafeDot; // ?. (null safe field access)
	var Dollar; // $ (string interpo)
	var LeftParen; // (
	var RightParen; // )
	var LeftBrace; // {
	var RightBrace; // }
	var LeftBracket; // [
	var RightBracket; // ]
	var Assign; // =
	var Plus; // +
	var Minus; // -
	var Star; // *
	var Slash; // /
	var Percent; // %
	var Increment; // ++
	var Decrement; // --

	// UH
	var AssignAdd; // +=
	var AssignSub; // -=
	var AssignMul; // *=
	var AssignDiv; // /=
	var AssignMod; // %=
	var Equals; // ==
	var NotEquals; // !=
	var LessThan; // <
	var GreaterThan; // >
	var LessEquals; // <=
	var GreaterEquals; // >=
	var LogicalAnd; // &&
	var LogicalOr; // ||
	var Not; // !
	var BitAnd; // &
	var BitOr; // |
	var BitXor; // ^
	var BitNot; // ~
	var ShiftLeft; // <<
	var ShiftRight; // >>
	var UShiftRight; // >>> (i still dont know what this does)
	var AssignShl; // <<=
	var AssignShr; // >>=
	var AssignUShr; // >>>=
	var AssignBitAnd; // &=
	var AssignBitOr; // |=
	var AssignBitXor; // ^=
	var AssignNullCoalesce; // ??=
	var Question; // ?
	var NullCoalesce; // ??

	// conditional compiler directives
	var CIf; // #if
	var CElseIf; // #elseif
	var CElse; // #else
	var CEnd; // #end
	// todo: toString for the upcoming printer class
}

@:publicFields
final class Token {
	var type:TokenType;

	#if hscriptPos
	var line:Int;
	var col:Int;
	#end

	var start:Int;
	var length:Int;

	public inline function new(type:TokenType, start:Int, length:Int, #if hscriptPos line:Int, col:Int #end) {
		this.type = type;
		this.start = start;
		this.length = length;

		#if hscriptPos
		this.line = line;
		this.col = col;
		#end
	}
}

// self explanatory, no?
inline function isIdentifierChar(code:Int) {
	return (code >= "A".code && code <= "Z".code)
		|| (code >= "a".code && code <= "z".code)
		|| (code >= "0".code && code <= "9".code)
		|| code == "_".code;
}

inline function isNumber(code:Int) {
	return (code >= "0".code && code <= "9".code);
}

inline function isHexadecimal(c:Int) {
	return isNumber(c) || (c >= "a".code && c <= "f".code) || (c >= "A".code && c <= "F".code);
}

// Basically, instead of splitting and storing the actual value in the token,
// im just storing the start and end, doing this should theoretically cut down
// on the lexical analysis phase.

// Also, each lexer instance only allocates a single token throughout it's whole lifespan.
// Every time you call `next`, the `token` instance variable gets updated and returned.
@:nullSafety(Strict)
class Lexer {
	var input:String;
	var length:Int; // input length
	var pos:Int = 0;

	#if hscriptPos
	var line:Int = 1;
	var col:Int = 1;
	#end

	public var fileName(default, null):String;

	public function new(input:String, ?fileName:String):Void {
		this.input = input;
		this.length = input.length;
		this.fileName = fileName ?? "<unknown>";
	}

	/**
	 * Extract the text using the given token.
	 */
	public inline function extractText(t:Token):String {
		return input.substr(t.start, t.length);
	}

	public inline function hasNext():Bool {
		return pos < length;
	}

	inline function peek(offset:Int = 0):Int {
		final i = pos + offset;
		return i < length ? fastCodeAt(input, i) : 0;
	}

	public inline function error(msg) {
		return new Error(msg, fileName, #if hscriptPos line, col #end);
	}

	// a single multi use token
	public final token:Token = new Token(TokenType.Eof, 0, 0, #if hscriptPos 1, 1 #end);

	/**
	 * Update the current token, and return it
	 */
	inline function update(type:TokenType, pos:Int, length:Int, #if hscriptPos line:Int, col:Int #end):Token {
		token.type = type;
		token.start = pos;
		token.length = length;
		#if hscriptPos
		token.line = line;
		token.col = col;
		#end
		return token;
	}

	inline function advance():Void {
		pos++;
		#if hscriptPos col++; #end
	}

	inline function newline() {
		pos++;
		#if hscriptPos
		line++;
		col = 1;
		#end
	}

	/**
	 * Keep advancing until we hit a non-digit.
	 */
	inline function consumeDigits() {
		while (isNumber(peek())) {
			advance();
		}
	}

	/**
	 * Next token
	 */
	public function next():Token {
		// todo windows /r/n vs linux's /n
		// skips whitespace, tabs, newlines, \r, and comments
		while (pos < length) {
			final code = fastCodeAt(input, pos);

			if (code == ' '.code || code == '\t'.code || code == '\r'.code) {
				advance();
			} else if (code == '\n'.code) {
				newline();
			} else if (code == '/'.code && pos + 1 < length) {
				final next = peek(1);
				if (next == '/'.code) {
					pos += 2;
					while (pos < length && peek() != '\n'.code) {
						pos++;
					}
				} else if (next == '*'.code) {
					pos += 2;
					#if hscriptPos col += 2; #end
					while (true) {
						if (pos >= length)
							throw error("unterminated comment");
						if (peek() == '*'.code && peek(1) == '/'.code) {
							pos += 2;
							#if hscriptPos col += 2; #end
							break;
						}
						if (peek() == '\n'.code)
							newline();
						else
							advance();
					}
				} else {
					break;
				}
			} else {
				break;
			}
		}

		// Eof ~ push token
		if (pos >= length) {
			return update(Eof, pos, 0, #if hscriptPos line, col #end);
		}

		final startPos = pos, code = peek();

		#if hscriptPos
		final startLine = line;
		final startCol = col;
		#end

		// do identifiers & keywords
		// identifiers cannot start with numbers
		if (isIdentifierChar(code) && !isNumber(code)) {
			return doIdentifiers(startPos, #if hscriptPos startLine, startCol #end);
		}

		// lex numbers
		// both int, floats, and floats with a leading period.
		if (isNumber(code) || (code == '.'.code && isNumber(peek(1)))) {
			return doNumber(startPos, #if hscriptPos startLine, startCol #end);
		}

		// strings
		if (code == '"'.code || code == "'".code) {
			return doString(code, startPos, #if hscriptPos startLine, startCol #end);
		}

		// pre processors
		if (code == '#'.code) {
			return doConditionals(startPos, #if hscriptPos startLine, startCol #end);
		}

		// regex stuffs ~/../..
		if (code == '~'.code && peek(1) == '/'.code) {
			return doRegex(startPos, #if hscriptPos startLine, startCol #end);
		}

		// operators & symbol stuff
		return doOperator(code, startPos, #if hscriptPos startLine, startCol #end);
	}

	// compiler conditionals
	function doConditionals(startPos:Int, #if hscriptPos startLine:Int, startCol:Int #end) {
		advance(); // consume #
		final s = pos;
		while (isIdentifierChar(peek()))
			advance();

		final err = error("Unknown token"); // do suggestions? how would that even work???
		final peekOffset = s - pos;

		final type = switch pos - s {
			case 2: // if
				if (peek(peekOffset) == 'i'.code && peek(peekOffset + 1) == 'f'.code) {
					CIf;
				} else {
					throw err;
				}
			case 4: // else
				if (peek(peekOffset) == 'e'.code && peek(peekOffset + 1) == 'l'.code && peek(peekOffset + 2) == 's'.code && peek(peekOffset + 3) == 'e'.code) {
					CElse;
				} else {
					throw err;
				}
			case 6: // elseif
				if (peek(peekOffset) == 'e'.code && peek(peekOffset + 1) == 'l'.code && peek(peekOffset + 2) == 's'.code && peek(peekOffset + 3) == 'e'.code && peek(peekOffset + 4) == 'i'.code
					&& peek(peekOffset + 5) == 'f'.code) {
					CElseIf;
				} else {
					throw err;
				}
			case 3: // end
				if (peek(peekOffset) == 'e'.code && peek(peekOffset + 1) == 'n'.code && peek(peekOffset + 2) == 'd'.code) {
					CEnd;
				} else {
					throw err;
				}
			case _: throw err;
		}

		return update(type, startPos, pos - startPos, #if hscriptPos startLine, startCol #end);
	}

	function doRegex(startPos:Int, #if hscriptPos startLine:Int, startCol:Int #end) {
		advance();
		advance(); // ~/
		while (true) {
			if (pos >= length || peek() == '\n'.code)
				throw error("unterminated regex");
			final c = peek();
			advance();
			if (c == '\\'.code) {
				if (pos >= length || peek() == '\n'.code)
					throw error("unterminated regex");
				advance();
			} else if (c == '/'.code) {
				break;
			}
		}
		while (peek() >= 'a'.code && peek() <= 'z'.code)
			advance(); // flags
		return update(LEReg, startPos, pos - startPos, #if hscriptPos startLine, startCol #end);
	}

	function doNumber(startPos:Int, #if hscriptPos startLine:Int, startCol:Int #end) {
		var float = false;

		if (peek() == '0'.code && (peek(1) == 'x'.code || peek(1) == 'X'.code)) {
			advance();
			advance();
			final s = pos;
			while (isHexadecimal(peek()))
				advance();
			if (pos == s)
				throw error("bad hex literal");
		} else {
			consumeDigits();
			if (peek() == '.'.code && isNumber(peek(1))) { // `1.toString()` and `0...5` still work
				float = true;
				advance();
				consumeDigits();

				// prevent numbers like 6.2.1 from passing
				if (peek() == '.'.code && isNumber(peek(1)))
					throw error("bad number");
			}
			final e = peek(), n = peek(1);
			if ((e == 'e'.code || e == 'E'.code) && (isNumber(n) || ((n == '+'.code || n == '-'.code) && isNumber(peek(2))))) {
				float = true;
				advance();
				advance();
				consumeDigits();
			}
		}

		if (isIdentifierChar(peek()))
			throw error("bad number");
		return update(float ? LFloat : LInt, startPos, pos - startPos, #if hscriptPos startLine, startCol #end);
	}

	function doString(code:Int, startPos:Int, #if hscriptPos startLine:Int, startCol:Int #end) {
		advance();
		skipString(code);
		return update(LString, startPos, pos - startPos, #if hscriptPos startLine, startCol #end);
	}

	// pos is after the opening quote, consumes the closing one
	function skipString(q:Int) {
		while (pos < length) {
			final c = peek();
			if (c == q) {
				advance();
				return;
			}
			if (c == '\n'.code) {
				newline();
			} else if (c == '\\'.code) {
				advance();
				if (peek() == '\n'.code)
					newline();
				else if (pos < length)
					advance();
			} else if (c == "$".code && q == "'".code) {
				advance();
				if (peek() == '{'.code) {
					advance();
					skipInterp();
				} else if (peek() == "$".code) {
					advance();
				}
			} else {
				advance();
			}
		}
		throw error("unterminated string");
	}

	function skipInterp() {
		var depth = 1;
		while (pos < length) {
			final c = peek();
			if (c == '"'.code || c == "'".code) {
				advance();
				skipString(c);
			} else if (c == '\n'.code) {
				newline();
			} else {
				if (c == '{'.code)
					depth++;
				else if (c == '}'.code)
					depth--;
				advance();
				if (depth == 0)
					return;
			}
		}
		throw error("unterminated string interpolation");
	}

	function doOperator(code:Int, startPos:Int, #if hscriptPos startLine:Int, startCol:Int #end) {
		advance();

		final type:TokenType = switch code {
			case '('.code: LeftParen;
			case ')'.code: RightParen;
			case '{'.code: LeftBrace;
			case '}'.code: RightBrace;
			case '['.code: LeftBracket;
			case ']'.code: RightBracket;
			case ','.code: Comma;
			case ';'.code: Semicolon;
			case ":".code: Colon;
			case '@'.code: At;
			case '$'.code: Dollar;
			case '~'.code: BitNot;

			case '.'.code:
				if (peek() == '.'.code) { // ..
					advance();
					if (peek() == '.'.code) { // ...
						advance();
						Ellipsis; // for 0...67
					} else {
						throw error('Invalid token `..`');
					}
				} else {
					Dot;
				}

			case '?'.code:
				if (peek() == '?'.code) { // ??
					advance();
					if (peek() == '='.code) { // ??=
						advance();
						AssignNullCoalesce;
					} else {
						NullCoalesce;
					}
				} else if (peek() == '.'.code && !isNumber(peek(1))) { // ?.
					advance();
					NullSafeDot;
				} else { // ?
					Question;
				}

			case '='.code:
				if (peek() == '='.code) { // ==
					advance();
					Equals;
				} else if (peek() == '>'.code) { // =>
					advance();
					ChunkyArrow;
				} else { // =
					Assign;
				}

			case '-'.code:
				if (peek() == '>'.code) { // ->
					advance();
					SkinnyArrow;
				} else if (peek() == '='.code) { // -=
					advance();
					AssignSub;
				} else if (peek() == '-'.code) { // --
					advance();
					Decrement;
				} else { // -
					Minus;
				}

			case '+'.code:
				if (peek() == '='.code) { // +=
					advance();
					AssignAdd;
				} else if (peek() == '+'.code) { // ++
					advance();
					Increment;
				} else { // +
					Plus;
				}

			case '*'.code:
				if (peek() == '='.code) { // *=
					advance();
					AssignMul;
				} else { // *
					Star;
				}

			case '/'.code:
				if (peek() == '='.code) { // /=
					advance();
					AssignDiv;
				} else { // /
					Slash;
				}

			case '%'.code:
				if (peek() == '='.code) { // %=
					advance();
					AssignMod;
				} else { // %
					Percent;
				}

			case '<'.code:
				if (peek() == '<'.code) { // <<
					advance();
					if (peek() == '='.code) {
						advance();
						AssignShl;
					} else {
						ShiftLeft;
					}
				} else if (peek() == '='.code) {
					advance();
					LessEquals;
				} else {
					LessThan;
				}

			case '>'.code:
				if (peek() == '>'.code) { // >>
					advance();
					if (peek() == '>'.code) { // >>>
						advance();
						if (peek() == '='.code) { // >>>=
							advance();
							AssignUShr;
						} else { // >>>
							UShiftRight;
						}
					} else {
						if (peek() == '='.code) { // >>=
							advance();
							AssignShr;
						} else { // >>
							ShiftRight;
						}
					}
				} else if (peek() == '='.code) { // >=
					advance();
					GreaterEquals;
				} else { // >
					GreaterThan;
				}

			case '!'.code:
				if (peek() == '='.code) { // !=
					advance();
					NotEquals;
				} else { // !
					Not;
				}

			case '&'.code:
				if (peek() == '&'.code) {
					advance();
					LogicalAnd;
				} else if (peek() == '='.code) {
					advance();
					AssignBitAnd;
				} else {
					BitAnd;
				}

			case '|'.code:
				if (peek() == '|'.code) { // ||
					advance();
					LogicalOr;
				} else if (peek() == '='.code) { // |=
					advance();
					AssignBitOr;
				} else { // |
					BitOr;
				}

			case '^'.code:
				if (peek() == '='.code) { // ^=
					advance();
					AssignBitXor;
				} else { // ^
					BitXor;
				}

			default:
				throw error('Invalid character 0x${StringTools.hex(code)}');
		}

		return update(type, startPos, pos - startPos, #if hscriptPos startLine, startCol #end);
	}

	function doIdentifiers(startPos:Int, #if hscriptPos startLine:Int, startCol:Int #end) {
		while (pos < length && isIdentifierChar(peek())) {
			advance();
		}

		final length:Int = pos - startPos;

		// no keyword is longer than 10 characters SOOO
		if(length > 10) {
			return update(Identifier, startPos, length, #if hscriptPos startLine, startCol #end);
		}

		// todo: dis slow. change it ;<
		final type = switch input.substr(startPos, length) {
			case "typedef": TokenType.KwTypedef;
			case "package": TokenType.KwPackage;
			case 'var': TokenType.KwVar;
			case 'final': TokenType.KwFinal;
			case "public": TokenType.KwPublic;
			case "private": TokenType.KwPrivate;
			case "static": TokenType.KwStatic;
			case "inline": TokenType.KwInline;
			case "override": TokenType.KwOverride;
			case "abstract": TokenType.KwAbstract;
			case "interface": TokenType.KwInterface;
			case "dynamic": TokenType.KwDynamic;
			case "untyped": TokenType.KwUntyped;
			case "enum": TokenType.KwEnum;
			case "function": TokenType.KwFunction;
			case "class": TokenType.KwClass;
			case "extends": TokenType.KwExtends;
			case "implements": TokenType.KwImplements;
			case "if": TokenType.KwIf;
			case "else": TokenType.KwElse;
			case "switch": TokenType.KwSwitch;
			case "case": TokenType.KwCase;
			case "default": TokenType.KwDefault;
			case "while": TokenType.KwWhile;
			case "do": TokenType.KwDo;
			case "for": TokenType.KwFor;
			case "in": TokenType.KwIn;
			case "break": TokenType.KwBreak;
			case "continue": TokenType.KwContinue;
			case "return": TokenType.KwReturn;
			case "new": TokenType.KwNew;
			case "import": TokenType.KwImport;
			case "using": TokenType.KwUsing;
			case "try": TokenType.KwTry;
			case "catch": TokenType.KwCatch;
			case "throw": TokenType.KwThrow;
			case "this": TokenType.KwThis;
			case "super": TokenType.KwSuper;
			case "cast": TokenType.KwCast;
			case "as": TokenType.KwAs;
			case "is": TokenType.KwIs;
			case "true", "false": TokenType.LBool;
			case "null": TokenType.LNull;
			default: TokenType.Identifier;
		}

		return update(type, startPos, length, #if hscriptPos startLine, startCol #end);
	}
}
