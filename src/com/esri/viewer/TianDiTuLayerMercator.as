/*
* 根据输入的地图类型加载天地图(by chenyuming)
* 注意：投影类型为球形墨卡托
*/

package com.esri.viewer
{
	import com.esri.ags.SpatialReference;
	import com.esri.ags.geometry.Extent;
	import com.esri.ags.geometry.MapPoint;
	import com.esri.ags.layers.ArcGISDynamicMapServiceLayer;
	import com.esri.ags.layers.TiledMapServiceLayer;
	import com.esri.ags.layers.supportClasses.LOD;
	import com.esri.ags.layers.supportClasses.TileInfo;
	
	import flash.net.URLRequest;
	import flash.sampler.Sample;
	
	public class TianDiTuLayerMercator extends TiledMapServiceLayer
	{
		private var _tileInfo:TileInfo;       
		private var _baseURL:String;  
		private var _baseURLs:Array;  
		private var _initExtent:String; 
		private var _layerId:String;  
		private var _mapStyle:String="";
		
		public function TianDiTuLayerMercator(mapStyle:String)
		{
			this._mapStyle=mapStyle;//设置地图类型
			
			super();        
			this._tileInfo = new TileInfo();  
			this._initExtent = null;  
			this.buildTileInfo();  
			setLoaded(true);  
		}  
		
		override public function get fullExtent() : Extent  
		{  
			return new Extent(12417524.30797337,2702979.91199371, 12435698.54465215,2711332.28680540, new SpatialReference(3857));
			//return new Extent(-20037508.3427892,-20037508.3427892, 20037508.3427892,20037508.3427892, new SpatialReference(3857));  
		}  
		
		public function set initExtent(initextent:String):void  
		{  
			this._initExtent = initextent;  
		} 
		
		override public function get initialExtent() :Extent  
		{  
			if (this._initExtent == null)  
				return new Extent(8397502.3, 2660018.1, 15003861.0, 5509344.0, new SpatialReference(3857));      
			var coors:Array = this._initExtent.split(",");  
			return new Extent(Number(coors[0]), Number(coors[1]), Number(coors[2]) ,Number(coors[3]), new SpatialReference(3857));  
		}  
		
		override public function get spatialReference() : SpatialReference  
		{  
			return new SpatialReference(3857);   
		}  
		
		override public function get tileInfo() : TileInfo  
		{  
			return this._tileInfo;  
		}  
		
		//根据不同地图类型加载不同WMTS服务
		override protected function getTileURL(level:Number, row:Number, col:Number) : URLRequest  
		{
			_baseURL = "http://t0.tianditu.com";
			
			if(this._mapStyle == "ImageBaseMap")//获取影像地图（底图）
			{
				_layerId = "img_w";
			}
			else if(this._mapStyle == "ImageCNNote")//获取影像地图（中文注记）
			{
				_layerId = "cia_w";
			}
			else if(this._mapStyle == "ImageENNote")//获取影像地图（英文注记）
			{
				_layerId = "eia_w";
			}
			else if(this._mapStyle == "TerrainBaseMap")//获取地形图（底图）
			{
				_layerId = "ter_w";
			}
			else if(this._mapStyle == "TerrainCNNote")//获取地形图（中文注记）
			{
				_layerId = "cta_w";
			}
			else if(this._mapStyle == "TerrainENNote")//获取地形图（英文注记）
			{
				//暂无
			}
			else if(this._mapStyle == "VectorBaseMap")//获取矢量图（底图）
			{
				_layerId = "vec_w";
			}
			else if(this._mapStyle == "VectorCNNote")//获取矢量图（中文注记）
			{
				_layerId = "cva_w";
			}
			else if(this._mapStyle == "VectorENNote")//获取矢量图（英文注记）
			{
				_layerId = "eva_w";
			}
			
			var serNum:int = Math.round(Math.random() * 6) + 1;
			
			var urlRequest:String =_baseURL.replace("0",String(serNum))+"/DataServer?T="+_layerId+"&x="+col+"&y="+row+"&l="+level; 
			
			return new URLRequest(urlRequest);    
		}  
		
		//切片信息
		private function buildTileInfo() : void  
		{  
			this._tileInfo.height = 256;  
			this._tileInfo.width = 256;  
			this._tileInfo.origin = new MapPoint(-20037508.3427892,20037508.3427892,new SpatialReference(3857));  
			this._tileInfo.spatialReference = new SpatialReference(3857);  
			this._tileInfo.lods = new Array();
			this._tileInfo.lods = [  
				new LOD(1 ,77664.761018562790697674418604651, 2.958293554545656E8),                                   
				new LOD(2 ,38832.380509281395348837209302326, 1.479146777272828E8),   
				new LOD(3 ,19416.190254640697674418604651163, 7.39573388636414E7),    
				new LOD(4 ,9708.0951273203488372093023255814, 3.69786694318207E7),    
				new LOD(5 ,4854.0475636601744186046511627907, 1.848933471591035E7),   
				new LOD(6 ,2427.0237818300872093023255813953, 9244667.357955175),     
				new LOD(7 ,1213.5118909150436046511627906977, 4622333.678977588),     
				new LOD(8 ,606.75594545752180232558139534884, 2311166.839488794),     
				new LOD(9 ,303.37797272876090116279069767442, 1155583.419744397),     
				new LOD(10,151.68898636438045058139534883721, 577791.7098721985),     
				new LOD(11, 75.844493182190225290697674418605, 288895.85493609926),   
				new LOD(12, 37.922246591095112645348837209302, 144447.92746804963),   
				new LOD(13, 18.961123295547556322674418604651, 72223.96373402482),    
				new LOD(14, 9.4805616477737781613372093023256, 36111.98186701241),    
				new LOD(15, 4.7402808238868890806686046511628, 18055.990933506204),   
				new LOD(16, 2.3701404119434445403343023255814, 9027.995466753102),    
				new LOD(17, 1.1850702059717222701671511627907, 4513.997733376551),    
				new LOD(18, 0.59253510298586113508357558139535, 2256.998866688275)    
			];  
		}  
	}  
}