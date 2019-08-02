
import sys.io.abstractions.mock.MockFileSystem;
import SysHelper;
import HaxelibHelper;
import mockatoo.Mockatoo.mock;

using mockatoo.Mockatoo;

class Tests extends buddy.SingleSuite
{
    public function new()
    {
        describe('launching commands', {
            var mockSys = mock(SysHelper);
            mockSys.getArgs().returns([ 'Build.hxp', '/some/dir' ]);
            mockSys.getEnv('HAXELIB_CLI').returns('1');
            var mockHaxelib = mock(HaxelibHelper);
            var build = new Build(new MockFileSystem([], []), mock(SysHelper), mock(HaxelibHelper));
        });
    }
}
