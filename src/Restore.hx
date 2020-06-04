import Types;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.io.BytesInput;
import haxe.zip.Reader;
import com.akifox.asynchttp.HttpRequest;
import Utils.msdfPlatform;
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
        FileSystem.createDirectory(tempPath);

        final executable = msdfAtlasExecutable();
        final tempZip    = Path.join([ tempPath, 'temp.zip' ]);
        final msdfTool   = Path.join([ toolsPath, executable ]);
        final url        = switch Sys.systemName()
        {
            case 'Windows' : 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/windows-latest.zip';
            case 'Mac'     : 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/macOS-latest.zip';
            case 'Linux'   : 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/ubuntu-latest.zip';
            case unknown   : throw '$unknown not supported';
        }

        if (!FileSystem.exists(msdfTool))
        {
            Sys.command('curl', [ '-L', '-o', tempZip, url ]);
            Sys.command('tar', [ '-xvf', tempZip, '-C', toolsPath ]);
    
            FileSystem.deleteFile(tempZip);
            FileSystem.deleteDirectory(tempPath);
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
                url           : 'https://libgdx.badlogicgames.com/nightlies/runnables/runnable-texturepacker.jar',
                async         : false,
                callback      : response -> File.saveBytes(atlasTool, response.contentRaw),
                callbackError : response -> trace('Unable to get latest libgdx texture packer jar ${ response.error }')
            }).send();
        }
    }
}