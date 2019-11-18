
import sys.io.abstractions.mock.MockFileData;
import sys.io.abstractions.mock.MockFileSystem;
import SysHelper;
import HaxelibHelper;
import mockatoo.Mockatoo.*;

using mockatoo.Mockatoo;

class Tests extends buddy.SingleSuite
{
    public function new()
    {
        describe('launching commands', {
            it('will launch the help command if no arguments are provided', {
                var mockSys = mock(SysHelper);
                mockSys.getArgs().returns([]);
                mockSys.getEnv('HAXELIB_RUN').returns('0');

                new Build(new MockFileSystem(), mockSys, mock(HaxelibHelper));

                mockSys.runScript('scripts/Help.hx', cast any, cast any, cast any).verify(times(1));
            });

            it('will launch the help command if an invalid command is passed', {
                var mockSys = mock(SysHelper);
                mockSys.getArgs().returns([ 'command' ]);
                mockSys.getEnv('HAXELIB_RUN').returns('0');

                new Build(new MockFileSystem(), mockSys, mock(HaxelibHelper));

                mockSys.runScript('scripts/Help.hx', cast any, cast any, cast any).verify(times(1));
            });
        });
    }
}
