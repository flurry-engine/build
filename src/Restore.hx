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

    final project : Project;

    public function new(_buildFile : String)
    {
        buildFile = _buildFile;
        project   = tink.Json.parse(File.getContent(buildFile));
        toolsPath = Path.join([ project!.app!.output.or('bin'), 'tools', hostPlatform() ]);

        FileSystem.createDirectory(toolsPath);

        Sys.command('npx', [ 'lix', 'download' ]);

        downloadMdsfAtlasGen(toolsPath);
        downloadLbgdxTexturePackerJar(toolsPath);
    }

    /**
     * Download the msdf-atlas-gen binary for this OS.
     */
    function downloadMdsfAtlasGen(_toolsPath : String)
    {
        final msdfTool = Path.join([ _toolsPath, msdfAtlasExecutable() ]);

        if (!FileSystem.exists(msdfTool))
        {
            new HttpRequest({
                url      : 'https://api.github.com/repos/flurry-engine/msdf-atlas-gen/releases/latest',
                async    : false,
                callback : response -> {
                    for (asset in (haxe.Json.parse(response.content).assets : Array<Dynamic>))
                    {
                        if ((asset.name : String).contains(msdfPlatform()))
                        {
                            new HttpRequest({
                                url           : asset.browser_download_url,
                                async         : false,
                                callback      : response -> {
                                    if (response.isBinary)
                                    {
                                        final input = new BytesInput(response.contentRaw);

                                        // There should only be one entry in the zip archive
                                        File.saveBytes(msdfTool, Reader.readZip(input).first().sure().data);
    
                                        input.close();   
                                    }
                                    else
                                    {
                                        throw 'data is not binary';
                                    }
                                },
                                callbackError : response -> trace('Error downloading msdf-atlas-gen binary ${ response.error }')
                            }).send();

                            break;
                        }
                    }
                },
                callbackError : response -> trace('Unable to get latest msdf-atlas-gen release from github ${ response.error }')
            }).send();
        }
    }

    /**
     * Download the standalone libgdx texture packer jar into the tools directory.
     */
    function downloadLbgdxTexturePackerJar(_toolsPath : String)
    {
        final atlasTool = Path.join([ _toolsPath, 'runnable-texturepacker.jar' ]);

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