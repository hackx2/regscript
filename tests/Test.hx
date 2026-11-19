package tests;

import utest.Runner;
import utest.ui.Report;
import tests.classes.*;

class Test {
	public static function main() {
		final r = new Runner();
		r.addCase(new LexerTest());
		r.addCase(new PreprocessorTest());
		Report.create(r);
		r.run();
	}
}
