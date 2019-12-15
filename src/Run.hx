import haxe.io.Path;
import Types.Project;
import Utils.hostPlatform;
import Utils.hostArchitecture;

using Safety;

class Run
{
    public function new(_buildFile : String)
    {
        final project : Project = tink.Json.parse(sys.io.File.getContent(_buildFile));
        final releasePath = Path.join([ project!.app!.output.or('bin'), '${hostPlatform()}-${hostArchitecture()}' ]);

        switch hostPlatform()
        {
            case 'windows':
                Sys.command(Path.join([ releasePath, '${project.app.name}.exe' ]), []);
            case 'osx', 'linux':
                Sys.command(Path.join([ releasePath, project.app.name ]), []);
        }
    }
}