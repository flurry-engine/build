import Types.Project;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import Utils.hostPlatform;
import Utils.hostArchitecture;

using Safety;

class Build
{
    final project : Project;

    final user : Hxml;

    final snow : Hxml;

    final buildPath : String;

    final releasePath : String;

    public function new(_buildFile : String, _clean : Bool, _debug : Bool, _parcelTool : String)
    {
        // Parse the input file, create the hxml objects, and create our output paths.
        project     = tink.Json.parse(File.getContent(_buildFile));
        user        = new Hxml();
        snow        = new Hxml();
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

        FileSystem.createDirectory(buildPath);
        FileSystem.createDirectory(releasePath);

        var hxmlUser = File.write(Path.join([ buildPath, 'build.hxml' ]), false);
        var hxmlSnow = File.write(Path.join([ buildPath, 'snow.hxml' ]), false);

        hxmlUser.writeString(user.toString());
        hxmlSnow.writeString(snow.toString());

        hxmlUser.close();
        hxmlSnow.close();

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
            Sys.command('npx', [ 'lix', 'run', 'parcel', 'pack', '--input', parcel, '--output', parcelDirectory ]);
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
                user.noOptimisations();
                user.addDefine('annotate_source');
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

        // Add snow required libraries and user specified libraries.
        for (d in [
            'flurry-snow-host',
            'haxe-concurrent',
            'linc_directx',
            'linc_imgui',
            'sys.io.abstractions',
            'format',
            'safety',
            'signals',
            'json2object' ])
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
}