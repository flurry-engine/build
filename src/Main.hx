import tink.Cli;

class Main
{
    static function main()
    {
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

    @:defaultCommand
    public function help()
    {
        Sys.println(Cli.getDoc(this));
    }

    /**
     * //
     */
    @:command
    public function create()
    {
        new Create(buildFile);
    }

    /**
     * Compiles the project described by the json build file.
     */
    @:command
    public function build()
    {
        new Build(buildFile, clean, debug, parcelTool);
    }

    /**
     * Runs the project described by the json build file.
     */
    @:command
    public function run()
    {
        if (!noBuild)
        {
            new Build(buildFile, clean, debug, parcelTool);
        }

        new Run(buildFile);
    }

    /**
     * Packages the project described by the json build file for distribution.
     */
    @:command
    public function distribute()
    {
        if (!noBuild)
        {
            new Build(buildFile, clean, debug, parcelTool);
        }

        new Distribute();
    }
}