package tests.classes;

import utest.Test;
import utest.Assert;
import haxe.PosInfos;
import haxe.ds.StringMap;
import regscript.Lexer;
import regscript.Preprocessor;

function process(src:String, defines:Map<String, String>) {
    final lexer = new Lexer(src);
    final preprocessor = new Preprocessor(lexer, defines);
    final result:Array<TokenType> = [];

    //var res = "";
    while (true) {
        final type = preprocessor.next().type;
      //  res += lexer.extractText(lexer.token);
        if (type == TokenType.Eof) break;
        result.push(type);
    }
    //trace(res);
    return result;
}

class PreprocessorTest extends Test {
    function check(src:String, hope:Array<TokenType>, ?defines:Map<String, String>, ?pos:PosInfos) {
        //trace(process(src, defines));
        return Assert.same(hope, process(src, defines), null, null, null, pos);
    }

    function fails(src:String, ?defines:Map<String, String>, ?pos:PosInfos) {
        var threw = false;
        try process(src, defines)
        catch (_) threw = true;
        return Assert.isTrue(threw, null, pos);
    }

    // can't think of good test func names

    function testSuccess() {
        check("#if debug 1.0 #else 1 #end", [LInt]);
        check("#if debug 1.0 #else 1 #end", [LFloat], ["debug" => "1"]);
        check("#if debug 1.0 #elseif debug_ null #else 'string' #end", [LNull], ["debug_" => "1"]);
        check("#if debug 1.0 #elseif debug_ 1 #else 'string' #end", [LString]);
        check("#if (1 < 2) 'string' #else 1 #end", [LString]);
    }

    function testFails() {
        fails('#if');
        fails('#end');
        fails('#else');
        fails('#end');
        fails('#if #else');
        fails('#if #else #elseif');
        fails('#if #end #else');
    }
}