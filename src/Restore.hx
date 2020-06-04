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
        FileSystem.createDirectory(tempPath);

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
        final tempZip    = Path.join([ tempPath, 'temp.zip' ]);
        final msdfTool   = Path.join([ toolsPath, executable ]);

        if (hostPlatform() == 'linux')
        {
            // For some reason haxe will not extract the linux atlas zip, so we use command line tools instead
            Sys.command('curl', [ '-L', '-o', tempZip, 'https://github.com/flurry-engine/msdf-atlas-gen/releases/download/CI/ubuntu-latest.zip' ]);
            Sys.command('tar', [ '-xvf', tempZip, '-C', toolsPath ]);
            Sys.command('rm', [ tempZip ]);
        }
        else
        {
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
                                            final input = new BytesInput(response.contentRaw);
    
                                            // There should only be one entry in the zip archive
                                            File.saveBytes(msdfTool, Reader.readZip(input).first().sure().data);
        
                                            input.close();   
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