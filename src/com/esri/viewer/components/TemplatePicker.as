package com.esri.viewer.components
{
	import spark.components.supportClasses.SkinnableComponent;
	import com.esri.ags.components.supportClasses.Template;
	import flash.utils.Dictionary;
	import com.esri.ags.esri_internal;
	import com.esri.ags.layers.FeatureLayer;
	import com.esri.ags.events.LayerEvent;
	import com.esri.ags.events.TemplatePickerEvent;
	import com.esri.ags.layers.supportClasses.FeatureTemplate;
	import com.esri.ags.layers.supportClasses.FeatureType;
	import com.esri.ags.layers.ArcGISDynamicMapServiceLayer;
	import com.esri.ags.layers.supportClasses.FeatureLayerDetails;
	import mx.rpc.Fault;
	import com.esri.ags.layers.supportClasses.LegendItemInfo;
	import com.esri.ags.layers.supportClasses.LayerLegendInfo;
	import mx.rpc.AsyncResponder;
	import flash.events.Event;
	import com.esri.ags.layers.Layer;
	import com.esri.ags.symbols.Symbol;
	import com.esri.ags.symbols.CompositeSymbol;
	import com.esri.ags.symbols.SimpleMarkerSymbol;
	import com.esri.ags.symbols.SimpleLineSymbol;
	import com.esri.ags.symbols.SimpleFillSymbol;
	import com.esri.ags.geometry.Geometry;
	
	use namespace esri_internal;
	
	public class TemplatePicker extends SkinnableComponent
	{
		
		public function TemplatePicker(featureLayers:Array=null) {
			this._featureLayerToDynamicMapServiceLayer = new Dictionary();
			this._dynamicMapServiceLayerToLegendInfo = new Dictionary();
			super();
			this.featureLayers = featureLayers;
		}
		
		private var _loading:Boolean;
		
		private var _featureLayers:Array;
		
		private var _selectedTemplate:Template;
		
		private var _featureLayerLoadedCount:Number;
		
		private var _successfullyLoadedLayers:Array;
		
		private var _featureLayerToDynamicMapServiceLayer:Dictionary;
		
		private var _dynamicMapServiceLayerToLegendInfo:Dictionary;
		
		esri_internal var onlyShowEditableAndCreateAllowedLayers:Boolean;
		
		override public function set enabled(value:Boolean) : void {
			if(enabled != value)
			{
				invalidateSkinState();
			}
			super.enabled = value;
		}
		
		public function get featureLayers() : Array {
			return this._featureLayers;
		}
		
		public function set featureLayers(value:Array) : void {
			var featureLayerOld:FeatureLayer = null;
			var featureLayerNew:FeatureLayer = null;
			var featureLayer:FeatureLayer = null;
			for each(featureLayerOld in this._featureLayers)
			{
				featureLayerOld.removeEventListener(LayerEvent.LOAD,this.featureLayer_loadCompleteHandler);
				featureLayerOld.removeEventListener(LayerEvent.LOAD_ERROR,this.featureLayer_loadCompleteHandler);
			}
			this._featureLayers = value;
			this._featureLayerLoadedCount = 0;
			if(this._featureLayers)
			{
				this._loading = true;
				for each(featureLayerNew in this._featureLayers)
				{
					if((!featureLayerNew.loaded) && (!featureLayerNew.loadFault))
					{
						featureLayerNew.addEventListener(LayerEvent.LOAD,this.featureLayer_loadCompleteHandler,false,-1);
						featureLayerNew.addEventListener(LayerEvent.LOAD_ERROR,this.featureLayer_loadCompleteHandler,false,-1);
					}
					else
					{
						this._featureLayerLoadedCount++;
					}
				}
				if(this._featureLayerLoadedCount == this._featureLayers.length)
				{
					this._loading = false;
					this._successfullyLoadedLayers = [];
					for each(featureLayer in this._featureLayers)
					{
						if(!((this.onlyShowEditableAndCreateAllowedLayers) && (!featureLayer.isEditable) || (this.onlyShowEditableAndCreateAllowedLayers) && (featureLayer.isEditable) && (!this.checkIfCreateIsAllowed(featureLayer)) || (featureLayer.loadFault)))
						{
							this._successfullyLoadedLayers.push(featureLayer);
						}
					}
					this.populateTemplateCollection(this._successfullyLoadedLayers);
				}
				invalidateSkinState();
			}
		}
		
		public function get selectedTemplate() : Template {
			return this._selectedTemplate;
		}
		
		public function set selectedTemplate(value:Template) : void {
			if((this._selectedTemplate) && (value))
			{
				if((!(this._selectedTemplate.featureLayer == value.featureLayer)) || (!(this._selectedTemplate.featureType == value.featureType)) || (!(this._selectedTemplate.featureTemplate == value.featureTemplate)))
				{
					this._selectedTemplate = value;
					dispatchEvent(new TemplatePickerEvent(TemplatePickerEvent.SELECTED_TEMPLATE_CHANGE,this._selectedTemplate));
				}
			}
			else if(this._selectedTemplate != value)
			{
				this._selectedTemplate = value;
				dispatchEvent(new TemplatePickerEvent(TemplatePickerEvent.SELECTED_TEMPLATE_CHANGE,this._selectedTemplate));
			}
			
		}
		
		private var _templateCollection:Array;
		private var getLegendResult:Function;
		private var getLegendFault:Function;
		private var parseLayerLegendInfos:Function;
		
		public function get templateCollection() : Array {
			return this._templateCollection;
		}
		
		override protected function getCurrentSkinState() : String {
			if(!enabled)
			{
				return "disabled";
			}
			if(this._loading)
			{
				return "loading";
			}
			return "normal";
		}
		
		private function featureLayer_loadCompleteHandler(event:LayerEvent) : void {
			var featureLayer:FeatureLayer = null;
			this._featureLayerLoadedCount++;
			if(this._featureLayerLoadedCount == this._featureLayers.length)
			{
				this._loading = false;
				this._successfullyLoadedLayers = [];
				for each(featureLayer in this._featureLayers)
				{
					if((featureLayer.loaded) && (!featureLayer.loadFault))
					{
						if(!((this.onlyShowEditableAndCreateAllowedLayers) && (!featureLayer.isEditable) || (this.onlyShowEditableAndCreateAllowedLayers) && (featureLayer.isEditable) && (!this.checkIfCreateIsAllowed(featureLayer))))
						{
							this._successfullyLoadedLayers.push(featureLayer);
						}
					}
				}
				this.populateTemplateCollection(this._successfullyLoadedLayers);
				invalidateSkinState();
			}
		}
		
		public function clearSelection() : void {
			this.selectedTemplate = null;
		}
		
		override public function styleChanged(styleProp:String) : void {
			super.styleChanged(styleProp);
			if(styleProp == "skinClass")
			{
				callLater(this.populateTemplateCollection,[this._successfullyLoadedLayers]);
			}
		}
		
		private function populateTemplateCollection(loadedFeatureLayers:Array) : void {
			this._templateCollection = [];
			var index:int = 0;
			this.getTemplatesForFeatureLayer(index,loadedFeatureLayers);
		}
		
		private function getTemplatesForFeatureLayer(index:int, loadedFeatureLayers:Array) : void {
			var featureLayer:FeatureLayer = null;
			var templateArray:Array = null;
			var template:Template = null;
			var template0:FeatureTemplate = null;
			var type:FeatureType = null;
			var template1:FeatureTemplate = null;
			var template2:FeatureTemplate = null;
			var dynamicMapServiceLayer:ArcGISDynamicMapServiceLayer = null;
			if(index < loadedFeatureLayers.length)
			{
				featureLayer = loadedFeatureLayers[index];
				templateArray = [];
				if(featureLayer.layerDetails is FeatureLayerDetails)
				{
					if((!featureLayer.layerDetails.types) || (featureLayer.layerDetails.types.length == 0))
					{
						if((FeatureLayerDetails(featureLayer.layerDetails).templates) && (FeatureLayerDetails(featureLayer.layerDetails).templates.length > 0))
						{
							for each(template0 in FeatureLayerDetails(featureLayer.layerDetails).templates)
							{
								template = new Template();
								template.featureLayer = featureLayer;
								template.featureTemplate = template0;
								templateArray.push(template);
							}
						}
						else
						{
							template = new Template();
							template.featureLayer = featureLayer;
							templateArray.push(template);
						}
					}
					else if((featureLayer.layerDetails.types) && (featureLayer.layerDetails.types.length > 0))
					{
						for each(type in featureLayer.layerDetails.types)
						{
							if(type.templates)
							{
								for each(template1 in type.templates)
								{
									template = new Template();
									template.featureLayer = featureLayer;
									template.featureType = type;
									template.featureTemplate = template1;
									templateArray.push(template);
								}
							}
							else if(FeatureLayerDetails(featureLayer.layerDetails).templates)
							{
								for each(template2 in FeatureLayerDetails(featureLayer.layerDetails).templates)
								{
									template = new Template();
									template.featureLayer = featureLayer;
									template.featureType = type;
									template.featureTemplate = template2;
									templateArray.push(template);
								}
							}
							else
							{
								template = new Template();
								template.featureLayer = featureLayer;
								template.featureType = type;
								templateArray.push(template);
							}
							
						}
					}
					
					if((featureLayer.mode == FeatureLayer.MODE_SELECTION) && (10.1 <= featureLayer.layerDetails.version))
					{
						getLegendResult = function(layerLegendInfos:Array, token:Object=null):void
						{
							_dynamicMapServiceLayerToLegendInfo[token as ArcGISDynamicMapServiceLayer] = layerLegendInfos;
							parseLayerLegendInfos(layerLegendInfos);
						};
						getLegendFault = function(fault:Fault, token:Object=null):void
						{
							parseTemplates(index,templateArray,featureLayer,loadedFeatureLayers);
						};
						parseLayerLegendInfos = function(layerLegendInfos:Array):void
						{
							var legendItemInfos:Array = null;
							var t0:Template = null;
							var legendItemInfo:LegendItemInfo = null;
							var t01:Template = null;
							var t02:Template = null;
							var i:int = 0;
							while(i < layerLegendInfos.length)
							{
								if(LayerLegendInfo(layerLegendInfos[i]).layerId == String(featureLayer.layerDetails.id))
								{
									legendItemInfos = LayerLegendInfo(layerLegendInfos[i]).legendItemInfos;
									break;
								}
								i++;
							}
							if((legendItemInfos) && (legendItemInfos.length))
							{
								for each(t0 in templateArray)
								{
									for each(legendItemInfo in legendItemInfos)
									{
										if((legendItemInfo.values) && (legendItemInfo.values.length))
										{
											if(t0.featureTemplate.prototype.attributes[featureLayer.layerDetails.typeIdField] == legendItemInfo.values[0])
											{
												t0.symbol = legendItemInfo.symbol;
											}
										}
										else
										{
											for each(t01 in templateArray)
											{
												t01.symbol = getTemplateSymbol(t01,featureLayer);
											}
										}
									}
								}
							}
							else
							{
								for each(t02 in templateArray)
								{
									t02.symbol = getTemplateSymbol(t02,featureLayer);
								}
							}
							index++;
							_templateCollection.push(
								{
									"featureLayer":featureLayer,
									"selectedTemplates":templateArray,
									"templates":templateArray
								});
							getTemplatesForFeatureLayer(index,loadedFeatureLayers);
						};
						dynamicMapServiceLayer = this.getDynamicMapServiceLayer(featureLayer);
						if(dynamicMapServiceLayer)
						{
							if(!this._dynamicMapServiceLayerToLegendInfo[dynamicMapServiceLayer])
							{
								dynamicMapServiceLayer.getLegendInfos(new AsyncResponder(getLegendResult,getLegendFault,dynamicMapServiceLayer));
							}
							else
							{
								parseLayerLegendInfos(this._dynamicMapServiceLayerToLegendInfo[dynamicMapServiceLayer]);
							}
						}
						else
						{
							this.parseTemplates(index,templateArray,featureLayer,loadedFeatureLayers);
						}
					}
					else
					{
						this.parseTemplates(index,templateArray,featureLayer,loadedFeatureLayers);
					}
				}
			}
			else
			{
				this._loading = false;
				invalidateSkinState();
				dispatchEvent(new Event("templateCollectionReady"));
			}
		}
		
		private function parseTemplates(index:int, templateArray:Array, featureLayer:FeatureLayer, loadedFeatureLayers:Array) : void {
			var t:Template = null;
			for each(t in templateArray)
			{
				t.symbol = this.getTemplateSymbol(t,featureLayer);
			}
			index++;
			this._templateCollection.push(
				{
					"featureLayer":featureLayer,
					"selectedTemplates":templateArray,
					"templates":templateArray
				});
			this.getTemplatesForFeatureLayer(index,loadedFeatureLayers);
		}
		
		private function getDynamicMapServiceLayer(featureLayer:FeatureLayer) : ArcGISDynamicMapServiceLayer {
			var arcgisDynamicMapServiceLayer:ArcGISDynamicMapServiceLayer = null;
			var featureServiceURL:String = null;
			var mapServiceURL:String = null;
			var layer:Layer = null;
			if(this._featureLayerToDynamicMapServiceLayer[featureLayer])
			{
				arcgisDynamicMapServiceLayer = this._featureLayerToDynamicMapServiceLayer[featureLayer];
			}
			else
			{
				featureServiceURL = featureLayer.url.substring(0,featureLayer.url.lastIndexOf("/"));
				mapServiceURL = featureServiceURL.replace("FeatureServer","MapServer");
				for each(layer in featureLayer.map.layers)
				{
					if((layer is ArcGISDynamicMapServiceLayer) && (ArcGISDynamicMapServiceLayer(layer).url == mapServiceURL))
					{
						if(featureLayer.gdbVersion)
						{
							if((ArcGISDynamicMapServiceLayer(layer).gdbVersion) && (ArcGISDynamicMapServiceLayer(layer).gdbVersion == featureLayer.gdbVersion))
							{
								arcgisDynamicMapServiceLayer = ArcGISDynamicMapServiceLayer(layer);
								this._featureLayerToDynamicMapServiceLayer[featureLayer] = arcgisDynamicMapServiceLayer;
								break;
							}
							continue;
						}
						arcgisDynamicMapServiceLayer = ArcGISDynamicMapServiceLayer(layer);
						this._featureLayerToDynamicMapServiceLayer[featureLayer] = arcgisDynamicMapServiceLayer;
						break;
					}
				}
			}
			return arcgisDynamicMapServiceLayer;
		}
		
		private function getTemplateSymbol(template:Template, featureLayer:FeatureLayer) : Symbol {
			var result:Symbol = null;
			if(featureLayer.renderer)
			{
				if(template.featureTemplate)
				{
					result = featureLayer.renderer.getSymbol(template.featureTemplate.prototype);
				}
			}
			else if(featureLayer.symbol)
			{
				result = featureLayer.symbol;
			}
			
			if((!result) || (result is CompositeSymbol))
			{
				result = this.getDefaultSymbolBasedOnGeometry(featureLayer);
			}
			return result;
		}
		
		private function getDefaultSymbolBasedOnGeometry(fLayer:FeatureLayer) : Symbol {
			var sym:Symbol = null;
			switch(fLayer.layerDetails.geometryType)
			{
				case Geometry.MAPPOINT:
					sym = new SimpleMarkerSymbol();
					break;
				case Geometry.POLYLINE:
					sym = new SimpleLineSymbol();
					break;
				case Geometry.POLYGON:
					sym = new SimpleFillSymbol();
					break;
			}
			return sym;
		}
		
		private function checkIfCreateIsAllowed(featureLayer:FeatureLayer) : Boolean {
			var result:* = false;
			if(featureLayer.layerDetails is FeatureLayerDetails)
			{
				result = (featureLayer.layerDetails as FeatureLayerDetails).isCreateAllowed;
			}
			return result;
		}
	}
}
