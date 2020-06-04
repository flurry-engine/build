import Types;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.io.BytesInput;
import format.tgz.Reader;
import com.akifox.asynchttp.HttpRequest;
import Utils.hostPlatform;
import Utils.msdfAtlasExecutable;

using Safety;
using StringTools;

class Restore
{
    final buildFile : String;

    final toolsPath : String;

    final tempPath : String;

    final project : Project;

    public function new(_buildFile : String)
    {
        buildFile = _buildFile;
        project   = tink.Json.parse(File.getContent(buildFile));
        toolsPath = Path.join([ project!.app!.output.or('bin'), 'tools', hostPlatform() ]);
        tempPath  = Path.join([ project!.app!.output.or('bin'), 'temp' ]);

        FileSystem.createDirectory(toolsPath);

        Sys.command('npx', [ 'lix', 'download' ]);

        downloadMdsfAtlasGen();
        downloadLbgdxTexturePackerJar();
    }

    /**
     * Download the msdf-atlas-gen binary for this OS.
     */
    function downloadMdsfAtlasGen()
    {
        final executable = msdfAtlasExecutable();
        final msdfTool   = Path.join([ toolsPath, executable ]);
        final url        = switch Sys.systemName()
        {
            case 'Windows' : 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/windows-latest.tar.gz';
            case 'Mac'     : 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/macOS-latest.tar.gz';
            case 'Linux'   : 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/ubuntu-latest.tar.gz';
            case unknown   : throw '$unknown not supported';
        }

        if (!FileSystem.exists(msdfTool))
        {
            new HttpRequest({
                async         : false,
                url           : url,
                callback      : success -> {
                    final input = new BytesInput(success.contentRaw);
                    final entry = new Reader(input).read().first();

                    File.saveBytes(msdfTool, entry.data);

                    input.close();
                },
                callbackError : error -> {
                    Sys.println('Unable to download msdf-atlas-gen : ${ error.error }');
                    Sys.exit(1);
                }
            }).send();
        }
    }

    /**
     * Download the standalone libgdx texture packer jar into the tools directory.
     */
    function downloadLbgdxTexturePackerJar()
    {
        final atlasTool = Path.join([ toolsPath, 'runnable-texturepacker.jar' ]);

        if (!FileSystem.exists(atlasTool))
        {
            new HttpRequest({
                async         : false,
                url           : 'https://libgdx.badlogicgames.com/nightlies/runnables/runnable-texturepacker.jar',
                callback      : success -> File.saveBytes(atlasTool, success.contentRaw),
                callbackError : error -> {
                    Sys.println('Unable to download libgdx texture packer : ${ error.error }');
                    Sys.exit(1);
                }
            }).send();
        }
    }
}