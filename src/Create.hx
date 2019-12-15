class Create
{
    public function new(_buildFile : String)
    {
        // Download a local npm version of lix
        Sys.command('npm install git+https://git@github.com/aidan63/lix.client.git --global');

        // Create a new scope
        Sys.command('npm lix scope create');
        Sys.command('npm lix download haxe 4.0.3');
        Sys.command('npm lix use haxe 4.0.3');

        // Install libraries
        Sys.command('npm lix install gh:flurry-engine/flurry#dev');
        Sys.command('npm lix install gh:flurry-engine/flurry-snow-host');
        Sys.command('npm lix install gh:flurry-engine/parcel');
        Sys.command('npm lix install gh:flurry-engine/build');

        // Create build file.
    }
}