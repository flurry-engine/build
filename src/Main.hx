import tink.Cli;

class Main
{
    static function main()
    {
        Cli.process(Sys.args(), new Build()).handle(Cli.exit);
    }
}
