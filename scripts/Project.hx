
import sys.io.File;
import sys.FileSystem;
import hxp.System;
import hxp.Path;
import hxp.Version;
import hxp.Script;
import hxp.HXML;
import hxp.Log;

class Project extends Script
{
    /**
     * The output project type.
     */
    var backend : BuildBackend;

    /**
     * Meta data holds information about the overall project.
     */
    final meta : ProjectMeta;

    /**
     * The app class controls build configurations specific to the binary/app output of a project.
     */
    final app : ProjectApp;

    /**
     * The build class controls build specific configurations and files.
     */
    final build : ProjectBuild;

    /**
     * List of directories relative to the build file and how they will be copied into the output directory relative to the binary.
     */
    var files : Map<String, String>;

    /**
     * List of all parcel definitions which will be generated during building.
     */
    var parcels : Array<String>;

    public final function new()
    {
        super();

        backend = Snow;
        meta    = new ProjectMeta();
        app     = new ProjectApp();
        build   = new ProjectBuild();
        files   = [];
        parcels = [];

        setup();

        var pathBuild   = Path.combine(app.output, '${System.hostPlatform}-${System.hostArchitecture.getName().toLowerCase()}.build');
        var pathRelease = Path.combine(app.output, '${System.hostPlatform}-${System.hostArchitecture.getName().toLowerCase()}');

        switch (command)
        {
            case 'build':
                compile(pathBuild, pathRelease);

            case 'run':
                compile(pathBuild, pathRelease);
                run(pathRelease);

            case 'package':
                compile(pathBuild, pathRelease);
                distribute(pathRelease);

            case 'clean':
                System.removeDirectory(app.output);

            case _:
                Log.error('unknown command ${command}');
        }
    }

    /**
     * Overridable function, users should configure their project build in this function.
     */
    function setup()
    {
        //
    }

    final function compile(_pathBuild : String, _pathRelease : String)
    {
        switch (backend)
        {
            case Snow:
                compileSnow(_pathBuild, _pathRelease);
            case _unsupported:
                Log.error('$_unsupported backend is not yet implemented');
        }
    }

    final function compileSnow(_pathBuild : String, _pathRelease : String)
    {
        var user = new HXML();
        var snow = new HXML();

        FileSystem.createDirectory(_pathBuild);
        FileSystem.createDirectory(_pathRelease);

        // General snow settings
        user.main = 'snow.App';
        user.cpp  = Path.combine(_pathBuild, 'cpp');

        switch (build.profile)
        {
            case Debug:
                user.debug = true;
                user.noOpt = true;
                user.dce   = NO;
                build.defines.set('annotate_source', null);
            case Release:
                user.dce = FULL;
                user.noTraces = true;
        }

        if (build.noInline)
        {
            user.noInline = true;
        }

        // Add snow required defines, user specified defines, and a define for each libraries name.
        build.defines.set(System.hostPlatform  , null);
        build.defines.set('target-cpp'         , null);
        build.defines.set('desktop'            , null);
        build.defines.set('snow_native'        , null);
        build.defines.set('HXCPP_M64'          , null);
        build.defines.set('flurry-entry-point' , app.main);

        // Add snow required libraries and user specified libraries.
        build.dependencies.set('flurry-snow-host'   , null);
        build.dependencies.set('haxe-concurrent'    , null);
        build.dependencies.set('linc_directx'       , null);
        build.dependencies.set('linc_imgui'         , null);
        build.dependencies.set('sys.io.abstractions', null);
        build.dependencies.set('format'             , null);
        build.dependencies.set('safety'             , null);
        build.dependencies.set('signals'            , null);
        build.dependencies.set('json2object'        , null);

        // Add snow required macros and user specified macros.

        commonCopy(user);

        snow.addMacro('snow.Set.main("uk.aidanlee.flurry.snow.host.FlurrySnowHost")');
        snow.addMacro('snow.Set.ident("${app.namespace}")');
        snow.addMacro('snow.Set.config("config.json")');
        snow.addMacro('snow.Set.runtime("${ snowGetRuntimeString() }")');
        snow.addMacro('snow.Set.assets("snow.core.native.assets.Assets")');
        snow.addMacro('snow.Set.audio("snow.core.Audio")');
        snow.addMacro('snow.Set.io("snow.modules.sdl.IO")');
        snow.addMacro('snow.api.Debug.level(${ build.snow.log })');

        // Write the two snow build hxmls and build them.
        var hxmlUser = File.write(Path.combine(_pathBuild, 'build.hxml'), false);
        var hxmlSnow = File.write(Path.combine(_pathBuild, 'snow.hxml'), false);

        hxmlUser.writeString(user);
        hxmlUser.writeString('\n');
        hxmlUser.writeString(Path.combine(_pathBuild, 'snow.hxml'));

        hxmlSnow.writeString(snow);

        hxmlUser.close();
        hxmlSnow.close();

        // Build the project
        var result = System.runCommand(workingDirectory, 'npx', [ 'haxe', Path.combine(_pathBuild, 'build.hxml')]);
        if (result != 0)
        {
            Sys.exit(result);
        }

        // Copy files over
        for (src => dst in files)
        {
            System.recursiveCopy(src, Path.combine(_pathRelease, dst));
        }

        // Build all required parcels.
        var parcelDirectory = Path.join([ _pathRelease, 'assets', 'parcels' ]);
        if (!FileSystem.exists(parcelDirectory))
        {
            System.makeDirectory(parcelDirectory);
        }
        for (parcel in parcels)
        {
            System.runCommand('', 'npx', [ 'lix', 'run', 'parcel', 'pack', '--input', parcel, '--output', parcelDirectory ]);
        }

        // Rename the output executable and copy it over to the .build directory.
        // Platform specific since file extensions change.
        // If the script is called with the 'run' command i.e. `hxp .. build.hxp run` then the binary should be launched after building.
        switch System.hostPlatform
        {
            case WINDOWS:
                var src = Path.join([ _pathBuild, 'cpp', build.profile == Debug ? 'App-debug.exe' : 'App.exe' ]);
                var dst = Path.combine(_pathRelease, '${app.name}.exe');

                System.copyFile(src, dst);
            case MAC, LINUX:
                var src = Path.join([ _pathBuild, 'cpp', build.profile == Debug ? 'App-debug' : 'App' ]);
                var dst = Path.combine(_pathRelease, app.name);

                System.copyFile(src, dst);
                System.runCommand(workingDirectory, 'chmod', [ 'a+x', dst ]);
        }
    }

    final function commonCopy(_hxml : HXML)
    {
        for (p in app.codepaths)
        {           
            _hxml.cp(p);
        }

        for (d => v in build.defines)
        {
            _hxml.define(d, v);
        }

        for (m in build.macros)
        {
            _hxml.addMacro(m);
        }

        for (l => v in build.dependencies)
        {
            _hxml.lib(l, v);
            _hxml.define(l);
        }
    }

    final function snowGetRuntimeString() : String return switch build.snow.runtime
    {
        case Desktop: 'uk.aidanlee.flurry.snow.runtime.FlurrySnowDesktopRuntime';
        case Cli    : 'uk.aidanlee.flurry.snow.runtime.FlurrySnowCLIRuntime';
        case Custom(_package): _package;
    }

    final function run(_pathRelease : String) switch System.hostPlatform
    {
        case WINDOWS:
            System.runCommand(Path.combine(workingDirectory, _pathRelease), '${app.name}.exe', []);
        case MAC, LINUX:
            System.runCommand(workingDirectory, Path.combine(_pathRelease, app.name), []);
    }
    
    final function distribute(_pathRelease : String)
    {
        System.compress(_pathRelease, Path.combine(app.output, '${app.name}-${System.hostPlatform}${System.hostArchitecture.getName()}.zip'));
    }
}
