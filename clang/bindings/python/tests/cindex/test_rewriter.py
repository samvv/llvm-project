import os
from clang.cindex import Config
if 'CLANG_LIBRARY_PATH' in os.environ:
    Config.set_library_path(os.environ['CLANG_LIBRARY_PATH'])

from clang.cindex import Rewriter
from clang.cindex import TranslationUnit
from clang.cindex import SourceLocation
from clang.cindex import SourceRange
import unittest
from .util import get_cursor

kInputsDir = os.path.join(os.path.dirname(__file__), 'INPUTS')

kNewMainBody = """\
{
    printf("dag wereld\\n");
    return 0;
}"""

kHelloFileRewritten = """\
// This is an auto-generated comment

#include "stdio.h"

int main(int argc, char* argv[]) {
    printf("dag wereld\\n");
    return 0;
}
"""

class TestRewrite(unittest.TestCase):
    def test_create(self):
        path = os.path.join(kInputsDir, 'hello.cpp')
        tu = TranslationUnit.from_source(path)
        rewiter = Rewriter.create(tu)

    def test_get_contents_no_rewrite(self):
        path = os.path.join(kInputsDir, 'hello.cpp')
        tu = TranslationUnit.from_source(path)
        rewriter = Rewriter.create(tu)
        with open(path, 'r') as f:
            text = f.read()
        self.assertEqual(rewriter.contents, text)

    def test_insert_remove(self):
        inputPath = os.path.join(kInputsDir, 'hello.cpp')
        outputPath = os.path.join(kInputsDir, 'hello_rewritten.cpp')
        tu = TranslationUnit.from_source(inputPath)
        rewriter = Rewriter.create(tu)
        rewriter.insertAfter(tu.cursor.extent.start, '// This is an auto-generated comment\n\n')
        main = get_cursor(tu, 'main')
        main_xs = list(main.get_children())
        rewriter.removeText(main_xs[2].extent)
        rewriter.insertAfter(main_xs[2].extent.start, kNewMainBody)
        self.assertEqual(rewriter.contents, kHelloFileRewritten)

