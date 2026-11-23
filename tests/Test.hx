package tests;

import utest.Runner;
import utest.ui.Report;
import tests.classes.*;

class Test {
	public static function main() {
		final r = new Runner();
		r.addCase(new LexerTest());
		r.addCase(new PreprocessorTest());
		r.addCase(new VMTest());
		Report.create(r);
		r.run();
	}
}
