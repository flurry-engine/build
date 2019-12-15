import sys.io.Process;

class Utils
{
    public static function hostPlatform() return switch Sys.systemName()
    {
        case 'Windows' : 'windows';
        case 'Mac'     : 'osx';
        case 'Linux'   : 'linux';
        case _         : 'other';
    }

    public static function hostArchitecture() return switch Sys.systemName()
    {
        case 'Windows' : {
            var architecture      = Sys.getEnv('PROCESSOR_ARCHITECTURE');
            var wow64Architecture = Sys.getEnv('PROCESSOR_ARCHITEW6432');

            if (architecture.indexOf('64') > -1 || wow64Architecture != null && wow64Architecture.indexOf('64') > -1)
            {
                'x64';
            }
            else
            {
                'x86';
            }
        }
        case 'Mac', 'Linux' : {
            var process = new Process("uname", ["-m"]);
            var output  = process.stdout.readAll().toString();
            process.exitCode();
            process.close();

            if (output.indexOf("armv6") > -1)
            {
                'armv6';
            }
            else if (output.indexOf("armv7") > -1)
            {
                'armv7';
            }
            else if (output.indexOf("64") > -1)
            {
                'x64';
            }
            else
            {
                'x86';
            }
        }
        case _ : 'other';
    }
}