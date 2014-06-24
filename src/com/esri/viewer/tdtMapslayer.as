/*
* 根据输入的地图类型加载天地图(by chenyuming)
* 注意：投影类型为经纬度
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
	
	public class tdtMapslayer extends TiledMapServiceLayer
	{
		private var _tileInfo:TileInfo;       
		private var _baseURL:String;  
		private var _baseURLs:Array;  
		private var _initExtent:String;  
		private var _serviceMode:String;  
		private var _imageFormat:String;  
		private var _layerId:String;  
		private var _tileMatrixSetId:String; 
		private var _mapStyle:String="";
		
		public function tdtMapslayer(mapStyle:String,serviceMode:String = "KVP",imageFormat:String = "tiles")
		{
			this._mapStyle=mapStyle;//设置地图类型
			this._serviceMode = serviceMode;
			this._imageFormat = imageFormat;
			
			super();        
			this._tileInfo = new TileInfo();  
			this._initExtent = null;  
			this.buildTileInfo();  
			setLoaded(true);  
		}  
		
		override public function get fullExtent() : Extent  
		{  
			return new Extent(-180, -90, 180, 90, new SpatialReference(4490));  
		}  
		
		public function set initExtent(initextent:String):void  
		{  
			this._initExtent = initextent;  
		} 
		
		override public function get initialExtent() :Extent  
		{  
			if (this._initExtent == null)  
				return new Extent(70.0, 15.0, 135.0, 55.0, new SpatialReference(4490));      
			var coors:Array = this._initExtent.split(",");  
			return new Extent(Number(coors[0]), Number(coors[1]), Number(coors[2]) ,Number(coors[3]), new SpatialReference(4490));  
		}  
		
		override public function get spatialReference() : SpatialReference  
		{  
			return new SpatialReference(4490);  
		}  
		
		override public function get tileInfo() : TileInfo  
		{  
			return this._tileInfo;  
		}  
		
		//根据不同地图类型加载不同WMTS服务
		override protected function getTileURL(level:Number, row:Number, col:Number) : URLRequest  
		{
			if(this._mapStyle == "ImageBaseMap")//获取影像地图（底图）
			{
				_baseURL = "http://t0.tianditu.com/img_c/wmts";
				_layerId = "img";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "ImageCNNote")//获取影像地图（中文注记）
			{
				_baseURL = "http://t0.tianditu.com/cia_c/wmts";
				_layerId = "cia";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "ImageENNote")//获取影像地图（英文注记）
			{
				_baseURL = "http://t0.tianditu.com/eia_c/wmts";
				_layerId = "eia";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "TerrainBaseMap")//获取地形图（底图）
			{
				_baseURL = "http://t0.tianditu.com/ter_c/wmts";
				_layerId = "ter";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "TerrainCNNote")//获取地形图（中文注记）
			{
				_baseURL = "http://t0.tianditu.com/cta_c/wmts";
				_layerId = "cta";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "TerrainENNote")//获取地形图（英文注记）
			{
				//暂无
			}
			else if(this._mapStyle == "VectorBaseMap")//获取矢量图（底图）
			{
				_baseURL = "http://t0.tianditu.com/vec_c/wmts";
				_layerId = "vec";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "VectorCNNote")//获取矢量图（中文注记）
			{
				_baseURL = "http://t0.tianditu.com/cva_c/wmts";
				_layerId = "cva";
				_tileMatrixSetId = "c";
			}
			else if(this._mapStyle == "VectorENNote")//获取矢量图（英文注记）
			{
				_baseURL = "http://t0.tianditu.com/eva_c/wmts";
				_layerId = "eva";
				_tileMatrixSetId = "c";
			}
			
			var urlRequest:String=_baseURL+ "/wmts?Service=WMTS&Request=GetTile&Version=1.0.0" +  
				"&Style=Default&Format="+_imageFormat+"&serviceMode="+_serviceMode+"&layer="+_layerId +  
				"&TileMatrixSet="+_tileMatrixSetId+"&TileMatrix=" + level + "&TileRow=" + row + "&TileCol=" + col; 
			
			return new URLRequest(urlRequest);    
		}  
		
		//切片信息
		private function buildTileInfo() : void  
		{  
			this._tileInfo.height = 256;  
			this._tileInfo.width = 256;  
			this._tileInfo.origin = new MapPoint(-180, 90);  
			this._tileInfo.spatialReference = new SpatialReference(4490);  
			this._tileInfo.lods = new Array();  
			this._tileInfo.lods = [  
				new LOD(1 , 0.703125,    2.958293554545656E8),   
				new LOD(2 , 0.351563,    1.479146777272828E8),   
				new LOD(3 , 0.175781,    7.39573388636414E7),    
				new LOD(4 , 0.0878906,   3.69786694318207E7),    
				new LOD(5 , 0.0439453,   1.848933471591035E7),   
				new LOD(6 , 0.0219727,   9244667.357955175),     
				new LOD(7 , 0.0109863,   4622333.678977588),     
				new LOD(8 , 0.00549316,  2311166.839488794),     
				new LOD(9 , 0.00274658,  1155583.419744397),     
				new LOD(10, 0.00137329,  577791.7098721985),     
				new LOD(11, 0.000686646,  288895.85493609926),   
				new LOD(12, 0.000343323,  144447.92746804963),   
				new LOD(13, 0.000171661,  72223.96373402482),    
				new LOD(14, 8.58307e-005, 36111.98186701241),
				new LOD(15, 4.29153e-005, 18055.990933506204),   
				new LOD(16, 2.14577e-005, 9027.995466753102),  
				new LOD(17, 1.07289e-005, 4513.997733376551),    
				new LOD(18, 5.36445e-006, 2256.998866688275)   
			];
		}
	}    
}// ActionScript file