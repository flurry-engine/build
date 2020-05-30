import Types.Project;
import haxe.zip.Reader;
import haxe.io.BytesInput;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import com.akifox.asynchttp.HttpRequest;
import Utils.hostPlatform;
import Utils.hostArchitecture;
import Utils.atlasToolExecutable;

using Safety;
using StringTools;

class Build
{
    final project : Project;

    final user : Hxml;

    final snow : Hxml;

    final toolsPath : String;

    final buildPath : String;

    final releasePath : String;

    public function new(_buildFile : String, _clean : Bool, _debug : Bool, _parcelTool : String)
    {
        // Parse the input file, create the hxml objects, and create our output paths.
        project     = tink.Json.parse(File.getContent(_buildFile));
        user        = new Hxml();
        snow        = new Hxml();
        toolsPath   = Path.join([ project!.app!.output.or('bin'), 'tools', hostPlatform() ]);
        buildPath   = Path.join([ project!.app!.output.or('bin'), '${hostPlatform()}-${hostArchitecture()}.build' ]);
        releasePath = Path.join([ project!.app!.output.or('bin'), '${hostPlatform()}-${hostArchitecture()}' ]);

        // Clean the output directories.
        if (_clean)
        {
            clean(buildPath);
            clean(releasePath);
        }

        // create the game and snow hxml file.
        writeUserHxml(_debug);
        writeSnowHxml();

        FileSystem.createDirectory(toolsPath);
        FileSystem.createDirectory(buildPath);
        FileSystem.createDirectory(releasePath);

        var hxmlUser = File.write(Path.join([ buildPath, 'build.hxml' ]), false);
        var hxmlSnow = File.write(Path.join([ buildPath, 'snow.hxml' ]), false);

        hxmlUser.writeString(user.toString());
        hxmlSnow.writeString(snow.toString());

        hxmlUser.close();
        hxmlSnow.close();

        // Ensure we have all our build tools before starting compilation

        downloadMdsfAtlasGen();
        downloadLbgdxTexturePackerJar();

        // Call haxe to build the project.
        final result = Sys.command('npx', [ 'haxe', Path.join([ buildPath, 'build.hxml' ]) ]);
        if (result != 0)
        {
            Sys.exit(result);
        }

        // Call the parcel tool to create any parcels
        final parcelDirectory = Path.join([ releasePath, 'assets', 'parcels' ]);
        if (!FileSystem.exists(parcelDirectory))
        {
            FileSystem.createDirectory(parcelDirectory);
        }

        for (parcel in project!.parcels.or([]))
        {
            Sys.command([
                _parcelTool, 'pack',
                '--input', '"$parcel"',
                '--output', '"$parcelDirectory"',
                '--msdf-atlas-gen', '"${ Path.join([ toolsPath, atlasToolExecutable() ]) }"',
                '--gdx-jar', '"${ Path.join([ toolsPath, 'runnable-texturepacker.jar' ]) }"' ].join(' '));
        }

        // Rename the output executable and copy it over to the .build directory.
        // Platform specific since file extensions change.
        switch hostPlatform()
        {
            case 'windows':
                var src = Path.join([ buildPath, 'cpp', project!.build!.profile.or(Debug) == Debug ? 'App-debug.exe' : 'App.exe' ]);
                var dst = Path.join([ releasePath, '${project.app.name}.exe' ]);

                File.copy(src, dst);
            case 'osx', 'linux':
                var src = Path.join([ buildPath, 'cpp', project!.build!.profile.or(Debug) == Debug ? 'App-debug' : 'App' ]);
                var dst = Path.join([ releasePath, project.app.name ]);

                File.copy(src, dst);
                Sys.command('chmod', [ 'a+x', dst ]);
        }
    }

    function writeUserHxml(_debug : Bool)
    {
        user.main = 'snow.App';
        user.cpp  = Path.join([ buildPath, 'cpp' ]);

        switch (project!.build!.profile.or(Debug))
        {
            case Debug:
                user.dce = no;
                user.debug();
            case Release:
                user.dce = full;
                user.noTraces();
                if (_debug)
                {
                    user.debug();
                }
        }

        // Add snow required defines, user specified defines, and a define for each libraries name.
        user.addDefine(hostPlatform());
        user.addDefine('target-cpp');
        user.addDefine('desktop');
        user.addDefine('snow_native');
        user.addDefine('HXCPP_M64');
        user.addDefine('flurry-entry-point' , project!.app!.main.or(''));
        user.addMacro('Safety.safeNavigation("uk.aidanlee.flurry")');

        // Add snow required libraries and user specified libraries.
        for (d in [
            'flurry-snow-host',
            'haxe-concurrent',
            'linc_directx',
            'linc_imgui',
            'sys.io.abstractions',
            'format',
            'safety',
            'hxbit',
            'RxHaxe' ])
        {
            user.addLibrary(d);
            user.addDefine(d);
        }

        for (p in project!.app!.codepaths.or([]))
        {           
            user.addClassPath(p);
        }

        for (d in project!.build!.defines.or([]))
        {
            user.addDefine(d.def, d.value);
        }

        for (m in project!.build!.macros.or([]))
        {
            user.addMacro(m);
        }

        for (d in project!.build!.dependencies.or([]))
        {
            user.addLibrary(d.lib, d.version);
            user.addDefine(d.lib);
        }

        user.addHxml(Path.join([ buildPath, 'snow.hxml' ]));
    }

    function writeSnowHxml()
    {
        final namespace = project!.app!.namespace.or('empty-project');
        final snowLog   = project!.build!.snow!.log.or(1);

        snow.addMacro('snow.Set.main("uk.aidanlee.flurry.snow.host.FlurrySnowHost")');
        snow.addMacro('snow.Set.ident("$namespace")');
        snow.addMacro('snow.Set.config("config.json")');
        snow.addMacro('snow.Set.runtime("${ snowGetRuntimeString() }")');
        snow.addMacro('snow.Set.assets("snow.core.native.assets.Assets")');
        snow.addMacro('snow.Set.audio("snow.core.Audio")');
        snow.addMacro('snow.Set.io("snow.modules.sdl.IO")');
        snow.addMacro('snow.api.Debug.level($snowLog)');
    }

    function snowGetRuntimeString() : String return switch project!.build!.snow!.runtime.or(Desktop)
    {
        case Desktop: 'uk.aidanlee.flurry.snow.runtime.FlurrySnowDesktopRuntime';
        case Cli    : 'uk.aidanlee.flurry.snow.runtime.FlurrySnowCLIRuntime';
        case Custom(_package): _package;
    }

    function clean(_path : String)
    {
        for (file in FileSystem.readDirectory(_path))
        {
            final item = Path.join([ _path, file ]);
            if (FileSystem.isDirectory(item))
            {
                clean(item);

                FileSystem.deleteDirectory(item);
            }
            else
            {
                FileSystem.deleteFile(item);
            }
        }
    }

    /**
     * Download the msdf-atlas-gen binary for this OS.
     */
    function downloadMdsfAtlasGen()
    {
        final msdfTool = Path.join([ toolsPath, atlasToolExecutable() ]);

        if (!FileSystem.exists(msdfTool))
        {
            new HttpRequest({
                url      : 'https://api.github.com/repos/flurry-engine/msdf-atlas-gen/releases/latest',
                async    : false,
                callback : response -> {
                    for (asset in (haxe.Json.parse(response.content).assets : Array<Dynamic>))
                    {
                        if ((asset.name : String).contains(hostPlatform()))
                        {
                            new HttpRequest({
                                url           : asset.browser_download_url,
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
