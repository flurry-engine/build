import tink.Cli;

class Main
{
    static function main()
    {
        // When the tool is ran from haxelib the CWD is the root directory of the haxelib.
		// Haxelib also appends the CWD where it was called from as a last argument and sets the 'HAXELIB_RUN' env.
		// So if we are running in haxelib mode set the CWD to the last cli argument.
		if (Sys.getEnv('HAXELIB_RUN') == '1')
		{
            final args = Sys.args();
			final cwd  = args.pop();

			if (cwd != null)
			{
				Sys.setCwd(cwd);
			}
		}

        Cli.process(Sys.args(), new Main()).handle(Cli.exit);
    }

    /**
     * Path to the json build file.
     * default : build.json
     */
    @:flag('file')
    @:alias('f')
    public var buildFile : String;

    /**
     * If set the project will not be re-built before being ran or packaged.
     * default : false
     */
    @:flag('no-build')
    @:alias('n')
    public var noBuild : Bool;

    /**
     * If set the build directory will be delected before building.
     * default : false
     */
    @:flag('clean')
    @:alias('c')
    public var clean : Bool;

    /**
     * If set this will build in debug mode regardless of the build files profile.
     * default : false
     */
    @:flag('debug')
    @:alias('d')
    public var debug : Bool;

    /**
     * The command to call when invoking the parcel builder.
     * default : npx lix run parcel
     */
    @:flag('parcel-tool')
    @:alias('p')
    public var parcelTool : String;

    /**
     * The command the parcel builder will run to call the GLSL shader compiler.
     * default : glslangValidator
     */
    @:flag('glsl-compiler')
    @:alias('g')
    public var glslCompiler : String;

    /**
     * The command the parcel builder will run to call the HLSL shader compiler (Windows only).
     * default : fxc
     */
    @:flag('hlsl-compiler')
    @:alias('h')
    public var hlslCompiled : String;

    public function new()
    {
        buildFile    = 'build.json';
        noBuild      = false;
        clean        = false;
        debug        = false;
        parcelTool   = 'npx lix run parcel';
        glslCompiler = 'glslangValidator';
        hlslCompiled = 'fxc';
    }

    @:defaultCommand public function help()
    {
        Sys.println(Cli.getDoc(this));
    }

    /**
     * //
     */
    @:command public function create()
    {
        new Create(buildFile);
    }

    /**
     * Compile the project and required assets.
     */
    @:command public function build()
    {
        new Restore(buildFile);
        new Build(buildFile, clean, debug, parcelTool);
    }

    /**
     * Run the project.
     */
    @:command public function run()
    {
        if (!noBuild)
        {
            new Restore(buildFile);
            new Build(buildFile, clean, debug, parcelTool);
        }

        new Run(buildFile);
    }

    /**
     * Package a for distribution.
     */
    @:command public function distribute()
    {
        if (!noBuild)
        {
            new Build(buildFile, clean, debug, parcelTool);
        }

        new Distribute();
    }

    /**
     * Download all the dependencies required to a project.
     */
    @:command public function restore()
    {
        new Restore(buildFile);
    }
}