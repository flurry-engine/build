import hxp.Haxelib;

class HaxelibHelper
{
    public function new()
    {
        //
    }
    
    public function getDirectory(_lib : String) : String return Haxelib.getPath(new Haxelib(_lib));
}
