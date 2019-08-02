
import hxp.Path;
import hxp.Log;
import sys.io.abstractions.IFileSystem;
import sys.io.abstractions.concrete.FileSystem;

class Build
{
	static function main()
	{
		new Build(new FileSystem(), new SysHelper(), new HaxelibHelper());
	}

	final fileSystem : IFileSystem;

	final sys : SysHelper;

	final lib : HaxelibHelper;

	/**
	 * The command line arguments passed when this program was ran.
	 * The first argument will be cut off to identify which sub script to run.
	 */
	final arguments : Array<String>;

	public function new(_fileSystem : IFileSystem, _sys : SysHelper, _lib : HaxelibHelper)
	{
		fileSystem = _fileSystem;
		sys        = _sys;
		lib        = _lib;
		arguments  = sys.getArgs();

		// When the tool is ran from haxelib the CWD is the root directory of the haxelib.
		// Haxelib also appends the CWD where it was called from as a last argument and sets the 'HAXELIB_RUN' env.
		// So if we are running in haxelib mode set the CWD to the last cli argument.
		if (sys.getEnv('HAXELIB_RUN') == '1')
		{
			final cwd = arguments.pop();
			if (cwd != null)
			{
				sys.setCwd(cwd);
			}
		}

		switch arguments.shift()
		{
			case 'build':
				doBuildCommand('build');

			case 'run':
				doBuildCommand('run');

			case 'package':
				doBuildCommand('package');

			case 'clean':
				doBuildCommand('clean');

			case _:
				doHelpCommand();
		}
	}

	/**
	 * Run the build script with a command.
	 * @param _command The command for the build script to decide what to do.
	 */
	function doBuildCommand(_command : String)
	{
		final script = findBuildScript();
		if (script != '')
		{
			runHxpScript(script, _command);
		}
		else
		{
			Log.println('Cound not find a suitable script file to build');
		}
	}

	/**
	 * Prints help about the entire tool or a specific command.
	 */
	function doHelpCommand()
	{
		final script  = Path.join([ lib.getDirectory('build'), 'scripts', 'Help.hx' ]);
		final command = arguments.length == 0 ? 'default' : arguments.shift();

		if (command != null)
		{
			runHxpScript(script, command);
		}
	}

	/**
	 * Run a .hxp script with the correct flurry classes imported.
	 * @param _script Script file to run.
	 * @param _command Optional command for the script.
	 */
	function runHxpScript(_script : String, _command : String)
	{	
		final dir  = Path.directory(_script);
		final file = Path.withoutDirectory(_script);

		var className = Path.withoutExtension(file);
		className = className.substr(0, 1).toUpperCase() + className.substr(1);
		
		final version   = '1.1.2';
		final buildArgs = [
			className,
			'-D', 'hxp=$version',
			'-cp', Path.combine(lib.getDirectory('hxp'), 'src'),
			'-cp', Path.combine(lib.getDirectory('build'), 'scripts') ];
		final runArgs = [ 'hxp.Script', (_command == null || _command == '') ? 'default' : _command ].concat(arguments);
		
		runArgs.push(className);
		runArgs.push(sys.getCwd());
		
		sys.runScript(_script, buildArgs, runArgs, dir);
	}

	/**
	 * will look for a build script in the following order.
	 * - If there is a file which matches the first argument, use that.
	 * - If there is a file called build.hxp, use that.
	 * - If there is a file called build.hx, use that.
	 * - If none of the above are found, error out.
	 * @return Script file name or empty string.
	 */
	function findBuildScript() : String
	{
		if (arguments.length > 0)
		{
			if (fileSystem.file.exists(arguments[0]))
			{
				return sys.fullPath(arguments.shift());
			}
			else
			{
				Log.println('Build script "${arguments[0]}" does not exist');

				return '';
			}
		}

		if (fileSystem.file.exists('Build.hxp'))
		{
			return sys.fullPath('Build.hxp');
		}

		if (fileSystem.file.exists('build.hxp'))
		{
			return sys.fullPath('build.hxp');
		}

		if (fileSystem.file.exists('Build.hx'))
		{
			return sys.fullPath('Build.hx');
		}

		if (fileSystem.file.exists('build.hx'))
		{
			return sys.fullPath('build.hx');
		}

		return '';
	}
}
