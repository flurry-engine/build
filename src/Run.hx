import haxe.io.Path;
import Types.Project;
import sys.FileSystem;
import Utils.hostPlatform;
import Utils.hostArchitecture;

using Safety;

class Run
{
    public function new(_buildFile : String)
    {
        final project : Project = tink.Json.parse(sys.io.File.getContent(_buildFile));
        final buildPath   = Path.join([ project!.app!.output.or('bin'), '${hostPlatform()}-${hostArchitecture()}.build' ]);
        final releasePath = Path.join([ project!.app!.output.or('bin'), '${hostPlatform()}-${hostArchitecture()}' ]);
    }
}