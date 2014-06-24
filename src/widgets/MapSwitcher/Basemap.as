package widgets.MapSwitcher
{

public class Basemap
{
    public var id:String;
    public var thumbnail:String;
    public var label:String;
    public var visible:Boolean;
	private var _labelId:String;

    public function Basemap(id:String, label:String, thumbnail:String = null, visible:Boolean = false)
    {
        this.id = id;
        this.label = label;
        this.thumbnail = thumbnail;
        this.visible = visible;
    }
	
	public function set labelId(labelId:String):void
	{
		this._labelId = labelId;		
	}
	
	public function get labelId():String
	{
		return this._labelId;
	}
}
}
