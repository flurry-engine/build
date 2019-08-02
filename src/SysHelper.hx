
import sys.FileSystem;
import hxp.System;

class SysHelper
{
    public function new()
    {
        //
    }
    
    public function getCwd() : String return Sys.getCwd();

    public function setCwd(_dir : String) Sys.setCwd(_dir);

    public function getEnv(_env : String) : String return Sys.getEnv(_env);

    public function getArgs() : Array<String> return Sys.args();

    public function runScript(_script : String, _buildArgs : Array<String>, _runArgs : Array<String>, _dir : String)
    {
        System.runScript(_script, _buildArgs, _runArgs, _dir);
    }

    public function fullPath(_relative : String) : String return FileSystem.fullPath(_relative);
}
