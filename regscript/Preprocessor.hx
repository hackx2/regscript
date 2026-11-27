package regscript;

import regscript.Lexer.Token;
import regscript.Lexer.TokenType;
import haxe.ds.StringMap;

@:nullSafety(Strict)
class Preprocessor {
	public final lexer:Lexer;
	public final defines:Map<String, String>;

	public function new(lexer:Lexer, ?defines:Map<String, String>) {
		this.lexer = lexer;
		this.defines = defines ?? [];
	}

	/** how many if blocks we're currently inside **/
	var nestDepth = 0;

	// One bit per nesting level (max 31 levels deep).
	// Bit `x` is on while level `x` has chosen its `#else` branch.
	// This basically prevents more than one `#else` branch within a single conditional block.
	var elseBits = 0;
	
	/** Whether we're currently handling a token right now, or not **/
	var pending = false;

	public inline function next():Token {
		final token = acquire();
		final type:Int = cast token.type;

		return (type == (Eof : Int) || (type >= (CIf : Int) && type <= (CEnd : Int))) ? filter(token) : token;
	}

	inline function acquire() { // acquire current (or pending) token
		if (pending) {
			pending = false;
			return lexer.token; // pass the token back since we're finished with it
		}

		return lexer.next();
	}

	function filter(token:Token):Token {
		while (true) {
			switch token.type {
				case Eof:
					if (nestDepth != 0) { // if we're inside a conditional block
						throw lexer.error("Unclosed conditional compilation block");
					}
					return token;
				case CIf:
					if (evalCondition())
						push(false)
					else
						skipBranch();
				case CElse, CElseIf:
					if (nestDepth == 0) {
						throw lexer.error('#else without an #if');
					}
					
					if (((elseBits >> (nestDepth - 1)) & 1) != 0) {
						throw lexer.error('#else/#elseif after #else');
					}

					skipToEnd();
					pop();
				case CEnd:
					if(nestDepth==0) throw 'Invalid #end';
					pop();
				default:
					return token;
			}
			
			token = acquire();
		}
	}

	inline function push(elseBranch:Bool) {
		if(nestDepth >= 31) throw lexer.error("nested too deep... max depth 31");

		if(elseBranch) elseBits |= 1 << nestDepth;
		else elseBits &= ~(1 << nestDepth);

		nestDepth++;
	}

	inline function pop() {
		nestDepth--;
		elseBits &= ~(1<<nestDepth);
	}

	// if the condition was false, skip to the next branch (or #end)
	function skipBranch() {
		var depth = 0;

		while (true) {
			final token = acquire();
			switch token.type {
				case CIf:
					depth++;
				case CEnd:
					if(depth == 0) return;
					depth--;
				case CElseIf if (depth==0):
					if(evalCondition()) {
						push(false);
						return;
					}
				case CElse if(depth == 0):
					push(true);
					return ;
				case Eof: throw lexer.error('Unclosed conditional compilation block'); // totally not stolen from try.haxe.org
				default:
			}
		}
	}

	// if a branch has been chosen, skip to the end
	function skipToEnd() {
		var depth = 0;

		while (true) {
			final token = acquire();
			switch token.type {
				case CIf:
					depth++;
				case CEnd:
					if(depth==0) return;
					depth--;
				case Eof: throw lexer.error('Unclosed conditional compilation block'); // totally not stolen from try.haxe.org
				default:
			}
		}
	}

	// eval stuff below :3

	function evalCondition() {
		lexer.next();
		final res = orExpr();
		pending = true;
		return res != null;
	}

	@:noCompletion
	inline static final TRUE = "1"; // ignore me... please

	function orExpr():Null<String> {
		var left = andExpr();

		while (lexer.token.type == LogicalOr) {
			lexer.next();

			final right = andExpr();

			left = (left != null || right != null) ? TRUE : null;
		}

		return left;
	}

	function andExpr():Null<String> {
		var left = comparisonExpr();

		while (lexer.token.type == LogicalAnd) {
			lexer.next();

			final right = comparisonExpr();

			left = (left != null && right != null) ? TRUE : null;
		}

		return left;
	}

	// for stuff like #if (10 >= 20) #end
	function comparisonExpr():Null<String> {
		final left = unary();
		final type = lexer.token.type;

		switch type {
			case Equals, NotEquals, LessThan, GreaterThan, LessEquals, GreaterEquals:
				lexer.next();
				final right = unary();
				return comparePlease(type, left, right) ? TRUE : null;
			default:
				return left;
		}
	}

	// please.......
	function comparePlease(type:TokenType, left:Null<String>, right:Null<String>):Bool {
		final l = left == null ? Math.NaN : Std.parseFloat(left);
		final r = right == null ? Math.NaN : Std.parseFloat(right);

		if (!Math.isNaN(l) && !Math.isNaN(r)) {
			return switch type {
				case Equals: l == r;
				case NotEquals: l != r;
				case LessThan: l < r;
				case GreaterThan: l > r;
				case LessEquals: l <= r;
				case GreaterEquals: l >= r;
				default: throw 'how??';
			}
		}

		final l = left ?? "";
		final r = right ?? "";

		return switch type {
			case Equals: l == r;
			case NotEquals: l != r;
			case LessThan: l < r;
			case GreaterThan: l > r;
			case LessEquals: l <= r;
			case GreaterEquals: l >= r;
			default: throw 'how?? (string edition)';
		}
	}

	function unary():Null<String> {
		final token = lexer.token;
		switch token.type {
			case Not:
				lexer.next();
				return unary() == null ? TRUE : null;
			case LeftParen:
				lexer.next();
				final v = orExpr();
				if (lexer.token.type != RightParen) {
					throw lexer.error('expected )');
				}
				lexer.next();
				return v;
			case Identifier:
				final txt = defines.get(lexer.extractText(token));
				lexer.next();
				return txt;
			case LInt | LFloat | LString:
				final txt = lexer.extractText(token);
				lexer.next();
				return (token.type == LString) ? txt.substr(1, txt.length - 2) : txt;
			case LBool:
				final txt = lexer.extractText(token) == "true" ? TRUE : null;
				lexer.next();
				return txt;
			default:
				throw lexer.error('BAD LOL');
		}
	}
}
