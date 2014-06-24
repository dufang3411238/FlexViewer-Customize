package widgets.UserManager
{
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;

	public class SearchDataGridItem
	{
		private var _arrSource:Array;
		private var _wildcard:String;
		private var _expression:RegExp;
		
		public function get SourceArray():Array
		{
			return _arrSource;
		}
		
		public function get wildcard():String
		{
			return wildcard;	
		}
		
		public function SearchDataGridItem(arr:Array, searchStr:String = "")
		{
			_arrSource = arr;
			
			_wildcard = searchStr;
			
			_expression = createReEx(_wildcard);
		}
		
		public function search():int
		{
		
			
			for(var i:int = 0; i < SourceArray.length; i++)
			{
				if(test(SourceArray[i]))
				{
					return i;
					break;
				}
			}
			
			return -1;
		}
		
		
		
		private function test(testStr:String):Boolean
		{
			
			if(_expression && _expression.test(testStr))
			{
				return true;
			}
			
			return false;
		}
		private function createReEx(wildcard:String):RegExp
		{
			var resultStr:String;
			
			//excape metacharacters other than "*" and "?"
			resultStr = wildcard.replace(/[\^\$\\\.\+\(\)\[\]\{\}\|]/g, "\\$&");
			
			//replace wildcard "?" with reg exp equivalent "."
			resultStr = resultStr.replace(/[\?]/g, ".");
			
			//replace wildcard "*" with reg exp equivalen ".*?"
			resultStr = resultStr.replace(/[\*]/g, ".*?");
			
			return new RegExp(resultStr, "ig");
		}
	}
}