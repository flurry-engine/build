
import hxp.Script;
import hxp.Log;

/**
 * Script which prints help info for the build command options.
 */
class Help extends Script
{
    public function new()
    {
        super();

        switch (command)
        {
            case 'build':
                printBuildHelp();

            case 'run':
                printRunHelp();

            case 'package':
                printPackageHelp();

            case _:
                printHelp();
        }
    }

    function printBuildHelp()
    {
        //
    }

    function printRunHelp()
    {
        //
    }

    function printPackageHelp()
    {
        //
    }

    function printHelp()
    {
        Log.println('Flurry 0.0.1');
        Log.println('');
        Log.println('Commands');
        Log.println('    build   - Build a flurry project.');
        Log.println('    run     - Build and run a flurry project.');
        Log.println('    package - Build and package a flurry project for distribution');
        Log.println('    help    - Display detailed information on a command and all its options.');
    }
}
