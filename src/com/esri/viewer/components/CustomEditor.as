package com.esri.viewer.components
{
	
	import com.esri.ags.FeatureSet;
	import com.esri.ags.Graphic;
	import com.esri.ags.Map;
	import com.esri.ags.SpatialReference;
	import com.esri.ags.components.AttributeInspector;
	import com.esri.ags.components.supportClasses.AddOperation;
	import com.esri.ags.components.supportClasses.CreateOptions;
	import com.esri.ags.components.supportClasses.CutOperation;
	import com.esri.ags.components.supportClasses.DeleteOperation;
	import com.esri.ags.components.supportClasses.EditAttributesOperation;
	import com.esri.ags.components.supportClasses.EditGeometryOperation;
	import com.esri.ags.components.supportClasses.MergeOperation;
	import com.esri.ags.components.supportClasses.ReshapeOperation;
	import com.esri.ags.esri_internal;
	import com.esri.ags.events.AttributeInspectorEvent;
	import com.esri.ags.events.DrawEvent;
	import com.esri.ags.events.EditEvent;
	import com.esri.ags.events.FeatureLayerEvent;
	import com.esri.ags.events.LayerEvent;
	import com.esri.ags.events.MapMouseEvent;
	import com.esri.ags.events.TemplatePickerEvent;
	import com.esri.ags.geometry.Extent;
	import com.esri.ags.geometry.Geometry;
	import com.esri.ags.geometry.MapPoint;
	import com.esri.ags.geometry.Multipoint;
	import com.esri.ags.geometry.Polygon;
	import com.esri.ags.geometry.Polyline;
	import com.esri.ags.layers.ArcGISDynamicMapServiceLayer;
	import com.esri.ags.layers.FeatureLayer;
	import com.esri.ags.layers.Layer;
	import com.esri.ags.layers.supportClasses.EditFieldsInfo;
	import com.esri.ags.layers.supportClasses.FeatureEditResult;
	import com.esri.ags.layers.supportClasses.FeatureEditResults;
	import com.esri.ags.layers.supportClasses.FeatureLayerDetails;
	import com.esri.ags.layers.supportClasses.FeatureTemplate;
	import com.esri.ags.symbols.CompositeSymbol;
	import com.esri.ags.symbols.SimpleFillSymbol;
	import com.esri.ags.symbols.SimpleLineSymbol;
	import com.esri.ags.symbols.SimpleMarkerSymbol;
	import com.esri.ags.symbols.Symbol;
	import com.esri.ags.tasks.GeometryService;
	import com.esri.ags.tasks.GeometryServiceSingleton;
	import com.esri.ags.tasks.supportClasses.Query;
	import com.esri.ags.tools.DrawTool;
	import com.esri.ags.tools.EditTool;
	import com.esri.ags.utils.ESRIMessageCodes;
	import com.esri.ags.utils.GeometryUtil;
	import com.esri.ags.utils.GraphicUtil;
	
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.geom.Point;
	import flash.ui.Keyboard;
	import flash.utils.Dictionary;
	
	import flashx.undo.IOperation;
	import flashx.undo.UndoManager;
	
	import mx.binding.utils.ChangeWatcher;
	import mx.core.FlexGlobals;
	import mx.core.UIComponent;
	import mx.events.FlexEvent;
	import mx.events.PropertyChangeEvent;
	import mx.managers.CursorManager;
	import mx.managers.CursorManagerPriority;
	import mx.rpc.AsyncResponder;
	import mx.rpc.Fault;
	import mx.rpc.Responder;
	import mx.rpc.events.FaultEvent;
	import mx.utils.ObjectUtil;
	
	import spark.components.DropDownList;
	import spark.components.Label;
	import spark.components.supportClasses.ButtonBase;
	import spark.components.supportClasses.SkinnableComponent;
	import spark.components.supportClasses.ToggleButtonBase;
	import spark.events.IndexChangeEvent;
	
	use namespace esri_internal;
	
	public class CustomEditor extends SkinnableComponent
	{
		
		
		public function CustomEditor(featureLayers:Array=null, map:Map=null, geometryService:GeometryService=null) 
		{
			//this.moveCursor = Editor_moveCursor;
			this.m_drawTool = new DrawTool();
			this.m_editTool = new EditTool();
			this.m_selectionExtentSymbol = new SimpleFillSymbol("solid",0,0,new SimpleLineSymbol("solid",0,1,2));
			this.m_undoCutUpdateDeletesArray = [];
			this.m_undoRedoMergeAddsDeletesArray = [];
			this.m_activeFeatureChangedAttributes = [];
			this.m_featureLayerToDynamicMapServiceLayer = new Dictionary();
			super();
			this.m_undoManager = new UndoManager();
			this.m_attributeInspector = new AttributeInspector();
			this.m_attributeInspector.infoWindowLabel = ESRIMessageCodes.getString("editorInfoWindowLabel");
			this.m_attributeInspector.addEventListener(AttributeInspectorEvent.UPDATE_FEATURE,this.attributeInspector_updateFeatureHandler);
			this.m_attributeInspector.addEventListener(AttributeInspectorEvent.DELETE_FEATURE,this.attributeInspector_deleteFeatureHandler);
			this.m_attributeInspector.addEventListener(AttributeInspectorEvent.SAVE_FEATURE,this.attributeInspector_saveFeatureHandler,false,-1);
			this.m_changeWatcher = ChangeWatcher.watch(this.m_attributeInspector,"activeFeature",this.attributeInspector_activeFeatureChangeHandler);
			this.featureLayers = featureLayers;
			this.map = map;
			this.geometryService = geometryService;
			FlexGlobals.topLevelApplication.addEventListener(KeyboardEvent.KEY_DOWN,this.key_downHandler);
			this.m_drawTool.addEventListener(DrawEvent.DRAW_START,this.drawTool_drawStartHandler);
			this.m_drawTool.addEventListener(DrawEvent.DRAW_END,this.drawTool_drawEndHandler);
			this.addEditToolEventListeners();
		}
		
		private static const ADD_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorAddFeatureOperationStartLabel");
		
		private static const ADD_FEATURE_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorAddFeatureOperationCompleteLabel");
		
		private static const ADD_FEATURE_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorAddFeatureOperationFailedLabel");
		
		private static const DELETE_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorDeleteFeatureOperationStartLabel");
		
		private static const DELETE_FEATURE_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorDeleteFeatureOperationCompleteLabel");
		
		private static const DELETE_FEATURE_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorDeleteFeatureOperationFailedLabel");
		
		private static const DELETE_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorDeleteFeaturesOperationStartLabel");
		
		private static const DELETE_FEATURES_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorDeleteFeaturesOperationCompleteLabel");
		
		private static const DELETE_FEATURES_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorDeleteFeaturesOperationFailedLabel");
		
		private static const UPDATE_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorUpdateFeatureOperationStartLabel");
		
		private static const UPDATE_FEATURE_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorUpdateFeatureOperationCompleteLabel");
		
		private static const UPDATE_FEATURE_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorUpdateFeatureOperationFailedCompleteLabel");
		
		private static const MERGE_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorMergeFeaturesOperationStartLabel");
		
		private static const MERGE_FEATURES_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorMergeFeaturesOperationCompleteLabel");
		
		private static const MERGE_FEATURES_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorMergeFeaturesOperationFailedCompleteLabel");
		
		private static const SPLIT_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorSplitFeatureOperationStartLabel");
		
		private static const SPLIT_FEATURE_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorSplitFeatureOperationCompleteLabel");
		
		private static const SPLIT_FEATURE_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorSplitFeatureOperationFailedCompleteLabel");
		
		private static const SPLIT_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorSplitFeaturesOperationStartLabel");
		
		private static const SPLIT_FEATURES_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorSplitFeaturesOperationCompleteLabel");
		
		private static const SPLIT_FEATURES_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorSplitFeaturesOperationFailedCompleteLabel");
		
		private static const UNDO_ADD_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoAddFeatureOperationStartLabel");
		
		private static const UNDO_DELETE_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoDeleteFeatureOperationStartLabel");
		
		private static const UNDO_DELETE_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoDeleteFeaturesOperationStartLabel");
		
		private static const UNDO_UPDATE_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoUpdateFeatureOperationStartLabel");
		
		private static const UNDO_MERGE_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoMergeFeaturesOperationStartLabel");
		
		private static const UNDO_SPLIT_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoSplitFeatureOperationStartLabel");
		
		private static const UNDO_SPLIT_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorUndoSplitFeaturesOperationStartLabel");
		
		private static const REDO_ADD_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoAddFeatureOperationStartLabel");
		
		private static const REDO_DELETE_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoDeleteFeatureOperationStartLabel");
		
		private static const REDO_DELETE_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoDeleteFeaturesOperationStartLabel");
		
		private static const REDO_UPDATE_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoUpdateFeatureOperationStartLabel");
		
		private static const REDO_MERGE_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoMergeFeaturesOperationStartLabel");
		
		private static const REDO_SPLIT_FEATURE_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoSplitFeatureOperationStartLabel");
		
		private static const REDO_SPLIT_FEATURES_OPERATION_START:String = ESRIMessageCodes.getString("editorRedoSplitFeaturesOperationStartLabel");
		
		private static const UNDO_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorUndoOperationCompleteLabel");
		
		private static const UNDO_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorUndoOperationFailedLabel");
		
		private static const REDO_OPERATION_COMPLETE:String = ESRIMessageCodes.getString("editorRedoOperationCompleteLabel");
		
		private static const REDO_OPERATION_FAILED:String = ESRIMessageCodes.getString("editorRedoOperationFailedLabel");
		
		private static var _skinParts:Object = 
			{
				"operationStartLabel":false,
				"clearSelectionButton":false,
				"mergeButton":false,
				"drawDropDownList":false,
				"reshapeButton":false,
				"deleteButton":false,
				"templatePicker":false,
				"undoButton":false,
				"cutButton":false,
				"selectionDropDownList":false,
				"redoButton":false,
				"operationCompleteLabel":false
			};
		
		public var clearSelectionButton:ButtonBase;
		
		public var cutButton:ToggleButtonBase;
		
		public var deleteButton:ButtonBase;
		
		public var drawDropDownList:DropDownList;
		
		public var mergeButton:ButtonBase;
		
		public var redoButton:ButtonBase;
		
		public var reshapeButton:ToggleButtonBase;
		
		public var selectionDropDownList:DropDownList;
		
		public var templatePicker:TemplatePicker;
		
		public var undoButton:ButtonBase;
		
		public var operationStartLabel:Label;
		
		public var operationCompleteLabel:Label;
		
		private var moveCursor:Class;
		
		private var m_featureLayers:Array;
		
		private var m_loadedFeatureLayers:Array;
		
		private var m_visibleFeatureLayers:Array;
		
		private var m_inScaleFeatureLayers:Array;
		
		private var m_map:Map;
		
		private var m_geometryService:GeometryService;
		
		private var m_attributeInspector:AttributeInspector;
		
		private var m_createOptions:CreateOptions;
		
		private var m_changeWatcher:ChangeWatcher;
		
		private var m_drawTool:DrawTool;
		
		private var m_editTool:EditTool;
		
		private var m_lastActiveEdit:String;
		
		private var m_editGraphic:Graphic;
		
		private var m_query:Query;
		
		private var m_applyingEdits:Boolean;
		
		private var m_templateSelected:Boolean;
		
		private var m_featuresSelected:Boolean;
		
		private var m_toolbarVisible:Boolean;
		
		private var m_toolbarCutVisible:Boolean;
		
		private var m_toolbarMergeVisible:Boolean;
		
		private var m_toolbarReshapeVisible:Boolean;
		
		private var m_addEnabled:Boolean = true;
		
		private var m_deleteEnabled:Boolean = true;
		
		private var m_updateGeometryEnabled:Boolean = true;
		
		private var m_updateAttributesEnabled:Boolean = true;
		
		private var m_doNotApplyEdits:Boolean;
		
		private var m_editClearSelection:Boolean;
		
		private var m_cutInProgress:Boolean;
		
		private var m_cutQueryFeatureArray:Array;
		
		private var m_polylinePolygonCutResultArray:Array;
		
		private var m_mergeInProgress:Boolean;
		
		private var m_reshapeInProgress:Boolean;
		
		private var m_creationInProgress:Boolean;
		
		private var m_editGraphicPartOfSelection:Boolean;
		
		private var m_editPoint:MapPoint;
		
		private var m_featureCreated:Boolean;
		
		private var m_lastCreatedGraphic:Graphic;
		
		private var m_showTemplateSwatchOnCursor:Boolean = true;
		
		private var m_drawStart:Boolean;
		
		private var m_graphicRemoved:Boolean;
		
		private var m_graphicEditing:Boolean;
		
		private var m_currentlyDrawnGraphic:Graphic;
		
		private var m_selectionModeFeatureLayers:Array;
		
		private var m_visibleSelectionModeFeatureLayers:Array;
		
		private var m_newFeatureCreated:Boolean;
		
		private var m_selectionMode:Boolean;
		
		private var m_stagePointInfoWindow:Point;
		
		private var m_createGeometryType:String;
		
		private var m_lastPolygonCreateOptionIndex:int = 0;
		
		private var m_lastPolylineCreateOptionIndex:int = 0;
		
		private var m_currentSelectedTemplateFeatureLayer:FeatureLayer = null;
		
		private var m_currentSelectedTemplateFeatureLayerChanged:Boolean;
		
		private var m_isEdit:Boolean;
		
		private var m_templateSwatch:UIComponent;
		
		private var m_selectionExtentSymbol:SimpleFillSymbol;
		
		private var m_undoManager:UndoManager;
		
		private var m_undoAndRedoItemLimit:int = 25;
		
		private var m_redoVertexMoveGraphicGeometry:Geometry;
		
		private var m_undoVertexMoveGraphicGeometry:Geometry;
		
		private var m_redoGraphicMoveGraphicGeometry:Geometry;
		
		private var m_undoGraphicMoveGraphicGeometry:Geometry;
		
		private var m_redoVertexAddGraphicGeometry:Geometry;
		
		private var m_undoVertexAddGraphicGeometry:Geometry;
		
		private var m_redoVertexDeleteGraphicGeometry:Geometry;
		
		private var m_undoVertexDeleteGraphicGeometry:Geometry;
		
		private var m_redoGraphicScaleRotateGraphicGeometry:Geometry;
		
		private var m_undoGraphicScaleRotateGraphicGeometry:Geometry;
		
		private var m_redoReshapeGraphicGeometry:Geometry;
		
		private var m_undoReshapeGraphicGeometry:Geometry;
		
		private var m_undoCutGeometryArray:Array;
		
		private var m_redoCutGeometryArray:Array;
		
		private var m_undoRedoAddDeleteOperation:Boolean;
		
		private var m_undoRedoCutOperation:Boolean;
		
		private var m_undoRedoMergeOperation:Boolean;
		
		private var m_undoRedoReshapeOperation:Boolean;
		
		private var m_redoAddOperation:Boolean;
		
		private var m_undoAddOperation:Boolean;
		
		private var m_featureLayerCountLoaded:Number = 0;
		
		private var m_featuresToBeDeleted:Array;
		
		private var m_numMergeFeatureLayers:int;
		
		private var m_countDeleteFeatureLayers:int;
		
		private var m_featureLayerAddResults:Array;
		
		private var m_featureLayerDeleteResults:Array;
		
		private var m_lastUpdateOperation:String;
		
		private var m_arrUndoCutOperation:Array;
		
		private var m_undoCutUpdateDeletesArray:Array;
		
		private var m_undoRedoMergeAddsDeletesArray:Array;
		
		private var m_arrUndoRedoMergeOperation:Array;
		
		private var m_undoRedoInProgress:Boolean;
		
		private var m_openHandCursorVisibleState:Boolean;
		
		private var m_activeFeatureChangedAttributes:Array;
		
		private var m_infoWindowCloseButtonClicked:Boolean;
		
		private var m_attributesSaved:Boolean;
		
		private var m_featureLayerToDynamicMapServiceLayer:Dictionary;
		
		private var m_tempNewFeature:Graphic;
		
		private var m_tempNewFeatureLayer:FeatureLayer;
		
		private var m_deletingTempGraphic:Boolean;
		
		private var m_lastActiveTempEdit:String = "moveEditVertices";
		private var query_resultHandler:Function;
		private var savePolygon:Function;
		private var geometryServiceAutoComplete:Function;
		private var query_faultHandler:Function;
		private var geometryServiceSimplify:Function;
		private var startCut:Function;
		private var geometryServiceCut:Function;
		private var cut_selectResult:Function;
		private var handleCutResult:Function;
		private var addUpdateFeatures:Function;
		private var cut_applyEditsResult:Function;
		private var cut_applyEditsFault:Function;
		private var cutApplyEditsComplete:Function;
		private var cut_selectFault:Function;
		private var reshape_queryResultHandler:Function;
		private var geometryServiceReshape:Function;
		private var reshape_queryFaultHandler:Function;
		private var geometryServiceUnion:Function;
		private var selectFeaturesFromSelectionModeLayers:Function;
		private var isOneFeatureSelected:Function;
		
		override public function set enabled(value:Boolean) : void {
			if(enabled != value)
			{
				invalidateSkinState();
			}
			super.enabled = value;
		}
		
		public function get featureLayers() : Array {
			return this.m_featureLayers;
		}
		
		private function set _1730434088featureLayers(value:Array) : void {
			var featureLayer1:FeatureLayer = null;
			var featureLayer2:FeatureLayer = null;
			for each(featureLayer1 in this.m_featureLayers)
			{
				featureLayer1.removeEventListener(FaultEvent.FAULT,this.featureLayer_faultHandler);
				featureLayer1.removeEventListener(FlexEvent.HIDE,this.featureLayer_hideHandler);
				featureLayer1.removeEventListener(FlexEvent.SHOW,this.featureLayer_showHandler);
				featureLayer1.removeEventListener(LayerEvent.IS_IN_SCALE_RANGE_CHANGE,this.featureLayer_isInScaleRangeChangeHandler);
				featureLayer1.removeEventListener(FeatureLayerEvent.EDITS_COMPLETE,this.featureLayer_editsCompleteHandler);
				featureLayer1.removeEventListener(FeatureLayerEvent.SELECTION_CLEAR,this.featureLayer_selectionClearHandler);
				featureLayer1.removeEventListener(FeatureLayerEvent.SELECTION_COMPLETE,this.featureLayer_selectionCompleteHandler);
			}
			this.m_featureLayers = value;
			this.m_selectionModeFeatureLayers = [];
			if(this.m_featureLayers)
			{
				for each(featureLayer2 in this.m_featureLayers)
				{
					featureLayer2.addEventListener(FaultEvent.FAULT,this.featureLayer_faultHandler);
					featureLayer2.addEventListener(FlexEvent.HIDE,this.featureLayer_hideHandler);
					featureLayer2.addEventListener(FlexEvent.SHOW,this.featureLayer_showHandler);
					featureLayer2.addEventListener(LayerEvent.IS_IN_SCALE_RANGE_CHANGE,this.featureLayer_isInScaleRangeChangeHandler);
					featureLayer2.addEventListener(FeatureLayerEvent.EDITS_COMPLETE,this.featureLayer_editsCompleteHandler);
					featureLayer2.addEventListener(FeatureLayerEvent.SELECTION_CLEAR,this.featureLayer_selectionClearHandler);
					featureLayer2.addEventListener(FeatureLayerEvent.SELECTION_COMPLETE,this.featureLayer_selectionCompleteHandler,false,-1);
					if(featureLayer2.mode == FeatureLayer.MODE_SELECTION)
					{
						this.m_selectionModeFeatureLayers.push(featureLayer2);
					}
				}
				this.m_visibleSelectionModeFeatureLayers = this.getInScaleFeatureLayers(this.getVisibleFeatureLayers(this.m_selectionModeFeatureLayers));
				if(this.m_attributeInspector)
				{
					this.m_attributeInspector.featureLayers = this.m_featureLayers;
				}
				if(this.templatePicker)
				{
					this.templatePicker.featureLayers = this.m_featureLayers;
				}
			}
		}
		
		public function get map() : Map {
			return this.m_map;
		}
		
		private function set _107868map(value:Map) : void {
			if(!value)
			{
				if(this.m_tempNewFeature)
				{
					this.removeTempNewGraphic();
				}
				if(this.m_editGraphic)
				{
					this.m_editGraphic = null;
				}
			}
			if(this.m_map)
			{
				if(this.m_openHandCursorVisibleState)
				{
					this.m_map.openHandCursorVisible = true;
				}
				this.m_map.removeEventListener(KeyboardEvent.KEY_DOWN,this.map_keyDownHandler);
				this.m_map.removeEventListener(MapMouseEvent.MAP_MOUSE_DOWN,this.map_mouseDownHandler);
			}
			this.m_map = value;
			if(this.m_map)
			{
				this.m_openHandCursorVisibleState = this.m_map.openHandCursorVisible;
				if(this.m_openHandCursorVisibleState)
				{
					this.m_map.openHandCursorVisible = false;
				}
				this.m_map.addEventListener(KeyboardEvent.KEY_DOWN,this.map_keyDownHandler);
				this.m_map.addEventListener(MapMouseEvent.MAP_MOUSE_DOWN,this.map_mouseDownHandler);
				this.m_drawTool.map = this.m_map;
				this.m_editTool.map = this.m_map;
				this.m_map.infoWindowContent = null;
				this.m_map.infoWindowContent = this.m_attributeInspector;
			}
		}
		
		public function get geometryService() : GeometryService {
			return this.m_geometryService;
		}
		
		private function set _1579241955geometryService(value:GeometryService) : void {
			this.m_geometryService = value;
		}
		
		public function get toolbarVisible() : Boolean {
			return this.m_toolbarVisible;
		}
		
		private function set _1563241591toolbarVisible(value:Boolean) : void {
			if(this.m_toolbarVisible != value)
			{
				this.m_toolbarVisible = value;
				if(this.m_toolbarVisible)
				{
					this.setButtonStates();
				}
				invalidateSkinState();
			}
		}
		
		public function get toolbarCutVisible() : Boolean {
			return this.m_toolbarCutVisible;
		}
		
		private function set _1691214251toolbarCutVisible(value:Boolean) : void {
			if(this.m_toolbarCutVisible != value)
			{
				this.m_toolbarCutVisible = value;
			}
		}
		
		public function get toolbarMergeVisible() : Boolean {
			return this.m_toolbarMergeVisible;
		}
		
		private function set _1160858571toolbarMergeVisible(value:Boolean) : void {
			if(this.m_toolbarMergeVisible != value)
			{
				this.m_toolbarMergeVisible = value;
			}
		}
		
		public function get toolbarReshapeVisible() : Boolean {
			return this.m_toolbarReshapeVisible;
		}
		
		private function set _385871969toolbarReshapeVisible(value:Boolean) : void {
			if(this.m_toolbarReshapeVisible != value)
			{
				this.m_toolbarReshapeVisible = value;
			}
		}
		
		public function get createOptions() : CreateOptions {
			return this.m_createOptions;
		}
		
		private function set _997042690createOptions(value:CreateOptions) : void {
			if(this.m_createOptions != value)
			{
				this.m_createOptions = value;
			}
		}
		
		public function get createGeometryType() : String {
			return this.m_createGeometryType;
		}
		
		public function get attributeInspector() : AttributeInspector {
			return this.m_attributeInspector;
		}
		
		public function get editTool() : EditTool {
			return this.m_editTool;
		}
		
		public function get drawTool() : DrawTool {
			return this.m_drawTool;
		}
		
		public function get showTemplateSwatchOnCursor() : Boolean {
			return this.m_showTemplateSwatchOnCursor;
		}
		
		private function set _1701569304showTemplateSwatchOnCursor(value:Boolean) : void {
			if(this.m_showTemplateSwatchOnCursor != value)
			{
				this.m_showTemplateSwatchOnCursor = value;
				this.m_templateSwatch = null;
			}
		}
		
		public function get deleteEnabled() : Boolean {
			return this.m_deleteEnabled;
		}
		
		private function set _1814366442deleteEnabled(value:Boolean) : void {
			if(this.m_deleteEnabled != value)
			{
				this.m_deleteEnabled = value;
				this.m_attributeInspector.deleteButtonVisible = this.m_deleteEnabled;
			}
		}
		
		public function get undoAndRedoItemLimit() : int {
			return this.m_undoAndRedoItemLimit;
		}
		
		private function set _1765640073undoAndRedoItemLimit(value:int) : void {
			if(this.m_undoAndRedoItemLimit != value)
			{
				this.m_undoAndRedoItemLimit = value;
				this.m_undoManager.undoAndRedoItemLimit = this.m_undoAndRedoItemLimit;
			}
		}
		
		public function get addEnabled() : Boolean {
			return this.m_addEnabled;
		}
		
		private function set _298640224addEnabled(value:Boolean) : void {
			if(this.m_addEnabled != value)
			{
				this.m_addEnabled = value;
				if(this.templatePicker)
				{
					this.templatePicker.enabled = this.m_addEnabled;
				}
			}
		}
		
		public function get updateAttributesEnabled() : Boolean {
			return this.m_updateAttributesEnabled;
		}
		
		private function set _546952159updateAttributesEnabled(value:Boolean) : void {
			if(this.m_updateAttributesEnabled != value)
			{
				this.m_updateAttributesEnabled = value;
				this.m_attributeInspector.updateEnabled = this.m_updateAttributesEnabled;
			}
		}
		
		public function get updateGeometryEnabled() : Boolean {
			return this.m_updateGeometryEnabled;
		}
		
		private function set _1030763930updateGeometryEnabled(value:Boolean) : void {
			if(this.m_updateGeometryEnabled != value)
			{
				this.m_updateGeometryEnabled = value;
			}
		}
		
		override protected function getCurrentSkinState() : String {
			if(enabled === false)
			{
				return "disabled";
			}
			if(this.m_applyingEdits)
			{
				return "applyingEdits";
			}
			if(this.m_templateSelected)
			{
				return "templateSelected";
			}
			if(this.m_featuresSelected)
			{
				return "featuresSelected";
			}
			if(!this.m_toolbarVisible)
			{
				return "toolbarNotVisible";
			}
			return "normal";
		}
		
		override protected function partAdded(partName:String, instance:Object) : void {
			super.partAdded(partName,instance);
			if(instance === this.templatePicker)
			{
				this.templatePicker.onlyShowEditableAndCreateAllowedLayers = true;
				this.templatePicker.featureLayers = this.m_featureLayers;
				this.templatePicker.enabled = this.m_addEnabled;
				this.templatePicker.addEventListener(TemplatePickerEvent.SELECTED_TEMPLATE_CHANGE,this.templatePicker_selectedTemplateChangeHandler);
			}
			else if(instance === this.selectionDropDownList)
			{
				this.selectionDropDownList.addEventListener(MouseEvent.MOUSE_DOWN,this.dropDownList_mouseDownHandler);
				this.selectionDropDownList.addEventListener(IndexChangeEvent.CHANGE,this.selectionDropDownList_changeHandler);
			}
			else if(instance === this.clearSelectionButton)
			{
				this.clearSelectionButton.addEventListener(MouseEvent.CLICK,this.clearSelectionButton_clickHandler);
			}
			else if(instance === this.drawDropDownList)
			{
				this.drawDropDownList.addEventListener(FlexEvent.VALUE_COMMIT,this.drawDropDownList_valueCommitHandler);
				this.drawDropDownList.addEventListener(IndexChangeEvent.CHANGE,this.drawDropDownList_changeHandler);
			}
			else if(instance === this.deleteButton)
			{
				this.deleteButton.addEventListener(MouseEvent.CLICK,this.deleteButton_clickHandler);
			}
			else if(instance === this.redoButton)
			{
				this.redoButton.enabled = this.m_undoManager.canRedo();
				this.redoButton.addEventListener(MouseEvent.CLICK,this.redoButton_clickHandler);
			}
			else if(instance === this.undoButton)
			{
				this.undoButton.enabled = this.m_undoManager.canUndo();
				this.undoButton.addEventListener(MouseEvent.CLICK,this.undoButton_clickHandler);
			}
			else if(instance === this.cutButton)
			{
				this.cutButton.addEventListener(Event.CHANGE,this.cutButton_changeHandler);
			}
			else if(instance === this.mergeButton)
			{
				this.mergeButton.addEventListener(MouseEvent.CLICK,this.mergeButton_clickHandler);
			}
			else if(instance === this.reshapeButton)
			{
				this.reshapeButton.addEventListener(Event.CHANGE,this.reshapeButton_changeHandler);
			}
			
			
			
			
			
			
			
			
			
		}
		
		override protected function partRemoved(partName:String, instance:Object) : void {
			super.partRemoved(partName,instance);
			if(instance === this.templatePicker)
			{
				this.templatePicker.onlyShowEditableAndCreateAllowedLayers = false;
				this.templatePicker.featureLayers = null;
				this.templatePicker.removeEventListener(TemplatePickerEvent.SELECTED_TEMPLATE_CHANGE,this.templatePicker_selectedTemplateChangeHandler);
			}
			else if(instance === this.selectionDropDownList)
			{
				this.selectionDropDownList.removeEventListener(MouseEvent.CLICK,this.dropDownList_mouseDownHandler);
				this.selectionDropDownList.removeEventListener(IndexChangeEvent.CHANGE,this.selectionDropDownList_changeHandler);
			}
			else if(instance === this.clearSelectionButton)
			{
				this.clearSelectionButton.removeEventListener(MouseEvent.CLICK,this.clearSelectionButton_clickHandler);
			}
			else if(instance === this.drawDropDownList)
			{
				this.drawDropDownList.removeEventListener(FlexEvent.VALUE_COMMIT,this.drawDropDownList_valueCommitHandler);
				this.drawDropDownList.removeEventListener(IndexChangeEvent.CHANGE,this.drawDropDownList_changeHandler);
			}
			else if(instance === this.deleteButton)
			{
				this.deleteButton.removeEventListener(MouseEvent.CLICK,this.deleteButton_clickHandler);
			}
			else if(instance === this.redoButton)
			{
				this.redoButton.removeEventListener(MouseEvent.CLICK,this.redoButton_clickHandler);
			}
			else if(instance === this.undoButton)
			{
				this.undoButton.removeEventListener(MouseEvent.CLICK,this.undoButton_clickHandler);
			}
			else if(instance === this.cutButton)
			{
				this.cutButton.removeEventListener(IndexChangeEvent.CHANGE,this.cutButton_changeHandler);
			}
			else if(instance === this.mergeButton)
			{
				this.mergeButton.removeEventListener(MouseEvent.CLICK,this.mergeButton_clickHandler);
			}
			else if(instance === this.reshapeButton)
			{
				this.reshapeButton.removeEventListener(IndexChangeEvent.CHANGE,this.reshapeButton_changeHandler);
			}
			
			
			
			
			
			
			
			
			
		}
		
		private function featureLayer_hideHandler(event:FlexEvent) : void {
			if((this.templatePicker.selectedTemplate) && (this.templatePicker.selectedTemplate.featureLayer === event.target))
			{
				this.templatePicker.clearSelection();
			}
			if((this.m_tempNewFeature) || (this.m_editGraphic) && (FeatureLayer(this.m_editGraphic.graphicsLayer) === event.target))
			{
				if(this.m_tempNewFeature)
				{
					this.removeTempNewGraphic();
				}
				this.m_editTool.deactivate();
				this.removeEditToolEventListeners();
				this.clearSelection();
				this.map.infoWindow.hide();
				this.m_editGraphic = null;
			}
			this.m_attributeInspector.featureLayers = this.getVisibleFeatureLayers(this.m_featureLayers);
			this.m_visibleSelectionModeFeatureLayers = this.getInScaleFeatureLayers(this.getVisibleFeatureLayers(this.m_selectionModeFeatureLayers));
		}
		
		private function featureLayer_showHandler(event:FlexEvent) : void {
			this.m_attributeInspector.featureLayers = this.getVisibleFeatureLayers(this.m_featureLayers);
			this.m_visibleSelectionModeFeatureLayers = this.getInScaleFeatureLayers(this.getVisibleFeatureLayers(this.m_selectionModeFeatureLayers));
		}
		
		private function featureLayer_isInScaleRangeChangeHandler(event:LayerEvent) : void {
			this.m_attributeInspector.featureLayers = this.getInScaleFeatureLayers(this.m_featureLayers);
			this.m_visibleSelectionModeFeatureLayers = this.getInScaleFeatureLayers(this.getVisibleFeatureLayers(this.m_selectionModeFeatureLayers));
			if((this.templatePicker.selectedTemplate) && (this.templatePicker.selectedTemplate.featureLayer === event.target))
			{
				this.templatePicker.clearSelection();
			}
			if(!FeatureLayer(event.target).isInScaleRange)
			{
				if((this.m_tempNewFeature) || (this.m_editGraphic) && (FeatureLayer(this.m_editGraphic.graphicsLayer) === event.target))
				{
					if(this.m_tempNewFeature)
					{
						this.removeTempNewGraphic();
					}
					this.m_editTool.deactivate();
					this.removeEditToolEventListeners();
					this.map.infoWindow.hide();
				}
			}
		}
		
		private function getVisibleFeatureLayers(featureLayers:Array) : Array {
			var featureLayer:FeatureLayer = null;
			this.m_visibleFeatureLayers = featureLayers.slice();
			var i:int = 0;
			while(i < this.m_visibleFeatureLayers.length)
			{
				featureLayer = this.m_visibleFeatureLayers[i] as FeatureLayer;
				if((featureLayer) && (!featureLayer.visible))
				{
					this.m_visibleFeatureLayers.splice(i,1);
					i--;
				}
				i++;
			}
			return this.m_visibleFeatureLayers;
		}
		
		private function getInScaleFeatureLayers(featureLayers:Array) : Array {
			var featureLayer:FeatureLayer = null;
			this.m_inScaleFeatureLayers = featureLayers.slice();
			var i:int = 0;
			while(i < this.m_inScaleFeatureLayers.length)
			{
				featureLayer = this.m_inScaleFeatureLayers[i] as FeatureLayer;
				if((featureLayer) && (!featureLayer.isInScaleRange))
				{
					this.m_inScaleFeatureLayers.splice(i,1);
					i--;
				}
				i++;
			}
			return this.m_inScaleFeatureLayers;
		}
		
		private function featureLayer_editsCompleteHandler(event:FeatureLayerEvent) : void {
			var k:int = 0;
			var p:int = 0;
			var j:int = 0;
			var d:int = 0;
			var a:int = 0;
			var b:int = 0;
			var undoCutComplete:Function = function():void
			{
				var c:* = 0;
				var k:* = NaN;
				var j:* = NaN;
				if(m_arrUndoCutOperation.length == m_undoCutUpdateDeletesArray.length)
				{
					m_lastUpdateOperation = "";
					operationCompleteLabel.text = UNDO_OPERATION_COMPLETE;
					c = 0;
					while(c < m_arrUndoCutOperation.length)
					{
						if(m_arrUndoCutOperation[c].featureEditResults.updateResults.length > 0)
						{
							k = 0;
							while(k < m_arrUndoCutOperation[c].featureEditResults.updateResults.length)
							{
								if(m_arrUndoCutOperation[c].featureEditResults.updateResults[k].success)
								{
									k++;
									continue;
								}
								operationCompleteLabel.text = UNDO_OPERATION_FAILED;
								break;
							}
						}
						if(m_arrUndoCutOperation[c].featureEditResults.deleteResults.length > 0)
						{
							j = 0;
							while(j < m_arrUndoCutOperation[c].featureEditResults.deleteResults.length)
							{
								if(m_arrUndoCutOperation[c].featureEditResults.deleteResults[j].success)
								{
									j++;
									continue;
								}
								operationCompleteLabel.text = UNDO_OPERATION_FAILED;
								break;
							}
						}
						if(operationCompleteLabel.text == UNDO_OPERATION_FAILED)
						{
							break;
						}
						c++;
					}
					m_undoRedoInProgress = false;
					applyEditsComplete();
				}
			};
			var redoCutComplete:Function = function():void
			{
				var c:* = 0;
				var k:* = NaN;
				var j:* = NaN;
				if(m_arrUndoCutOperation.length == m_undoCutUpdateDeletesArray.length)
				{
					m_lastUpdateOperation = "";
					operationCompleteLabel.text = REDO_OPERATION_COMPLETE;
					c = 0;
					while(c < m_arrUndoCutOperation.length)
					{
						if(m_arrUndoCutOperation[c].featureEditResults.updateResults.length > 0)
						{
							k = 0;
							while(k < m_arrUndoCutOperation[c].featureEditResults.updateResults.length)
							{
								if(m_arrUndoCutOperation[c].featureEditResults.updateResults[k].success)
								{
									k++;
									continue;
								}
								operationCompleteLabel.text = REDO_OPERATION_FAILED;
								break;
							}
						}
						if(m_arrUndoCutOperation[c].featureEditResults.addResults.length > 0)
						{
							m_query = new Query();
							j = 0;
							while(j < m_arrUndoCutOperation[c].featureEditResults.addResults.length)
							{
								if(m_arrUndoCutOperation[c].featureEditResults.addResults[j].success)
								{
									m_query.objectIds = [m_arrUndoCutOperation[c].featureEditResults.addResults[j].objectId];
									FeatureLayer(m_arrUndoCutOperation[c].featureLayer).selectFeatures(m_query,FeatureLayer.SELECTION_ADD);
									j++;
									continue;
								}
								operationCompleteLabel.text = REDO_OPERATION_FAILED;
								break;
							}
						}
						if(operationCompleteLabel.text == REDO_OPERATION_FAILED)
						{
							break;
						}
						c++;
					}
					m_undoRedoInProgress = false;
					applyEditsComplete();
				}
			};
			var undoRedoMergeComplete:Function = function():void
			{
				var c:* = 0;
				var k:* = NaN;
				var j:* = NaN;
				if(m_arrUndoRedoMergeOperation.length == m_undoRedoMergeAddsDeletesArray.length)
				{
					operationCompleteLabel.text = m_lastUpdateOperation == "undo merge geometry"?UNDO_OPERATION_COMPLETE:REDO_OPERATION_COMPLETE;
					c = 0;
					while(c < m_arrUndoRedoMergeOperation.length)
					{
						if(m_arrUndoRedoMergeOperation[c].addResults.length > 0)
						{
							k = 0;
							while(k < m_arrUndoRedoMergeOperation[c].addResults.length)
							{
								if(m_arrUndoRedoMergeOperation[c].addResults[k].success)
								{
									k++;
									continue;
								}
								operationCompleteLabel.text = m_lastUpdateOperation == "undo merge geometry"?UNDO_OPERATION_FAILED:REDO_OPERATION_FAILED;
								break;
							}
						}
						if(m_arrUndoRedoMergeOperation[c].deleteResults.length > 0)
						{
							j = 0;
							while(j < m_arrUndoRedoMergeOperation[c].deleteResults.length)
							{
								if(m_arrUndoRedoMergeOperation[c].deleteResults[j].success)
								{
									j++;
									continue;
								}
								operationCompleteLabel.text = m_lastUpdateOperation == "undo merge geometry"?UNDO_OPERATION_FAILED:REDO_OPERATION_FAILED;
								break;
							}
						}
						if((operationCompleteLabel.text == UNDO_OPERATION_FAILED) || (operationCompleteLabel.text == REDO_OPERATION_FAILED))
						{
							break;
						}
						c++;
					}
					m_lastUpdateOperation = "";
					m_undoRedoInProgress = false;
					applyEditsComplete();
				}
			};
			var applyEditsComplete:Function = function():void
			{
				if(m_applyingEdits)
				{
					m_applyingEdits = false;
					invalidateSkinState();
				}
				operationCompleteLabel.includeInLayout = true;
				operationCompleteLabel.visible = true;
				operationCompleteLabel.visible = false;
				refreshDynamicMapServiceLayer(event.featureLayer);
			};
			if((event.featureEditResults.addResults) && (event.featureEditResults.addResults.length > 0))
			{
				if(this.m_featureCreated)
				{
					this.m_featureCreated = false;
					if(event.featureEditResults.addResults[0].success)
					{
						this.operationCompleteLabel.text = ADD_FEATURE_OPERATION_COMPLETE;
						callLater(this.updateUndoRedoButtons);
					}
					else
					{
						this.operationCompleteLabel.text = ADD_FEATURE_OPERATION_FAILED;
					}
					if(this.m_tempNewFeature)
					{
						this.removeTempNewGraphic();
					}
					applyEditsComplete();
				}
				else if(this.m_undoRedoAddDeleteOperation)
				{
					if(this.m_redoAddOperation)
					{
						this.m_redoAddOperation = false;
						this.m_undoRedoAddDeleteOperation = false;
						this.operationCompleteLabel.text = event.featureEditResults.addResults[0].success?REDO_OPERATION_COMPLETE:REDO_OPERATION_FAILED;
						this.m_undoRedoInProgress = false;
						applyEditsComplete();
					}
					else if(this.m_featuresToBeDeleted.length == 1)
					{
						this.m_undoRedoAddDeleteOperation = false;
						if(this.m_featuresToBeDeleted[0].selectedFeatures.length == 1)
						{
							this.operationCompleteLabel.text = event.featureEditResults.addResults[0].success?UNDO_OPERATION_COMPLETE:UNDO_OPERATION_FAILED;
							this.m_undoRedoInProgress = false;
							applyEditsComplete();
						}
						else
						{
							this.operationCompleteLabel.text = UNDO_OPERATION_COMPLETE;
							k = 0;
							while(k < event.featureEditResults.addResults.length)
							{
								if(!event.featureEditResults.addResults[k].success)
								{
									this.operationCompleteLabel.text = UNDO_OPERATION_FAILED;
									break;
								}
								k++;
							}
							this.m_undoRedoAddDeleteOperation = false;
							this.m_undoRedoInProgress = false;
							applyEditsComplete();
						}
					}
					else
					{
						this.m_countDeleteFeatureLayers++;
						this.operationCompleteLabel.text = UNDO_OPERATION_COMPLETE;
						this.m_featureLayerAddResults.push(
							{
								"featureLayer":event.featureLayer,
								"addResults":event.featureEditResults.addResults
							});
						if(this.m_countDeleteFeatureLayers == this.m_featuresToBeDeleted.length)
						{
							p = 0;
							while(p < this.m_featureLayerAddResults.length)
							{
								j = 0;
								while(j < this.m_featureLayerAddResults[p].addResults.length)
								{
									if(!this.m_featureLayerAddResults[p].addResults[j].success)
									{
										this.operationCompleteLabel.text = UNDO_OPERATION_FAILED;
										break;
									}
									j++;
								}
								if(this.operationCompleteLabel.text == UNDO_OPERATION_FAILED)
								{
									break;
								}
								p++;
							}
							this.m_undoRedoAddDeleteOperation = false;
							this.m_undoRedoInProgress = false;
							applyEditsComplete();
						}
					}
					
				}
				else if(this.m_lastUpdateOperation == "redo split geometry")
				{
					this.m_arrUndoCutOperation.push(
						{
							"featureLayer":event.featureLayer,
							"featureEditResults":event.featureEditResults
						});
					redoCutComplete();
				}
				else if((this.m_lastUpdateOperation == "undo merge geometry") || (this.m_lastUpdateOperation == "redo merge geometry"))
				{
					this.m_arrUndoRedoMergeOperation.push(event.featureEditResults);
					undoRedoMergeComplete();
				}
				
				
				
			}
			if((event.featureEditResults.deleteResults) && (event.featureEditResults.deleteResults.length > 0))
			{
				if(this.m_lastUpdateOperation == "undo split geometry")
				{
					this.m_arrUndoCutOperation.push(
						{
							"featureLayer":event.featureLayer,
							"featureEditResults":event.featureEditResults
						});
					undoCutComplete();
				}
				else if((this.m_lastUpdateOperation == "undo merge geometry") || (this.m_lastUpdateOperation == "redo merge geometry"))
				{
					this.m_arrUndoRedoMergeOperation.push(event.featureEditResults);
					undoRedoMergeComplete();
				}
				else if(this.m_undoRedoAddDeleteOperation)
				{
					this.m_undoRedoAddDeleteOperation = false;
					if(this.m_undoAddOperation)
					{
						this.m_undoAddOperation = false;
						this.m_editGraphic = null;
						this.operationCompleteLabel.text = event.featureEditResults.deleteResults[0].success?UNDO_OPERATION_COMPLETE:UNDO_OPERATION_FAILED;
					}
					else
					{
						this.operationCompleteLabel.text = event.featureEditResults.deleteResults[0].success?REDO_OPERATION_COMPLETE:REDO_OPERATION_FAILED;
					}
					this.m_undoRedoInProgress = false;
					applyEditsComplete();
				}
				else
				{
					isOneFeatureSelected = function():void
					{
						var atleastOneFeatureSelected:* = false;
						var i:Number = 0;
						while(i < m_featureLayers.length)
						{
							if(FeatureLayer(m_featureLayers[i]).selectedFeatures.length > 0)
							{
								atleastOneFeatureSelected = true;
								break;
							}
							i++;
						}
						if(!atleastOneFeatureSelected)
						{
							m_editGraphic = null;
							if(m_toolbarVisible)
							{
								deleteButton.enabled = false;
							}
							if(m_isEdit)
							{
								m_isEdit = false;
								m_editTool.deactivate();
								removeEditToolEventListeners();
							}
							if(map)
							{
								map.infoWindow.hide();
							}
						}
					};
					if((this.m_featuresToBeDeleted) && (this.m_featuresToBeDeleted.length > 0))
					{
						if(this.m_featuresToBeDeleted.length == 1)
						{
							this.m_undoRedoAddDeleteOperation = false;
							if(this.m_featuresToBeDeleted[0].selectedFeatures.length == 1)
							{
								if(event.featureEditResults.deleteResults[0].success)
								{
									this.operationCompleteLabel.text = DELETE_FEATURE_OPERATION_COMPLETE;
									this.m_editGraphic = null;
									this.m_isEdit = false;
									this.m_editTool.deactivate();
									this.removeEditToolEventListeners();
									if(this.map)
									{
										this.map.infoWindow.hide();
									}
								}
								else
								{
									this.operationCompleteLabel.text = DELETE_FEATURE_OPERATION_FAILED;
								}
								applyEditsComplete();
							}
							else
							{
								this.operationCompleteLabel.text = DELETE_FEATURES_OPERATION_COMPLETE;
								d = 0;
								while(d < event.featureEditResults.deleteResults.length)
								{
									if(!event.featureEditResults.deleteResults[d].success)
									{
										this.operationCompleteLabel.text = DELETE_FEATURES_OPERATION_FAILED;
										break;
									}
									d++;
								}
								this.m_undoRedoAddDeleteOperation = false;
								applyEditsComplete();
								if(this.operationCompleteLabel.text == DELETE_FEATURES_OPERATION_COMPLETE)
								{
									isOneFeatureSelected();
								}
							}
						}
						else
						{
							this.m_countDeleteFeatureLayers++;
							this.operationCompleteLabel.text = DELETE_FEATURES_OPERATION_COMPLETE;
							this.m_featureLayerDeleteResults.push(
								{
									"featureLayer":event.featureLayer,
									"deleteResults":event.featureEditResults.deleteResults
								});
							if(this.m_countDeleteFeatureLayers == this.m_featuresToBeDeleted.length)
							{
								a = 0;
								while(a < this.m_featureLayerDeleteResults.length)
								{
									b = 0;
									while(b < this.m_featureLayerDeleteResults[a].deleteResults.length)
									{
										if(!this.m_featureLayerDeleteResults[a].deleteResults[b].success)
										{
											this.operationCompleteLabel.text = DELETE_FEATURES_OPERATION_FAILED;
											break;
										}
										b++;
									}
									if(this.operationCompleteLabel.text == DELETE_FEATURES_OPERATION_FAILED)
									{
										break;
									}
									a++;
								}
								if(this.operationCompleteLabel.text == DELETE_FEATURES_OPERATION_COMPLETE)
								{
									isOneFeatureSelected();
								}
								this.m_undoRedoAddDeleteOperation = false;
								applyEditsComplete();
							}
						}
					}
					if(this.m_toolbarVisible)
					{
						this.mergeReshapeButtonHandler();
						this.checkForSelection();
						this.updateDeleteButtonBasedOnSelection();
					}
				}
				
				
			}
			if((event.featureEditResults.updateResults) && (event.featureEditResults.updateResults.length > 0))
			{
				if((this.m_lastUpdateOperation == "edit geometry") || (this.m_lastUpdateOperation == "edit attribute") || (this.m_lastUpdateOperation == "reshape geometry"))
				{
					this.operationCompleteLabel.text = event.featureEditResults.updateResults[0].success?UPDATE_FEATURE_OPERATION_COMPLETE:UPDATE_FEATURE_OPERATION_FAILED;
					applyEditsComplete();
					if(this.m_toolbarVisible)
					{
						this.mergeReshapeButtonHandler();
						this.checkForSelection();
					}
					if(this.m_lastUpdateOperation == "edit geometry")
					{
						callLater(this.updateUndoRedoButtons);
						callLater(this.activateEditToolAfterNormalize);
					}
					this.m_lastUpdateOperation = "";
				}
				if((this.m_lastUpdateOperation == "undo edit geometry") || (this.m_lastUpdateOperation == "undo edit attribute") || (this.m_lastUpdateOperation == "undo reshape geometry"))
				{
					this.m_lastUpdateOperation = "";
					this.operationCompleteLabel.text = event.featureEditResults.updateResults[0].success?UNDO_OPERATION_COMPLETE:UNDO_OPERATION_FAILED;
					this.m_undoRedoInProgress = false;
					applyEditsComplete();
					if(this.m_toolbarVisible)
					{
						this.mergeReshapeButtonHandler();
						this.checkForSelection();
					}
				}
				if((this.m_lastUpdateOperation == "redo edit geometry") || (this.m_lastUpdateOperation == "redo edit attribute") || (this.m_lastUpdateOperation == "redo reshape geometry"))
				{
					this.m_lastUpdateOperation = "";
					this.operationCompleteLabel.text = event.featureEditResults.updateResults[0].success?REDO_OPERATION_COMPLETE:REDO_OPERATION_FAILED;
					this.m_undoRedoInProgress = false;
					applyEditsComplete();
					if(this.m_toolbarVisible)
					{
						this.mergeReshapeButtonHandler();
						this.checkForSelection();
					}
				}
				if(this.m_lastUpdateOperation == "undo split geometry")
				{
					this.m_arrUndoCutOperation.push(
						{
							"featureLayer":event.featureLayer,
							"featureEditResults":event.featureEditResults
						});
					undoCutComplete();
				}
				if(this.m_lastUpdateOperation == "redo split geometry")
				{
					this.m_arrUndoCutOperation.push(
						{
							"featureLayer":event.featureLayer,
							"featureEditResults":event.featureEditResults
						});
					redoCutComplete();
				}
			}
		}
		
		private function featureLayer_selectionClearHandler(event:FeatureLayerEvent) : void {
			if(this.map)
			{
				this.map.infoWindow.hide();
			}
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			CursorManager.removeCursor(CursorManager.currentCursorID);
			if((this.m_isEdit) && (!this.m_editClearSelection))
			{
				this.m_isEdit = false;
				this.m_editGraphic = null;
			}
			if(this.m_toolbarVisible)
			{
				this.m_drawTool.deactivate();
				this.mergeButton.enabled = false;
				this.reshapeButton.enabled = false;
				if(this.cutButton.selected)
				{
					this.cutButton.selected = false;
					this.cutReshapeButtonHandler();
				}
				if(this.m_featuresSelected)
				{
					this.m_featuresSelected = false;
					invalidateSkinState();
				}
			}
		}
		
		private function featureLayer_selectionCompleteHandler(event:FeatureLayerEvent) : void {
			if(this.m_toolbarVisible)
			{
				if((!this.m_featuresSelected) && (event.featureLayer.selectedFeatures.length > 0))
				{
					this.m_featuresSelected = true;
					invalidateSkinState();
				}
				this.mergeReshapeButtonHandler();
			}
			switch(event.selectionMethod)
			{
				case FeatureLayer.SELECTION_NEW:
					this.selectionNewHandler(event);
					break;
				case FeatureLayer.SELECTION_ADD:
					this.selectionAddHandler(event);
					break;
				case FeatureLayer.SELECTION_SUBTRACT:
					this.selectionSubtractHandler(event);
					break;
			}
			if(this.m_toolbarVisible)
			{
				this.updateDeleteButtonBasedOnSelection();
			}
		}
		
		private function selectionAddHandler(event:FeatureLayerEvent) : void {
			if((event.features) && (event.features.length > 0))
			{
				if(this.m_isEdit)
				{
					this.m_isEdit = false;
					if((this.m_toolbarVisible) && (!this.m_featuresSelected))
					{
						this.m_featuresSelected = true;
						invalidateSkinState();
					}
				}
			}
			else if((this.m_toolbarVisible) && (this.m_featuresSelected))
			{
				this.m_featuresSelected = false;
				invalidateSkinState();
			}
			
		}
		
		private function selectionSubtractHandler(event:FeatureLayerEvent) : void {
			if((event.features) && (event.features.length > 0))
			{
				this.m_attributeInspector.refresh();
				if(this.map)
				{
					this.map.infoWindow.hide();
				}
				this.m_editTool.deactivate();
				this.removeEditToolEventListeners();
				CursorManager.removeCursor(CursorManager.currentCursorID);
				if(this.m_toolbarVisible)
				{
					this.checkForSelection();
				}
				if(!this.m_featuresSelected)
				{
					if((this.m_isEdit) && (!this.m_editClearSelection))
					{
						this.m_isEdit = false;
						this.m_editGraphic = null;
					}
				}
			}
		}
		
		private function selectionNewHandler(event:FeatureLayerEvent) : void {
			if((!event.features) || (event.features.length == 0))
			{
				if(!this.m_selectionMode)
				{
					if(this.m_isEdit)
					{
						this.m_isEdit = false;
						this.m_editGraphic = null;
					}
					if((this.m_toolbarVisible) && (this.m_featuresSelected))
					{
						this.m_featuresSelected = false;
						invalidateSkinState();
					}
					if(this.map)
					{
						this.map.infoWindow.hide();
					}
					this.m_editTool.deactivate();
					this.removeEditToolEventListeners();
				}
			}
			else if(this.m_isEdit)
			{
				this.m_isEdit = false;
				if(this.map)
				{
					this.map.infoWindow.show(this.m_editPoint);
					this.map.infoWindow.closeButton.addEventListener(MouseEvent.MOUSE_DOWN,this.infoWindowCloseButtonMouseDownHandler);
				}
				if((this.m_toolbarVisible) && (!this.m_featuresSelected))
				{
					this.m_featuresSelected = true;
					invalidateSkinState();
				}
			}
			
		}
		
		private function checkForSelection() : void {
			if(this.m_featuresSelected)
			{
				this.m_featuresSelected = false;
				invalidateSkinState();
			}
			var i:Number = 0;
			while(i < this.m_featureLayers.length)
			{
				if(FeatureLayer(this.m_featureLayers[i]).selectedFeatures.length > 0)
				{
					if(!this.m_featuresSelected)
					{
						this.m_featuresSelected = true;
						invalidateSkinState();
						break;
					}
				}
				i++;
			}
		}
		
		private function updateDeleteButtonBasedOnSelection() : void {
			var atleastOneFeatureCanBeDeleted:* = false;
			var featureLayer:FeatureLayer = null;
			var j:* = 0;
			var feature:Graphic = null;
			var i:int = 0;
			while(i < this.m_featureLayers.length)
			{
				featureLayer = this.m_featureLayers[i];
				if((featureLayer.selectedFeatures.length > 0) && (this.checkIfDeleteIsAllowed(featureLayer)))
				{
					j = 0;
					while(j < featureLayer.selectedFeatures.length)
					{
						feature = featureLayer.selectedFeatures[j];
						if(featureLayer.isDeleteAllowed(feature))
						{
							atleastOneFeatureCanBeDeleted = true;
							break;
						}
						j++;
					}
					if(atleastOneFeatureCanBeDeleted)
					{
						break;
					}
					i++;
				}
				else
				{
					i++;
				}
			}
			if(this.m_toolbarVisible)
			{
				this.deleteButton.enabled = atleastOneFeatureCanBeDeleted;
			}
		}
		
		private function mergeReshapeButtonHandler() : void {
			var selectedFeature:Graphic = null;
			var selectedFeatures:Array = [];
			var i:Number = 0;
			while(i < this.m_featureLayers.length)
			{
				if((FeatureLayer(this.m_featureLayers[i]).selectedFeatures.length > 0) && (this.checkIfGeometryUpdateIsAllowed(FeatureLayer(this.m_featureLayers[i]))))
				{
					for each(selectedFeature in FeatureLayer(this.m_featureLayers[i]).selectedFeatures)
					{
						selectedFeatures.push(selectedFeature);
					}
				}
				i++;
			}
			this.reshapeButton.enabled = (selectedFeatures.length == 1) && (this.m_updateGeometryEnabled)?true:false;
			var polygonCount:Number = 0;
			var j:Number = 0;
			while(j < selectedFeatures.length)
			{
				if(selectedFeatures[j].geometry is Polygon)
				{
					polygonCount++;
					if(polygonCount >= 2)
					{
						break;
					}
				}
				j++;
			}
			this.mergeButton.enabled = (polygonCount >= 2) && (this.m_updateGeometryEnabled)?true:false;
		}
		
		private function cutReshapeButtonHandler() : void {
			if(this.cutButton.selected)
			{
				this.m_cutInProgress = false;
				this.cutButton.selected = false;
			}
			if(this.reshapeButton.selected)
			{
				this.m_reshapeInProgress = false;
				this.reshapeButton.selected = false;
			}
			this.m_creationInProgress = false;
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.m_drawTool.deactivate();
		}
		
		private function featureLayer_faultHandler(event:FaultEvent) : void {
			if(this.m_applyingEdits)
			{
				this.m_applyingEdits = false;
				invalidateSkinState();
			}
			if(this.m_tempNewFeature)
			{
				this.removeTempNewGraphic();
			}
			dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,event.fault));
		}
		
		private function attributeInspector_activeFeatureChangeHandler(event:Event=null) : void {
			var activeFeature:Graphic = null;
			var activeFeatureLayer:FeatureLayer = null;
			if(this.m_tempNewFeature)
			{
				return;
			}
			if(!this.m_attributesSaved)
			{
				if(this.m_editGraphic)
				{
					this.saveUnsavedAttributes(this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer));
				}
			}
			else
			{
				this.m_attributesSaved = false;
			}
			this.m_attributeInspector.deleteButtonVisible = this.deleteEnabled;
			this.m_attributeInspector.updateEnabled = this.updateAttributesEnabled;
			if(this.m_attributeInspector.activeFeatureIndex != -1)
			{
				if((this.m_attributeInspector.activeFeature) && (this.m_attributeInspector.activeFeature.geometry) && (this.m_attributeInspector.activeFeature.graphicsLayer))
				{
					activeFeature = this.m_attributeInspector.activeFeature;
					activeFeatureLayer = FeatureLayer(activeFeature.graphicsLayer);
					if(this.m_isEdit)
					{
						this.m_editGraphic = activeFeature;
						if(this.m_toolbarVisible)
						{
							this.deleteButton.enabled = activeFeatureLayer.isDeleteAllowed(activeFeature);
						}
						if((!(this.map.infoWindowContent is AttributeInspector)) || (!(this.map.infoWindowContent === this.m_attributeInspector)))
						{
							this.map.infoWindowContent = this.m_attributeInspector;
						}
						if((this.m_updateGeometryEnabled) && (this.checkIfGeometryUpdateIsAllowed(activeFeatureLayer)) && (activeFeatureLayer.isUpdateAllowed(this.m_editGraphic)))
						{
							this.m_editTool.deactivate();
							this.removeEditToolEventListeners();
							this.m_editTool.activate(EditTool.MOVE | EditTool.EDIT_VERTICES,[this.m_editGraphic]);
							this.addEditToolEventListeners();
						}
						this.updateAttributeInspector(activeFeatureLayer,activeFeature);
						this.showAttributeInspector(this.m_editGraphic);
					}
				}
			}
		}
		
		private function templatePicker_selectedTemplateChangeHandler(event:TemplatePickerEvent) : void {
			var symbol:Symbol = null;
			var defaultMarkerSymbol:SimpleMarkerSymbol = null;
			var defaultMarkerSymbol1:SimpleMarkerSymbol = null;
			var defaultLineSymbol:SimpleLineSymbol = null;
			var polylineDrawingToolString:String = null;
			var defaultFillSymbol:SimpleFillSymbol = null;
			var polygonDrawingToolString:String = null;
			if(!this.map)
			{
				return;
			}
			this.m_drawStart = false;
			this.m_lastActiveEdit = null;
			if(event.selectedTemplate)
			{
				if(this.m_tempNewFeature)
				{
					this.saveTempNewFeature();
				}
				this.m_currentSelectedTemplateFeatureLayerChanged = false;
				if(this.m_currentSelectedTemplateFeatureLayer !== event.selectedTemplate.featureLayer)
				{
					this.m_currentSelectedTemplateFeatureLayer = event.selectedTemplate.featureLayer;
					this.m_currentSelectedTemplateFeatureLayerChanged = true;
				}
				if(this.m_showTemplateSwatchOnCursor)
				{
					this.m_map.removeEventListener(MouseEvent.MOUSE_OVER,this.mouseOverHandler);
					this.m_map.removeEventListener(MouseEvent.MOUSE_OUT,this.mouseOutHandler);
					this.m_map.addEventListener(MouseEvent.MOUSE_OVER,this.mouseOverHandler);
					this.m_map.addEventListener(MouseEvent.MOUSE_OUT,this.mouseOutHandler);
				}
				this.m_creationInProgress = true;
				this.m_graphicRemoved = false;
				this.m_templateSelected = true;
				if(this.m_toolbarVisible)
				{
					invalidateSkinState();
				}
				this.m_createGeometryType = event.selectedTemplate.featureLayer.layerDetails.geometryType;
				dispatchEvent(new Event("createGeometryTypeChanged"));
				this.m_drawTool.deactivate();
				this.m_editTool.deactivate();
				this.removeEditToolEventListeners();
				this.clearSelection();
				switch(event.selectedTemplate.featureLayer.layerDetails.geometryType)
				{
					case Geometry.MAPPOINT:
						if(event.selectedTemplate.featureLayer.renderer)
						{
							symbol = event.selectedTemplate.featureLayer.renderer.getSymbol(event.selectedTemplate.featureTemplate.prototype);
							if(symbol)
							{
								this.m_drawTool.markerSymbol = symbol;
							}
						}
						else if(event.selectedTemplate.featureLayer.symbol)
						{
							this.m_drawTool.markerSymbol = event.selectedTemplate.featureLayer.symbol;
						}
						else
						{
							this.m_drawTool.markerSymbol = new SimpleMarkerSymbol();
						}
						
						if(this.m_showTemplateSwatchOnCursor)
						{
							if((!this.m_drawTool.markerSymbol) || (this.m_drawTool.markerSymbol is CompositeSymbol))
							{
								defaultMarkerSymbol = new SimpleMarkerSymbol();
								this.m_templateSwatch = defaultMarkerSymbol.createSwatch(50,50);
							}
							else
							{
								this.m_templateSwatch = this.m_drawTool.markerSymbol.createSwatch(50,50);
							}
							this.addSwatchToStage();
						}
						if(!this.m_toolbarVisible)
						{
							this.m_drawTool.activate(DrawTool.MAPPOINT);
						}
						else
						{
							callLater(this.resetDrawingDropDownList);
						}
						break;
					case Geometry.MULTIPOINT:
						if(event.selectedTemplate.featureLayer.renderer)
						{
							symbol = event.selectedTemplate.featureLayer.renderer.getSymbol(event.selectedTemplate.featureTemplate.prototype);
							if(symbol)
							{
								this.m_drawTool.markerSymbol = symbol;
							}
						}
						else if(event.selectedTemplate.featureLayer.symbol)
						{
							this.m_drawTool.markerSymbol = event.selectedTemplate.featureLayer.symbol;
						}
						else
						{
							this.m_drawTool.markerSymbol = new SimpleMarkerSymbol();
						}
						
						if(this.m_showTemplateSwatchOnCursor)
						{
							if((!this.m_drawTool.markerSymbol) || (this.m_drawTool.markerSymbol is CompositeSymbol))
							{
								defaultMarkerSymbol1 = new SimpleMarkerSymbol();
								this.m_templateSwatch = defaultMarkerSymbol1.createSwatch(50,50);
							}
							else
							{
								this.m_templateSwatch = this.m_drawTool.markerSymbol.createSwatch(50,50);
							}
							this.addSwatchToStage();
						}
						if(!this.m_toolbarVisible)
						{
							this.m_drawTool.activate(DrawTool.MULTIPOINT);
						}
						else
						{
							callLater(this.resetDrawingDropDownList);
						}
						break;
					case Geometry.POLYLINE:
						if(event.selectedTemplate.featureLayer.renderer)
						{
							symbol = event.selectedTemplate.featureLayer.renderer.getSymbol(event.selectedTemplate.featureTemplate.prototype);
							if(symbol)
							{
								this.m_drawTool.lineSymbol = symbol;
							}
						}
						else if(event.selectedTemplate.featureLayer.symbol)
						{
							this.m_drawTool.lineSymbol = event.selectedTemplate.featureLayer.symbol;
						}
						else
						{
							this.m_drawTool.lineSymbol = new SimpleLineSymbol();
						}
						
						if(this.m_showTemplateSwatchOnCursor)
						{
							if((!this.m_drawTool.lineSymbol) || (this.m_drawTool.lineSymbol is CompositeSymbol))
							{
								defaultLineSymbol = new SimpleLineSymbol();
								this.m_templateSwatch = defaultLineSymbol.createSwatch(50,50);
							}
							else
							{
								this.m_templateSwatch = this.m_drawTool.lineSymbol.createSwatch(50,50,event.selectedTemplate.featureTemplate.drawingTool);
							}
							this.addSwatchToStage();
						}
						if(!this.m_toolbarVisible)
						{
							if(this.createOptions)
							{
								this.m_drawTool.activate(this.createOptions.polylineDrawTools[0]);
							}
							else if(event.selectedTemplate.featureTemplate.drawingTool)
							{
								switch(event.selectedTemplate.featureTemplate.drawingTool)
								{
									case FeatureTemplate.TOOL_LINE:
										this.m_drawTool.activate(DrawTool.POLYLINE);
										break;
									case FeatureTemplate.TOOL_CIRCLE:
									case FeatureTemplate.TOOL_ELLIPSE:
									case FeatureTemplate.TOOL_RECTANGLE:
									case FeatureTemplate.TOOL_FREEHAND:
										this.m_drawTool.activate(DrawTool.FREEHAND_POLYLINE);
										break;
								}
							}
							else
							{
								this.m_drawTool.activate(DrawTool.POLYLINE);
							}
							
						}
						else
						{
							this.drawDropDownList.selectedIndex = -1;
							if(this.createOptions)
							{
								this.drawDropDownList.selectedIndex = this.m_lastPolylineCreateOptionIndex;
							}
							else if(event.selectedTemplate.featureTemplate.drawingTool)
							{
								if(this.m_currentSelectedTemplateFeatureLayerChanged)
								{
									polylineDrawingToolString = "";
									switch(event.selectedTemplate.featureTemplate.drawingTool)
									{
										case FeatureTemplate.TOOL_LINE:
											polylineDrawingToolString = "pointToPointLine";
											break;
										case FeatureTemplate.TOOL_CIRCLE:
										case FeatureTemplate.TOOL_ELLIPSE:
										case FeatureTemplate.TOOL_RECTANGLE:
										case FeatureTemplate.TOOL_FREEHAND:
											polylineDrawingToolString = "freehandLine";
											break;
									}
									callLater(this.checkDrawingToolInfo,[polylineDrawingToolString,true]);
								}
								else
								{
									this.drawDropDownList.selectedIndex = this.m_lastPolylineCreateOptionIndex;
								}
							}
							else
							{
								this.drawDropDownList.selectedIndex = this.m_lastPolylineCreateOptionIndex;
							}
							
						}
						break;
					case Geometry.POLYGON:
						if(event.selectedTemplate.featureLayer.renderer)
						{
							symbol = event.selectedTemplate.featureLayer.renderer.getSymbol(event.selectedTemplate.featureTemplate.prototype);
							if(symbol)
							{
								this.m_drawTool.fillSymbol = symbol;
							}
						}
						else if(event.selectedTemplate.featureLayer.symbol)
						{
							this.m_drawTool.fillSymbol = event.selectedTemplate.featureLayer.symbol;
						}
						else
						{
							this.m_drawTool.fillSymbol = new SimpleFillSymbol();
						}
						
						if(this.m_showTemplateSwatchOnCursor)
						{
							if((!this.m_drawTool.fillSymbol) || (this.m_drawTool.fillSymbol is CompositeSymbol))
							{
								defaultFillSymbol = new SimpleFillSymbol();
								this.m_templateSwatch = defaultFillSymbol.createSwatch(25,25);
							}
							else
							{
								this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,event.selectedTemplate.featureTemplate.drawingTool);
							}
							this.addSwatchToStage();
						}
						if(!this.m_toolbarVisible)
						{
							if(this.createOptions)
							{
								this.m_drawTool.activate(this.createOptions.polygonDrawTools[0]);
							}
							else if(event.selectedTemplate.featureTemplate.drawingTool)
							{
								switch(event.selectedTemplate.featureTemplate.drawingTool)
								{
									case FeatureTemplate.TOOL_AUTO_COMPLETE_FREEHAND_POLYGON:
									case FeatureTemplate.TOOL_FREEHAND:
										this.m_drawTool.activate(DrawTool.FREEHAND_POLYGON);
										break;
									case FeatureTemplate.TOOL_CIRCLE:
										this.m_drawTool.activate(DrawTool.CIRCLE);
										break;
									case FeatureTemplate.TOOL_ELLIPSE:
										this.m_drawTool.activate(DrawTool.ELLIPSE);
										break;
									case FeatureTemplate.TOOL_POLYGON:
									case FeatureTemplate.TOOL_AUTO_COMPLETE_POLYGON:
										this.m_drawTool.activate(DrawTool.POLYGON);
										break;
									case FeatureTemplate.TOOL_RECTANGLE:
										this.m_drawTool.activate(DrawTool.EXTENT);
										break;
								}
							}
							else
							{
								this.m_drawTool.activate(DrawTool.POLYGON);
							}
							
						}
						else
						{
							this.drawDropDownList.selectedIndex = -1;
							if(this.createOptions)
							{
								this.drawDropDownList.selectedIndex = this.m_lastPolygonCreateOptionIndex;
							}
							else if(event.selectedTemplate.featureTemplate.drawingTool)
							{
								if(this.m_currentSelectedTemplateFeatureLayerChanged)
								{
									polygonDrawingToolString = "";
									switch(event.selectedTemplate.featureTemplate.drawingTool)
									{
										case FeatureTemplate.TOOL_FREEHAND:
											polygonDrawingToolString = "freehandPolygon";
											break;
										case FeatureTemplate.TOOL_CIRCLE:
											polygonDrawingToolString = "circle";
											break;
										case FeatureTemplate.TOOL_ELLIPSE:
											polygonDrawingToolString = "ellipse";
											break;
										case FeatureTemplate.TOOL_POLYGON:
											polygonDrawingToolString = "pointToPointPolygon";
											break;
										case FeatureTemplate.TOOL_AUTO_COMPLETE_FREEHAND_POLYGON:
										case FeatureTemplate.TOOL_AUTO_COMPLETE_POLYGON:
											polygonDrawingToolString = "autoComplete";
											break;
										case FeatureTemplate.TOOL_RECTANGLE:
											polygonDrawingToolString = "extent";
											break;
									}
									callLater(this.checkDrawingToolInfo,[polygonDrawingToolString,false]);
								}
								else
								{
									this.drawDropDownList.selectedIndex = this.m_lastPolygonCreateOptionIndex;
								}
							}
							else
							{
								this.drawDropDownList.selectedIndex = this.m_lastPolygonCreateOptionIndex;
							}
							
						}
						break;
				}
				if(this.m_templateSwatch)
				{
					this.m_templateSwatch.filters = [new DropShadowFilter(6,45,0,0.4)];
				}
			}
			else
			{
				this.m_creationInProgress = false;
				this.m_templateSelected = false;
				if(this.m_templateSwatch)
				{
					this.m_templateSwatch.visible = false;
				}
				this.m_map.removeEventListener(MouseEvent.MOUSE_OVER,this.mouseOverHandler);
				this.m_map.removeEventListener(MouseEvent.MOUSE_OUT,this.mouseOutHandler);
				if(this.m_toolbarVisible)
				{
					this.drawDropDownList.selectedIndex = -1;
					invalidateSkinState();
				}
				this.m_drawTool.deactivate();
				this.m_drawTool.fillSymbol = this.m_selectionExtentSymbol;
			}
		}
		
		private function resetDrawingDropDownList() : void {
			this.drawDropDownList.selectedIndex = -1;
			this.drawDropDownList.selectedIndex = 0;
		}
		
		private function checkDrawingToolInfo(drawingToolString:String, polylineDrawing:Boolean) : void {
			var i:Number = 0;
			while(i < this.drawDropDownList.dataProvider.length)
			{
				if(drawingToolString == this.drawDropDownList.dataProvider.getItemAt(i).drawId)
				{
					this.drawDropDownList.selectedIndex = i;
					if(polylineDrawing)
					{
						this.m_lastPolygonCreateOptionIndex = i;
					}
					else
					{
						this.m_lastPolylineCreateOptionIndex = i;
					}
					break;
				}
				i++;
			}
		}
		
		private function mouseOverHandler(event:MouseEvent) : void {
			this.m_map.addEventListener(MouseEvent.MOUSE_MOVE,this.mouseMoveHandler);
		}
		
		private function mouseOutHandler(event:MouseEvent) : void {
			this.m_map.removeEventListener(MouseEvent.MOUSE_MOVE,this.mouseMoveHandler);
			if(this.m_templateSwatch)
			{
				this.m_templateSwatch.visible = false;
			}
		}
		
		private function mouseMoveHandler(event:MouseEvent) : void {
			if((this.templatePicker.selectedTemplate) && (!this.m_drawStart))
			{
				if((this.m_showTemplateSwatchOnCursor) && (this.m_templateSwatch))
				{
					this.m_templateSwatch.x = this.templatePicker.selectedTemplate.featureLayer.layerDetails.geometryType == Geometry.POLYGON?event.stageX + 20:event.stageX;
					this.m_templateSwatch.y = this.templatePicker.selectedTemplate.featureLayer.layerDetails.geometryType == Geometry.POLYGON?event.stageY + 20:event.stageY;
					event.updateAfterEvent();
					this.m_templateSwatch.visible = true;
				}
			}
		}
		
		private function addSwatchToStage() : void {
			systemManager.addChild(this.m_templateSwatch);
			this.m_templateSwatch.visible = false;
		}
		
		private function selectionDropDownList_changeHandler(event:IndexChangeEvent) : void {
			if(this.m_tempNewFeature)
			{
				this.saveTempNewFeature();
			}
			if(event.newIndex != -1)
			{
				this.m_graphicRemoved = false;
				if(this.templatePicker.selectedTemplate)
				{
					this.templatePicker.clearSelection();
				}
				this.m_drawTool.deactivate();
				this.m_drawTool.fillSymbol = this.m_selectionExtentSymbol;
				this.m_drawTool.activate(DrawTool.EXTENT);
			}
		}
		
		private function dropDownList_mouseDownHandler(event:MouseEvent) : void {
			if(!this.map)
			{
				return;
			}
			if(this.m_tempNewFeature)
			{
				this.saveTempNewFeature();
			}
			this.cutReshapeButtonHandler();
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.map.infoWindow.hide();
		}
		
		private function clearSelectionButton_clickHandler(event:MouseEvent) : void {
			if(!this.map)
			{
				return;
			}
			this.cutReshapeButtonHandler();
			if(this.m_editClearSelection)
			{
				this.m_editClearSelection = false;
			}
			this.clearSelection();
		}
		
		private function attributeInspector_updateFeatureHandler(event:AttributeInspectorEvent) : void {
			this.m_activeFeatureChangedAttributes.push(
				{
					"field":event.field,
					"oldValue":event.oldValue,
					"newValue":event.newValue
				});
		}
		
		private function attributeInspector_deleteFeatureHandler(event:AttributeInspectorEvent) : void {
			var deletes:Array = null;
			var deleteFeaturesOperation:DeleteOperation = null;
			if(this.m_tempNewFeature)
			{
				this.m_deletingTempGraphic = true;
				this.removeTempNewGraphic();
				this.map.infoWindow.hide();
			}
			else
			{
				deletes = [event.feature];
				event.featureLayer.applyEdits(null,null,deletes,false,new AsyncResponder(this.attributeInspector_editsCompleteHandler,this.attributeInspector_faultHandler));
				this.m_featuresToBeDeleted = [];
				this.m_featuresToBeDeleted.push(
					{
						"selectedFeatures":deletes,
						"featureLayer":this.attributeInspector.activeFeatureLayer
					});
				deleteFeaturesOperation = new DeleteOperation(this.m_featuresToBeDeleted);
				this.m_undoManager.pushUndo(deleteFeaturesOperation);
				callLater(this.updateUndoRedoButtons);
				this.operationStartLabel.text = DELETE_FEATURE_OPERATION_START;
				this.m_applyingEdits = true;
				invalidateSkinState();
			}
		}
		
		private function attributeInspector_saveFeatureHandler(event:AttributeInspectorEvent) : void {
			if(this.m_attributeInspector.isValid)
			{
				if(this.m_tempNewFeature)
				{
					this.addNewFeature(this.m_tempNewFeature,this.m_tempNewFeatureLayer);
				}
				else
				{
					this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
					this.map.infoWindow.hide();
				}
			}
		}
		
		private function drawDropDownList_changeHandler(event:IndexChangeEvent) : void {
			this.pickDrawingOption(event.currentTarget as DropDownList);
		}
		
		private function drawDropDownList_valueCommitHandler(event:FlexEvent) : void {
			this.pickDrawingOption(event.currentTarget as DropDownList);
		}
		
		private function pickDrawingOption(dropDownList:DropDownList) : void {
			this.m_drawTool.deactivate();
			if(dropDownList.selectedItem)
			{
				switch(dropDownList.selectedItem.drawId)
				{
					case "mappoint":
						if((this.templatePicker.selectedTemplate) && (this.templatePicker.selectedTemplate.featureLayer.layerDetails.geometryType == Geometry.MULTIPOINT))
						{
							this.m_drawTool.activate(DrawTool.MULTIPOINT);
						}
						else
						{
							this.m_drawTool.activate(DrawTool.MAPPOINT);
						}
						this.m_templateSwatch = this.m_drawTool.markerSymbol.createSwatch(50,50);
						this.addSwatchToStage();
						break;
					case "freehandLine":
						this.m_drawTool.activate(DrawTool.FREEHAND_POLYLINE);
						this.m_lastPolylineCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.lineSymbol.createSwatch(50,50,FeatureTemplate.TOOL_FREEHAND);
						this.addSwatchToStage();
						break;
					case "line":
						this.m_drawTool.activate(DrawTool.LINE);
						this.m_lastPolylineCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.lineSymbol.createSwatch(50,50,FeatureTemplate.TOOL_LINE);
						this.addSwatchToStage();
						break;
					case "pointToPointLine":
						this.m_drawTool.activate(DrawTool.POLYLINE);
						this.m_lastPolylineCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.lineSymbol.createSwatch(50,50,FeatureTemplate.TOOL_LINE);
						this.addSwatchToStage();
						break;
					case "freehandPolygon":
						this.m_drawTool.activate(DrawTool.FREEHAND_POLYGON);
						this.m_lastPolygonCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_FREEHAND);
						this.addSwatchToStage();
						break;
					case "pointToPointPolygon":
						this.m_drawTool.activate(DrawTool.POLYGON);
						this.m_lastPolygonCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_POLYGON);
						this.addSwatchToStage();
						break;
					case "extent":
						this.m_drawTool.activate(DrawTool.EXTENT);
						this.m_lastPolygonCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_RECTANGLE);
						this.addSwatchToStage();
						break;
					case "circle":
						this.m_drawTool.activate(DrawTool.CIRCLE);
						this.m_lastPolygonCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_CIRCLE);
						this.addSwatchToStage();
						break;
					case "ellipse":
						this.m_drawTool.activate(DrawTool.ELLIPSE);
						this.m_lastPolygonCreateOptionIndex = this.drawDropDownList.selectedIndex;
						this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_ELLIPSE);
						this.addSwatchToStage();
						break;
					case "autoComplete":
						if((this.templatePicker.selectedTemplate) && (this.templatePicker.selectedTemplate.featureTemplate.drawingTool == FeatureTemplate.TOOL_AUTO_COMPLETE_FREEHAND_POLYGON))
						{
							this.m_drawTool.activate(DrawTool.FREEHAND_POLYGON);
							this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_AUTO_COMPLETE_FREEHAND_POLYGON);
							this.addSwatchToStage();
						}
						else
						{
							this.m_drawTool.activate(DrawTool.POLYGON);
							this.m_templateSwatch = this.m_drawTool.fillSymbol.createSwatch(25,25,FeatureTemplate.TOOL_AUTO_COMPLETE_POLYGON);
							this.addSwatchToStage();
						}
						this.m_lastPolygonCreateOptionIndex = this.drawDropDownList.selectedIndex;
						break;
				}
			}
		}
		
		private function drawTool_drawStartHandler(event:DrawEvent) : void {
			this.m_drawStart = true;
			this.m_currentlyDrawnGraphic = event.graphic;
			if(this.m_templateSwatch)
			{
				this.m_templateSwatch.visible = false;
			}
		}
		
		private function drawTool_drawEndHandler(event:DrawEvent) : void {
			var spatialReference:SpatialReference = null;
			var featureLayer1:FeatureLayer = null;
			var extent:Extent = null;
			var arrPoints:Array = null;
			var polygon:Polygon = null;
			var newGraphic:Graphic = null;
			var fault:Fault = null;
			var featureSetArray:Array = null;
			var polygonPolylineFeatureLayerCount:int = 0;
			var queryResultCount:int = 0;
			var cutRequestCount:int = 0;
			var p:Number = NaN;
			var cut_polylineResultHandler:Function = null;
			var cut_polygonResultHandler:Function = null;
			var cut_faultHandler:Function = null;
			var reshapeSelectedFeaturesArray:Array = null;
			var r:Number = NaN;
			var featureArray:Array = null;
			var k:Number = NaN;
			var reshape_resultHandler:Function = null;
			var reshape_faultHandler:Function = null;
			var reshapeFeature:Graphic = null;
			var nGraphic:Graphic = null;
			this.m_creationInProgress = false;
			this.m_drawStart = false;
			this.m_doNotApplyEdits = false;
			spatialReference = FeatureLayer(this.m_featureLayers[0]).map.spatialReference;
			if(!this.m_graphicRemoved)
			{
				if((!this.m_templateSelected) && ((event.graphic.geometry.type == Geometry.EXTENT) || (event.graphic.geometry.type == Geometry.POLYGON)))
				{
					this.m_query = new Query();
					this.m_query.geometry = event.graphic.geometry;
					this.m_query.where = " ";
					for each(featureLayer1 in this.m_featureLayers)
					{
						if((!featureLayer1.visible) || (!featureLayer1.isInScaleRange))
						{
							continue;
						}
						switch(this.selectionDropDownList.selectedItem.selectionName)
						{
							case "newSelection":
								featureLayer1.selectFeatures(this.m_query,"new");
								continue;
							case "addToSelection":
								featureLayer1.selectFeatures(this.m_query,"add");
								continue;
							case "subtractFromSelection":
								featureLayer1.selectFeatures(this.m_query,"subtract");
								continue;
						}
					}
					this.m_drawTool.deactivate();
					this.selectionDropDownList.selectedIndex = -1;
				}
				else if(event.graphic.geometry.type == Geometry.EXTENT)
				{
					extent = event.graphic.geometry as Extent;
					if((!(extent.xmin == extent.xmax)) && (!(extent.ymin == extent.ymax)))
					{
						arrPoints = [new MapPoint(extent.xmin,extent.ymin),new MapPoint(extent.xmin,extent.ymax),new MapPoint(extent.xmax,extent.ymax),new MapPoint(extent.xmax,extent.ymin),new MapPoint(extent.xmin,extent.ymin)];
						polygon = new Polygon();
						polygon.addRing(arrPoints);
						polygon.spatialReference = extent.spatialReference;
						this.m_newFeatureCreated = true;
						newGraphic = this.templatePicker.selectedTemplate.featureTemplate?new Graphic(polygon,null,ObjectUtil.copy(this.templatePicker.selectedTemplate.featureTemplate.prototype.attributes)):new Graphic(polygon);
						this.createApplyEdits(newGraphic);
					}
					else
					{
						this.templatePicker.clearSelection();
					}
				}
				else if(event.graphic.geometry.type == Geometry.POLYGON)
				{
					savePolygon = function(polygon:Polygon):void
					{
						var featureSetArray:Array = null;
						var polygonFeatureLayerCount:Number = NaN;
						var i:Number = NaN;
						var autoComplete_resultHandler:Function = null;
						var autoComplete_faultHandler:Function = null;
						var g:Graphic = null;
						if((m_toolbarVisible) && (drawDropDownList.selectedItem.drawId == "autoComplete") || ((!m_toolbarVisible) && (templatePicker.selectedTemplate.featureTemplate.drawingTool)) && (templatePicker.selectedTemplate.featureTemplate.drawingTool == FeatureTemplate.TOOL_AUTO_COMPLETE_POLYGON))
						{
							query_resultHandler = function(featureSet:FeatureSet):void
							{
								var featureArray:Array = null;
								var count:Number = NaN;
								var feature:Graphic = null;
								var newGraphic:Graphic = null;
								var geometries:Array = null;
								var geometry:Geometry = null;
								var fault:Fault = null;
								featureSetArray.push(featureSet);
								if(featureSetArray.length == polygonFeatureLayerCount)
								{
									featureArray = [];
									count = 0;
									for each(featureSet in featureSetArray)
									{
										if(featureSet.features.length > 0)
										{
											for each(feature in featureSet.features)
											{
												featureArray.push(feature);
											}
										}
										else
										{
											count++;
										}
									}
									if(count == featureSetArray.length)
									{
										m_newFeatureCreated = true;
										newGraphic = templatePicker.selectedTemplate.featureTemplate?new Graphic(polygon,null,ObjectUtil.copy(templatePicker.selectedTemplate.featureTemplate.prototype.attributes)):new Graphic(polygon);
										createApplyEdits(newGraphic);
									}
									else
									{
										geometryServiceAutoComplete = function(geometryService:GeometryService):void
										{
											geometryService.autoComplete(geometries,[polygonToPolyline(polygon)],new Responder(autoComplete_resultHandler,autoComplete_faultHandler));
										};
										geometries = GraphicUtil.getGeometries(featureArray);
										for each(geometry in geometries)
										{
											if(!geometry.spatialReference)
											{
												geometry.spatialReference = spatialReference;
											}
										}
										if(m_geometryService)
										{
											geometryServiceAutoComplete(m_geometryService);
										}
										else if(GeometryServiceSingleton.instance.url)
										{
											geometryServiceAutoComplete(GeometryServiceSingleton.instance);
										}
										else
										{
											templatePicker.clearSelection();
											fault = new Fault(null,ESRIMessageCodes.formatMessage(ESRIMessageCodes.GEOMETRYSERVICE_REQUIRED));
											dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
										}
										
									}
								}
							};
							query_faultHandler = function(fault:Fault):void
							{
							};
							autoComplete_resultHandler = function(result:Object):void
							{
								var geometry:Geometry = null;
								var graphics:Array = [];
								for each(geometry in result)
								{
									if(templatePicker.selectedTemplate.featureTemplate)
									{
										graphics.push(new Graphic(geometry,null,ObjectUtil.copy(templatePicker.selectedTemplate.featureTemplate.prototype.attributes)));
									}
									else
									{
										graphics.push(new Graphic(geometry));
									}
								}
								m_newFeatureCreated = true;
								createApplyEdits(graphics[0] as Graphic);
							};
							autoComplete_faultHandler = function(fault:Fault):void
							{
							};
							m_query = new Query();
							m_query.geometry = polygon;
							featureSetArray = [];
							polygonFeatureLayerCount = 0;
							i = 0;
							while(i < m_featureLayers.length)
							{
								if(!((!FeatureLayer(m_featureLayers[i]).visible) || (!FeatureLayer(m_featureLayers[i]).isInScaleRange)))
								{
									if(FeatureLayer(m_featureLayers[i]).layerDetails.geometryType == Geometry.POLYGON)
									{
										polygonFeatureLayerCount++;
										FeatureLayer(m_featureLayers[i]).queryFeatures(m_query,new Responder(query_resultHandler,query_faultHandler));
									}
								}
								i++;
							}
						}
						else
						{
							m_newFeatureCreated = true;
							g = templatePicker.selectedTemplate.featureTemplate?new Graphic(polygon,null,ObjectUtil.copy(templatePicker.selectedTemplate.featureTemplate.prototype.attributes)):new Graphic(polygon);
							createApplyEdits(g);
						}
					};
					if(GeometryUtil.polygonSelfIntersecting(Polygon(event.graphic.geometry)))
					{
						geometryServiceSimplify = function(geometryService:GeometryService):void
						{
							var simplify_resultHandler:Function = null;
							var simplify_faultHandler:Function = null;
							simplify_resultHandler = function(result:Object):void
							{
								savePolygon(Polygon(result[0]));
							};
							simplify_faultHandler = function(fault:Fault):void
							{
								templatePicker.clearSelection();
								dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
							};
							geometryService.simplify([event.graphic.geometry],new Responder(simplify_resultHandler,simplify_faultHandler));
						};
						if(this.m_geometryService)
						{
							geometryServiceSimplify(this.m_geometryService);
						}
						else if(GeometryServiceSingleton.instance.url)
						{
							geometryServiceSimplify(GeometryServiceSingleton.instance);
						}
						else
						{
							fault = new Fault(null,ESRIMessageCodes.formatMessage(ESRIMessageCodes.GEOMETRYSERVICE_REQUIRED));
							dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
							this.templatePicker.clearSelection();
						}
						
					}
					else
					{
						savePolygon(Polygon(event.graphic.geometry));
					}
				}
				else if((event.graphic.geometry.type == Geometry.POLYLINE) && (this.m_cutInProgress))
				{
					query_resultHandler = function(featureSet:FeatureSet, token:Object=null):void
					{
						queryResultCount++;
						featureSetArray.push(
							{
								"featureSet":featureSet,
								"featureLayer":token
							});
						startCut();
					};
					query_faultHandler = function(fault:Fault, token:Object=null):void
					{
						queryResultCount++;
						templatePicker.clearSelection();
						startCut();
					};
					startCut = function():void
					{
						var count:Number = NaN;
						var i:Number = NaN;
						var feature:Graphic = null;
						var cutFault:Fault = null;
						if(queryResultCount == polygonPolylineFeatureLayerCount)
						{
							m_cutQueryFeatureArray = [];
							count = 0;
							i = 0;
							while(i < featureSetArray.length)
							{
								if(featureSetArray[i].featureSet.features.length > 0)
								{
									for each(feature in featureSetArray[i].featureSet.features)
									{
										m_cutQueryFeatureArray.push(
											{
												"feature":feature,
												"featureLayer":featureSetArray[i].featureLayer
											});
									}
								}
								else
								{
									count++;
								}
								i++;
							}
							if(count == featureSetArray.length)
							{
								m_cutInProgress = false;
								cutButton.selected = false;
							}
							else
							{
								geometryServiceCut = function(geometryService:GeometryService):void
								{
									m_polylinePolygonCutResultArray = [];
									var polylineGeometries:Array = [];
									var polylineQueryFeatureArray:Array = [];
									var polygonGeometries:Array = [];
									var polygonQueryFeatureArray:Array = [];
									var j:Number = 0;
									while(j < m_cutQueryFeatureArray.length)
									{
										if(!m_cutQueryFeatureArray[j].feature.geometry.spatialReference)
										{
											m_cutQueryFeatureArray[j].feature.geometry.spatialReference = spatialReference;
										}
										if(m_cutQueryFeatureArray[j].feature.geometry.type == Geometry.POLYLINE)
										{
											polylineGeometries.push(m_cutQueryFeatureArray[j].feature.geometry);
											polylineQueryFeatureArray.push(m_cutQueryFeatureArray[j]);
										}
										else if(m_cutQueryFeatureArray[j].feature.geometry.type == Geometry.POLYGON)
										{
											polygonGeometries.push(m_cutQueryFeatureArray[j].feature.geometry);
											polygonQueryFeatureArray.push(m_cutQueryFeatureArray[j]);
										}
										
										j++;
									}
									if(polylineGeometries.length > 0)
									{
										cutRequestCount++;
										geometryService.cut(polylineGeometries,Polyline(event.graphic.geometry),new AsyncResponder(cut_polylineResultHandler,cut_faultHandler,{"featureArray":polylineQueryFeatureArray}));
									}
									if(polygonGeometries.length > 0)
									{
										cutRequestCount++;
										geometryService.cut(polygonGeometries,Polyline(event.graphic.geometry),new AsyncResponder(cut_polygonResultHandler,cut_faultHandler,{"featureArray":polygonQueryFeatureArray}));
									}
								};
								if(m_geometryService)
								{
									geometryServiceCut(m_geometryService);
								}
								else if(GeometryServiceSingleton.instance.url)
								{
									geometryServiceCut(GeometryServiceSingleton.instance);
								}
								else
								{
									m_cutInProgress = false;
									cutButton.selected = false;
									cutFault = new Fault(null,ESRIMessageCodes.formatMessage(ESRIMessageCodes.GEOMETRYSERVICE_REQUIRED));
									dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,cutFault));
								}
								
							}
						}
					};
					cut_polylineResultHandler = function(result:Object, token:Object=null):void
					{
						m_polylinePolygonCutResultArray.push(
							{
								"result":result,
								"featureArray":token.featureArray
							});
						handleCutResult();
					};
					cut_polygonResultHandler = function(result:Object, token:Object=null):void
					{
						m_polylinePolygonCutResultArray.push(
							{
								"result":result,
								"featureArray":token.featureArray
							});
						handleCutResult();
					};
					cut_faultHandler = function(fault:Fault, token:Object=null):void
					{
						m_cutInProgress = false;
						cutButton.selected = false;
						dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
					};
					handleCutResult = function():void
					{
						var arrCutFeatures:Array = null;
						var arrAddsUpdates:Array = null;
						var a:int = 0;
						var featuresArray:Array = null;
						var c:int = 0;
						var b:int = 0;
						if(m_polylinePolygonCutResultArray.length == cutRequestCount)
						{
							cut_selectResult = function(features:Array, token:Object=null):void
							{
								var cutOperation:CutOperation = null;
								var featureEditResultsArray:Array = null;
								var applyEditsResultCount:int = 0;
								var applyEditsFault:Boolean = false;
								var arrDistictFeatureLayers:Array = null;
								var k:Number = NaN;
								var featureLayer:FeatureLayer = null;
								var polylineFeaturesArray:Array = null;
								var polygonFeaturesArray:Array = null;
								var i:Number = NaN;
								var matchFound:Boolean = false;
								var df:int = 0;
								var arrAdds:Array = null;
								var arrUpdates:Array = null;
								var addUpdateObject:Object = null;
								featuresArray.push(
									{
										"feature":features[0],
										"resultGeometries":token.resultGeometries,
										"cutIndexes":token.cutIndexes
									});
								if(featuresArray.length == arrCutFeatures.length)
								{
									addUpdateFeatures = function(arr:Array):void
									{
										var update:* = false;
										var j:* = NaN;
										var i:Number = 0;
										while(i < arr.length)
										{
											update = true;
											j = 0;
											while(j < arr[i].cutIndexes.length)
											{
												if(i == arr[i].cutIndexes[j])
												{
													if(update)
													{
														m_undoCutGeometryArray.push(
															{
																"feature":Graphic(arr[i].feature),
																"geometry":ObjectUtil.copy(Graphic(arr[i].feature).geometry) as Geometry
															});
														m_redoCutGeometryArray.push(
															{
																"feature":Graphic(arr[i].feature),
																"geometry":ObjectUtil.copy(arr[i].resultGeometries[j]) as Geometry
															});
														Graphic(arr[i].feature).geometry = arr[i].resultGeometries[j];
														arrAddsUpdates.push(
															{
																"feature":Graphic(arr[i].feature),
																"featureLayer":Graphic(arr[i].feature).graphicsLayer,
																"update":true
															});
														update = false;
													}
													else
													{
														arrAddsUpdates.push(
															{
																"feature":new Graphic(arr[i].resultGeometries[j],null,ObjectUtil.copy(Graphic(arr[i].feature).attributes)),
																"featureLayer":Graphic(arr[i].feature).graphicsLayer,
																"update":false
															});
													}
												}
												j++;
											}
											i++;
										}
									};
									cut_applyEditsResult = function(featureEditResults:FeatureEditResults, token:Object=null):void
									{
										applyEditsResultCount++;
										featureEditResultsArray.push(
											{
												"featureEditResults":featureEditResults,
												"featureLayer":token
											});
										cutApplyEditsComplete();
										refreshDynamicMapServiceLayer(token as FeatureLayer);
									};
									cut_applyEditsFault = function(fault:Fault, token:Object=null):void
									{
										applyEditsFault = true;
										applyEditsResultCount++;
										cutApplyEditsComplete();
									};
									cutApplyEditsComplete = function():void
									{
										var i:* = NaN;
										var featureLayer:FeatureLayer = null;
										var j:* = NaN;
										var k:* = NaN;
										if(applyEditsResultCount == arrDistictFeatureLayers.length)
										{
											m_cutInProgress = false;
											cutButton.selected = false;
											if(!applyEditsFault)
											{
												operationCompleteLabel.text = m_cutQueryFeatureArray.length == 1?SPLIT_FEATURE_OPERATION_COMPLETE:SPLIT_FEATURES_OPERATION_COMPLETE;
												i = 0;
												while(i < featureEditResultsArray.length)
												{
													featureLayer = featureEditResultsArray[i].featureLayer;
													m_query = new Query();
													m_query.objectIds = [];
													if(featureEditResultsArray[i].featureEditResults.addResults.length > 0)
													{
														j = 0;
														while(j < featureEditResultsArray[i].featureEditResults.addResults.length)
														{
															if(featureEditResultsArray[i].featureEditResults.addResults[j].success)
															{
																m_query.objectIds.push(featureEditResultsArray[i].featureEditResults.addResults[j].objectId);
																FeatureLayer(featureEditResultsArray[i].featureLayer).selectFeatures(m_query,FeatureLayer.SELECTION_ADD);
																j++;
																continue;
															}
															operationCompleteLabel.text = m_cutQueryFeatureArray.length == 1?SPLIT_FEATURE_OPERATION_FAILED:SPLIT_FEATURES_OPERATION_FAILED;
															break;
														}
													}
													if(featureEditResultsArray[i].featureEditResults.updateResults.length > 0)
													{
														k = 0;
														while(k < featureEditResultsArray[i].featureEditResults.updateResults.length)
														{
															if(featureEditResultsArray[i].featureEditResults.updateResults[k].success)
															{
																k++;
																continue;
															}
															operationCompleteLabel.text = m_cutQueryFeatureArray.length == 1?SPLIT_FEATURE_OPERATION_FAILED:SPLIT_FEATURES_OPERATION_FAILED;
															break;
														}
													}
													if((operationCompleteLabel.text == SPLIT_FEATURE_OPERATION_FAILED) || (operationCompleteLabel.text == SPLIT_FEATURES_OPERATION_FAILED))
													{
														break;
													}
													if(m_query.objectIds.length > 0)
													{
														featureLayer.selectFeatures(m_query,FeatureLayer.SELECTION_ADD);
													}
													i++;
												}
											}
											else
											{
												operationCompleteLabel.text = m_cutQueryFeatureArray.length == 1?SPLIT_FEATURE_OPERATION_FAILED:SPLIT_FEATURES_OPERATION_FAILED;
											}
											m_applyingEdits = false;
											invalidateSkinState();
											operationCompleteLabel.includeInLayout = true;
											operationCompleteLabel.visible = true;
											operationCompleteLabel.visible = false;
										}
									};
									if(m_polylinePolygonCutResultArray.length == 2)
									{
										polylineFeaturesArray = [];
										polygonFeaturesArray = [];
										i = 0;
										while(i < featuresArray.length)
										{
											if(Graphic(featuresArray[i].feature).geometry.type == Geometry.POLYLINE)
											{
												polylineFeaturesArray.push(
													{
														"feature":featuresArray[i].feature,
														"resultGeometries":featuresArray[i].resultGeometries,
														"cutIndexes":featuresArray[i].cutIndexes
													});
											}
											else if(Graphic(featuresArray[i].feature).geometry.type == Geometry.POLYGON)
											{
												polygonFeaturesArray.push(
													{
														"feature":featuresArray[i].feature,
														"resultGeometries":featuresArray[i].resultGeometries,
														"cutIndexes":featuresArray[i].cutIndexes
													});
											}
											
											i++;
										}
										addUpdateFeatures(polylineFeaturesArray);
										addUpdateFeatures(polygonFeaturesArray);
									}
									else
									{
										addUpdateFeatures(featuresArray);
									}
									m_undoCutUpdateDeletesArray = arrAddsUpdates;
									cutOperation = new CutOperation(m_undoCutGeometryArray,m_redoCutGeometryArray,arrAddsUpdates);
									m_undoManager.pushUndo(cutOperation);
									callLater(updateUndoRedoButtons);
									featureEditResultsArray = [];
									applyEditsResultCount = 0;
									arrDistictFeatureLayers = [];
									k = 0;
									while(k < arrAddsUpdates.length)
									{
										matchFound = false;
										df = 0;
										while(df < arrDistictFeatureLayers.length)
										{
											if(arrDistictFeatureLayers[df] == arrAddsUpdates[k].featureLayer)
											{
												matchFound = true;
											}
											df++;
										}
										if(!matchFound)
										{
											arrDistictFeatureLayers.push(arrAddsUpdates[k].featureLayer);
										}
										k++;
									}
									for each(featureLayer in arrDistictFeatureLayers)
									{
										arrAdds = [];
										arrUpdates = [];
										for each(addUpdateObject in arrAddsUpdates)
										{
											if(addUpdateObject.featureLayer == featureLayer)
											{
												if(addUpdateObject.update)
												{
													arrUpdates.push(addUpdateObject.feature);
												}
												else
												{
													arrAdds.push(addUpdateObject.feature);
												}
											}
										}
										featureLayer.applyEdits(arrAdds,arrUpdates,null,true,new AsyncResponder(cut_applyEditsResult,cut_applyEditsFault,featureLayer));
									}
									if(!m_applyingEdits)
									{
										m_applyingEdits = true;
										invalidateSkinState();
									}
								}
							};
							cut_selectFault = function(fault:Fault, token:Object=null):void
							{
								m_cutInProgress = false;
								cutButton.selected = false;
							};
							operationStartLabel.text = m_cutQueryFeatureArray.length == 1?SPLIT_FEATURE_OPERATION_START:SPLIT_FEATURES_OPERATION_START;
							arrCutFeatures = [];
							arrAddsUpdates = [];
							a = 0;
							while(a < m_polylinePolygonCutResultArray.length)
							{
								b = 0;
								while(b < m_polylinePolygonCutResultArray[a].featureArray.length)
								{
									arrCutFeatures.push(
										{
											"featureObject":m_polylinePolygonCutResultArray[a].featureArray[b],
											"result":m_polylinePolygonCutResultArray[a].result
										});
									b++;
								}
								a++;
							}
							featuresArray = [];
							c = 0;
							while(c < arrCutFeatures.length)
							{
								if((arrCutFeatures[c].result.geometries) && (arrCutFeatures[c].result.cutIndexes))
								{
									m_query = new Query();
									m_query.objectIds = [arrCutFeatures[c].featureObject.feature.attributes[arrCutFeatures[c].featureObject.featureLayer.layerDetails.objectIdField]];
									FeatureLayer(arrCutFeatures[c].featureObject.featureLayer).selectFeatures(m_query,FeatureLayer.SELECTION_ADD,new AsyncResponder(cut_selectResult,cut_selectFault,
										{
											"resultGeometries":arrCutFeatures[c].result.geometries,
											"cutIndexes":arrCutFeatures[c].result.cutIndexes
										}));
								}
								c++;
							}
						}
					};
					this.m_query = new Query();
					this.m_query.geometry = Polyline(event.graphic.geometry);
					this.m_isEdit = false;
					this.m_drawTool.deactivate();
					featureSetArray = [];
					polygonPolylineFeatureLayerCount = 0;
					queryResultCount = 0;
					cutRequestCount = 0;
					p = 0;
					while(p < this.m_featureLayers.length)
					{
						if(!((!FeatureLayer(this.m_featureLayers[p]).visible) || (!FeatureLayer(this.m_featureLayers[p]).isInScaleRange)))
						{
							if((FeatureLayer(this.m_featureLayers[p]).layerDetails.geometryType == Geometry.POLYGON) || (FeatureLayer(this.m_featureLayers[p]).layerDetails.geometryType == Geometry.POLYLINE))
							{
								polygonPolylineFeatureLayerCount++;
								FeatureLayer(this.m_featureLayers[p]).queryFeatures(this.m_query,new AsyncResponder(query_resultHandler,query_faultHandler,this.m_featureLayers[p]));
							}
						}
						p++;
					}
				}
				else if((event.graphic.geometry.type == Geometry.POLYLINE) && (this.m_reshapeInProgress))
				{
					reshape_queryResultHandler = function(objectIds:Array, token:Object=null):void
					{
						var selectedGraphicPartOfIntersect:Boolean = false;
						var n:Number = NaN;
						var fault:Fault = null;
						if(objectIds.length > 0)
						{
							n = 0;
							while(n < objectIds.length)
							{
								if(token.attributes[FeatureLayer(token.graphicsLayer).layerDetails.objectIdField] === objectIds[n])
								{
									selectedGraphicPartOfIntersect = true;
									break;
								}
								n++;
							}
							if(selectedGraphicPartOfIntersect)
							{
								geometryServiceReshape = function(geometryService:GeometryService):void
								{
									var geom:Geometry = token.geometry;
									m_undoReshapeGraphicGeometry = geom;
									geom.spatialReference = !geom.spatialReference?spatialReference:geom.spatialReference;
									geometryService.reshape(geom,Polyline(event.graphic.geometry),new AsyncResponder(reshape_resultHandler,reshape_faultHandler,token));
								};
								if(m_geometryService)
								{
									geometryServiceReshape(m_geometryService);
								}
								else if(GeometryServiceSingleton.instance.url)
								{
									geometryServiceReshape(GeometryServiceSingleton.instance);
								}
								else
								{
									fault = new Fault(null,ESRIMessageCodes.formatMessage(ESRIMessageCodes.GEOMETRYSERVICE_REQUIRED));
									dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
								}
								
							}
							else
							{
								m_reshapeInProgress = false;
								reshapeButton.selected = false;
								m_drawTool.deactivate();
							}
						}
					};
					reshape_resultHandler = function(result:Object, token:Object=null):void
					{
						var feature:Graphic = null;
						var featureLayer:FeatureLayer = null;
						var reshape_applyEditsResult:Function = function(featureEditResults:FeatureEditResults):void
						{
							var reshapeOperation:ReshapeOperation = null;
							if(featureEditResults.updateResults[0].success)
							{
								refreshDynamicMapServiceLayer(featureLayer);
								reshapeOperation = new ReshapeOperation(feature,featureLayer,m_undoReshapeGraphicGeometry,m_redoReshapeGraphicGeometry);
								m_undoManager.pushUndo(reshapeOperation);
								callLater(updateUndoRedoButtons);
							}
							m_editGraphic = feature;
						};
						var reshape_applyEditsFault:Function = function(fault:Fault):void
						{
						};
						m_lastUpdateOperation = "reshape geometry";
						operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
						m_reshapeInProgress = false;
						reshapeButton.selected = false;
						m_drawTool.deactivate();
						feature = token as Graphic;
						featureLayer = feature.graphicsLayer as FeatureLayer;
						m_redoReshapeGraphicGeometry = result as Geometry;
						feature.geometry = result as Geometry;
						featureLayer.applyEdits(null,[feature],null,false,new Responder(reshape_applyEditsResult,reshape_applyEditsFault));
						if(!m_applyingEdits)
						{
							m_applyingEdits = true;
							invalidateSkinState();
						}
					};
					reshape_faultHandler = function(fault:Fault, token:Object=null):void
					{
						m_reshapeInProgress = false;
						reshapeButton.selected = false;
						m_drawTool.deactivate();
						dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
					};
					reshape_queryFaultHandler = function(fault:Fault, tokern:Object=null):void
					{
					};
					this.m_query = new Query();
					this.m_query.geometry = Polyline(event.graphic.geometry);
					reshapeSelectedFeaturesArray = [];
					r = 0;
					while(r < this.m_featureLayers.length)
					{
						if((FeatureLayer(this.m_featureLayers[r]).layerDetails.geometryType == Geometry.POLYGON) || (FeatureLayer(this.m_featureLayers[r]).layerDetails.geometryType == Geometry.POLYLINE))
						{
							reshapeSelectedFeaturesArray.push(FeatureLayer(this.m_featureLayers[r]).selectedFeatures);
						}
						r++;
					}
					featureArray = [];
					k = 0;
					while(k < reshapeSelectedFeaturesArray.length)
					{
						for each(reshapeFeature in reshapeSelectedFeaturesArray[k])
						{
							featureArray.push(reshapeFeature);
						}
						k++;
					}
					if((featureArray) && (featureArray.length == 1))
					{
						FeatureLayer(Graphic(featureArray[0]).graphicsLayer).queryIds(this.m_query,new AsyncResponder(reshape_queryResultHandler,reshape_queryFaultHandler,featureArray[0]));
					}
					else
					{
						this.m_reshapeInProgress = false;
						this.reshapeButton.selected = false;
						this.m_drawTool.deactivate();
					}
				}
				else
				{
					this.m_newFeatureCreated = true;
					nGraphic = this.templatePicker.selectedTemplate.featureTemplate?new Graphic(event.graphic.geometry,null,ObjectUtil.copy(this.templatePicker.selectedTemplate.featureTemplate.prototype.attributes)):new Graphic(event.graphic.geometry);
					this.createApplyEdits(nGraphic);
				}
				
				
				
				
			}
		}
		
		private function createApplyEdits(graphic:Graphic) : void {
			this.m_featureCreated = true;
			this.m_lastCreatedGraphic = graphic;
			this.m_tempNewFeature = graphic;
			this.m_tempNewFeatureLayer = this.templatePicker.selectedTemplate.featureLayer;
			this.m_tempNewFeature.symbol = this.templatePicker.selectedTemplate.symbol;
			this.map.defaultGraphicsLayer.add(this.m_tempNewFeature);
			this.m_attributeInspector.showFeature(this.m_tempNewFeature,this.m_tempNewFeatureLayer);
			this.showAttributeInspector(this.m_tempNewFeature);
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.m_editTool.activate(EditTool.MOVE | EditTool.EDIT_VERTICES,[this.m_tempNewFeature]);
			this.addEditToolEventListeners();
			this.templatePicker.clearSelection();
			this.m_drawTool.deactivate();
			if(this.m_toolbarVisible)
			{
				this.deleteButton.enabled = true;
			}
		}
		
		private function addNewFeature(graphic:Graphic, featureLayer:FeatureLayer) : void {
			var userId:String = null;
			var attributeObject:Object = null;
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.map.infoWindow.hide();
			this.attributeInspector.activeFeatureIndex = -1;
			this.attributeInspector.refresh();
			var editFieldsInfo:EditFieldsInfo = featureLayer.editFieldsInfo;
			if((editFieldsInfo) && (editFieldsInfo.creatorField) && (featureLayer.userId))
			{
				userId = featureLayer.userId;
				graphic.attributes[editFieldsInfo.creatorField] = editFieldsInfo.realm?userId + "@" + editFieldsInfo.realm:userId;
			}
			if((editFieldsInfo) && (editFieldsInfo.creationDateField))
			{
				graphic.attributes[editFieldsInfo.creationDateField] = new Date().time;
			}
			if(this.m_activeFeatureChangedAttributes.length)
			{
				for each(attributeObject in this.m_activeFeatureChangedAttributes)
				{
					graphic.attributes[attributeObject.field.name] = attributeObject.newValue;
				}
			}
			var applyEditsGraphic:Graphic = new Graphic(graphic.geometry,null,graphic.attributes);
			featureLayer.applyEdits([applyEditsGraphic],null,null);
			this.m_undoRedoAddDeleteOperation = false;
			var addFeatureOperation:AddOperation = new AddOperation(applyEditsGraphic,featureLayer);
			this.m_undoManager.pushUndo(addFeatureOperation);
			this.operationStartLabel.text = ADD_FEATURE_OPERATION_START;
			if(!this.m_applyingEdits)
			{
				this.m_applyingEdits = true;
				invalidateSkinState();
			}
		}
		
		private function polygonToPolyline(polygon:Polygon) : Polyline {
			var ring:Array = null;
			var polyline:Polyline = new Polyline();
			for each(ring in polygon.rings)
			{
				polyline.addPath(ring);
			}
			return polyline;
		}
		
		private function deleteButton_clickHandler(event:MouseEvent) : void {
			var featureLayer:FeatureLayer = null;
			var selectedDeletableFeatures:Array = null;
			var feature:Graphic = null;
			var deleteFeaturesOperation:DeleteOperation = null;
			if(this.m_tempNewFeature)
			{
				this.m_deletingTempGraphic = true;
				this.removeTempNewGraphic();
				this.map.infoWindow.hide();
			}
			else
			{
				this.m_featuresToBeDeleted = [];
				this.m_featureLayerDeleteResults = [];
				this.m_undoRedoAddDeleteOperation = false;
				for each(featureLayer in this.m_featureLayers)
				{
					if((featureLayer.selectedFeatures.length > 0) && (this.checkIfDeleteIsAllowed(featureLayer)))
					{
						selectedDeletableFeatures = [];
						for each(feature in featureLayer.selectedFeatures)
						{
							if(featureLayer.isDeleteAllowed(feature))
							{
								selectedDeletableFeatures.push(feature);
							}
						}
						if(selectedDeletableFeatures.length)
						{
							this.m_featuresToBeDeleted.push(
								{
									"selectedFeatures":selectedDeletableFeatures,
									"featureLayer":featureLayer
								});
							featureLayer.applyEdits(null,null,selectedDeletableFeatures);
						}
					}
				}
				if(this.m_featuresToBeDeleted.length)
				{
					this.cutReshapeButtonHandler();
					deleteFeaturesOperation = new DeleteOperation(this.m_featuresToBeDeleted);
					this.m_undoManager.pushUndo(deleteFeaturesOperation);
					callLater(this.updateUndoRedoButtons);
					if(this.m_featuresToBeDeleted.length == 1)
					{
						if((this.m_featuresToBeDeleted[0].selectedFeatures as Array).length == 1)
						{
							this.operationStartLabel.text = DELETE_FEATURE_OPERATION_START;
						}
						else
						{
							this.operationStartLabel.text = DELETE_FEATURES_OPERATION_START;
						}
					}
					else
					{
						this.operationStartLabel.text = DELETE_FEATURES_OPERATION_START;
					}
					if(!this.m_applyingEdits)
					{
						this.m_applyingEdits = true;
						invalidateSkinState();
					}
				}
			}
		}
		
		private function undoButton_clickHandler(event:MouseEvent) : void {
			this.performUndo();
		}
		
		private function redoButton_clickHandler(event:MouseEvent) : void {
			this.performRedo();
		}
		
		private function performUndo() : void {
			this.m_undoRedoInProgress = true;
			this.m_applyingEdits = true;
			invalidateSkinState();
			if((this.m_undoManager.peekUndo() is AddOperation) || (this.m_undoManager.peekUndo() is DeleteOperation))
			{
				if(this.m_undoManager.peekUndo() is AddOperation)
				{
					this.m_undoAddOperation = true;
					this.operationStartLabel.text = UNDO_ADD_FEATURE_OPERATION_START;
				}
				else
				{
					this.m_countDeleteFeatureLayers = 0;
					this.m_featureLayerAddResults = [];
					if(this.m_featuresToBeDeleted.length == 1)
					{
						if((this.m_featuresToBeDeleted[0].selectedFeatures as Array).length == 1)
						{
							this.operationStartLabel.text = UNDO_DELETE_FEATURE_OPERATION_START;
						}
						else
						{
							this.operationStartLabel.text = UNDO_DELETE_FEATURES_OPERATION_START;
						}
					}
					else
					{
						this.operationStartLabel.text = UNDO_DELETE_FEATURES_OPERATION_START;
					}
				}
				this.m_undoRedoAddDeleteOperation = true;
				this.m_isEdit = false;
			}
			if(this.m_undoManager.peekUndo() is EditGeometryOperation)
			{
				this.m_lastUpdateOperation = "undo edit geometry";
				this.operationStartLabel.text = UNDO_UPDATE_FEATURE_OPERATION_START;
				if((EditGeometryOperation(this.m_undoManager.peekUndo()).feature === this.m_editGraphic) && (!this.m_undoRedoAddDeleteOperation) && (!this.m_undoRedoReshapeOperation) && (!this.m_undoRedoMergeOperation) && (!this.m_undoRedoCutOperation))
				{
					this.map.infoWindow.hide();
					EditGeometryOperation(this.m_undoManager.peekUndo()).restoreEditTool = true;
				}
				else
				{
					EditGeometryOperation(this.m_undoManager.peekUndo()).restoreEditTool = false;
				}
			}
			if((this.m_undoManager.peekUndo() is EditAttributesOperation) && (!this.m_undoRedoReshapeOperation) && (!this.m_undoRedoMergeOperation) && (!this.m_undoRedoCutOperation))
			{
				this.m_lastUpdateOperation = "undo edit attribute";
				this.operationStartLabel.text = UNDO_UPDATE_FEATURE_OPERATION_START;
				if(EditAttributesOperation(this.m_undoManager.peekUndo()).feature === this.m_editGraphic)
				{
					EditAttributesOperation(this.m_undoManager.peekUndo()).restoreAttributeInspector = true;
				}
				else
				{
					EditAttributesOperation(this.m_undoManager.peekUndo()).restoreAttributeInspector = false;
				}
			}
			if(this.m_undoManager.peekUndo() is ReshapeOperation)
			{
				this.m_lastUpdateOperation = "undo reshape geometry";
				this.operationStartLabel.text = UNDO_UPDATE_FEATURE_OPERATION_START;
			}
			if(this.m_undoManager.peekUndo() is CutOperation)
			{
				this.m_lastUpdateOperation = "undo split geometry";
				this.m_arrUndoCutOperation = [];
				this.operationStartLabel.text = this.m_cutQueryFeatureArray.length == 1?UNDO_SPLIT_FEATURE_OPERATION_START:UNDO_SPLIT_FEATURES_OPERATION_START;
			}
			if(this.m_undoManager.peekUndo() is MergeOperation)
			{
				this.m_lastUpdateOperation = "undo merge geometry";
				this.m_arrUndoRedoMergeOperation = [];
				this.operationStartLabel.text = UNDO_MERGE_FEATURES_OPERATION_START;
			}
			var operationToRedo:IOperation = this.m_undoManager.peekUndo();
			this.m_undoManager.undo();
			this.m_undoManager.pushRedo(operationToRedo);
			if(this.m_toolbarVisible)
			{
				this.setButtonStates();
			}
		}
		
		private function performRedo() : void {
			this.m_undoRedoInProgress = true;
			this.m_applyingEdits = true;
			invalidateSkinState();
			if((this.m_undoManager.peekRedo() is AddOperation) || (this.m_undoManager.peekRedo() is DeleteOperation))
			{
				if(this.m_undoManager.peekRedo() is AddOperation)
				{
					this.m_redoAddOperation = true;
					this.operationStartLabel.text = REDO_ADD_FEATURE_OPERATION_START;
				}
				else
				{
					this.m_countDeleteFeatureLayers = 0;
					this.m_featureLayerDeleteResults = [];
					if(this.m_featuresToBeDeleted.length == 1)
					{
						if((this.m_featuresToBeDeleted[0].selectedFeatures as Array).length == 1)
						{
							this.operationStartLabel.text = REDO_DELETE_FEATURE_OPERATION_START;
						}
						else
						{
							this.operationStartLabel.text = REDO_DELETE_FEATURES_OPERATION_START;
						}
					}
					else
					{
						this.operationStartLabel.text = REDO_DELETE_FEATURES_OPERATION_START;
					}
				}
				this.m_undoRedoAddDeleteOperation = true;
				this.m_isEdit = false;
			}
			if(this.m_undoManager.peekRedo() is EditGeometryOperation)
			{
				this.m_lastUpdateOperation = "redo edit geometry";
				this.operationStartLabel.text = REDO_UPDATE_FEATURE_OPERATION_START;
				if((EditGeometryOperation(this.m_undoManager.peekRedo()).feature === this.m_editGraphic) && (!this.m_undoRedoAddDeleteOperation) && (!this.m_undoRedoReshapeOperation) && (!this.m_undoRedoMergeOperation) && (!this.m_undoRedoCutOperation))
				{
					this.map.infoWindow.hide();
					EditGeometryOperation(this.m_undoManager.peekRedo()).restoreEditTool = true;
				}
				else
				{
					EditGeometryOperation(this.m_undoManager.peekRedo()).restoreEditTool = false;
				}
			}
			if(this.m_undoManager.peekRedo() is EditAttributesOperation)
			{
				this.m_lastUpdateOperation = "redo edit attribute";
				this.operationStartLabel.text = REDO_UPDATE_FEATURE_OPERATION_START;
				if((EditAttributesOperation(this.m_undoManager.peekRedo()).feature === this.m_editGraphic) && (!this.m_undoRedoReshapeOperation) && (!this.m_undoRedoMergeOperation) && (!this.m_undoRedoCutOperation))
				{
					EditAttributesOperation(this.m_undoManager.peekRedo()).restoreAttributeInspector = true;
				}
				else
				{
					EditAttributesOperation(this.m_undoManager.peekRedo()).restoreAttributeInspector = false;
				}
			}
			if(this.m_undoManager.peekRedo() is ReshapeOperation)
			{
				this.m_lastUpdateOperation = "redo reshape geometry";
				this.operationStartLabel.text = REDO_UPDATE_FEATURE_OPERATION_START;
			}
			if(this.m_undoManager.peekRedo() is CutOperation)
			{
				this.m_lastUpdateOperation = "redo split geometry";
				this.m_arrUndoCutOperation = [];
				this.operationStartLabel.text = this.m_cutQueryFeatureArray.length == 1?REDO_SPLIT_FEATURE_OPERATION_START:REDO_SPLIT_FEATURES_OPERATION_START;
			}
			if(this.m_undoManager.peekRedo() is MergeOperation)
			{
				this.m_lastUpdateOperation = "redo merge geometry";
				this.m_arrUndoRedoMergeOperation = [];
				this.operationStartLabel.text = REDO_MERGE_FEATURES_OPERATION_START;
			}
			var operationToUndo:IOperation = this.m_undoManager.peekRedo();
			this.m_undoManager.redo();
			this.m_undoManager.pushUndo(operationToUndo);
			if(this.m_toolbarVisible)
			{
				this.setButtonStates();
			}
		}
		
		private function setButtonStates() : void {
			if((this.undoButton) && (this.redoButton))
			{
				this.undoButton.enabled = this.m_undoManager.canUndo();
				this.redoButton.enabled = this.m_undoManager.canRedo();
			}
		}
		
		private function cutButton_changeHandler(event:Event) : void {
			this.m_cutInProgress = false;
			this.m_creationInProgress = false;
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.m_drawTool.deactivate();
			this.m_undoCutGeometryArray = [];
			this.m_redoCutGeometryArray = [];
			if(this.cutButton.selected)
			{
				this.m_undoRedoCutOperation = true;
				this.m_mergeInProgress = false;
				this.m_reshapeInProgress = false;
				this.reshapeButton.selected = false;
				this.m_cutInProgress = true;
				if(this.map)
				{
					this.map.infoWindow.hide();
				}
				this.m_drawTool.activate(DrawTool.POLYLINE);
				this.m_drawTool.lineSymbol = new SimpleLineSymbol(SimpleLineSymbol.STYLE_SOLID,0,1,1);
				this.m_creationInProgress = true;
			}
		}
		
		private function mergeButton_clickHandler(event:MouseEvent) : void {
			var selectedFeaturesArray:Array = null;
			var spatialReference:SpatialReference = null;
			var featureArray:Array = null;
			var feature:Graphic = null;
			var merge_resultHandler:Function = null;
			var merge_faultHandler:Function = null;
			var fault:Fault = null;
			this.m_reshapeInProgress = false;
			this.reshapeButton.selected = false;
			this.m_cutInProgress = false;
			this.cutButton.selected = false;
			this.cutReshapeButtonHandler();
			this.m_mergeInProgress = true;
			this.m_undoRedoMergeOperation = true;
			selectedFeaturesArray = [];
			spatialReference = FeatureLayer(this.m_featureLayers[0]).map.spatialReference;
			var i:Number = 0;
			while(i < this.m_featureLayers.length)
			{
				if((FeatureLayer(this.m_featureLayers[i]).layerDetails.geometryType == Geometry.POLYGON) && (FeatureLayer(this.m_featureLayers[i]).selectedFeatures.length > 1))
				{
					selectedFeaturesArray.push(
						{
							"featureLayer":FeatureLayer(this.m_featureLayers[i]),
							"selectedFeatures":FeatureLayer(this.m_featureLayers[i]).selectedFeatures
						});
				}
				i++;
			}
			featureArray = [];
			var k:Number = 0;
			while(k < selectedFeaturesArray.length)
			{
				for each(feature in selectedFeaturesArray[k].selectedFeatures)
				{
					featureArray.push(feature);
				}
				k++;
			}
			if((featureArray) && (featureArray.length == 1))
			{
				this.m_mergeInProgress = false;
			}
			else if((featureArray) && (featureArray.length > 1))
			{
				geometryServiceUnion = function(geometryService:GeometryService):void
				{
					m_editTool.deactivate();
					removeEditToolEventListeners();
					if(map)
					{
						map.infoWindow.hide();
					}
					var geometries:Array = [];
					var j:Number = 0;
					while(j < featureArray.length)
					{
						if(!Graphic(featureArray[j]).geometry.spatialReference)
						{
							Graphic(featureArray[j]).geometry.spatialReference = spatialReference;
						}
						geometries.push(Graphic(featureArray[j]).geometry);
						j++;
					}
					geometryService.union(geometries,new AsyncResponder(merge_resultHandler,merge_faultHandler,featureArray));
				};
				merge_resultHandler = function(result:Object, token:Object=null):void
				{
					var featureEditResultsArray:Array = null;
					var applyEditsResultCount:int = 0;
					var applyEditsFault:Boolean = false;
					var merge_applyEditsResult:Function = null;
					var merge_applyEditsFault:Function = null;
					var i:Number = NaN;
					merge_applyEditsResult = function(featureEditResults:FeatureEditResults, token:Object=null):void
					{
						applyEditsResultCount++;
						featureEditResultsArray.push(
							{
								"featureEditResults":featureEditResults,
								"featureLayer":token
							});
						mergeApplyEditsComplete();
						refreshDynamicMapServiceLayer(token as FeatureLayer);
					};
					merge_applyEditsFault = function(fault:Fault, token:Object=null):void
					{
						applyEditsFault = true;
						applyEditsResultCount++;
						mergeApplyEditsComplete();
					};
					var mergeApplyEditsComplete:Function = function():void
					{
						var i:* = NaN;
						var j:* = NaN;
						var k:* = NaN;
						if(applyEditsResultCount == selectedFeaturesArray.length)
						{
							m_mergeInProgress = false;
							m_isEdit = false;
							if(!applyEditsFault)
							{
								m_query = new Query();
								operationCompleteLabel.text = MERGE_FEATURES_OPERATION_COMPLETE;
								i = 0;
								while(i < featureEditResultsArray.length)
								{
									if(featureEditResultsArray[i].featureEditResults.addResults.length > 0)
									{
										j = 0;
										while(j < featureEditResultsArray[i].featureEditResults.addResults.length)
										{
											if(featureEditResultsArray[i].featureEditResults.addResults[j].success)
											{
												m_query.objectIds = [featureEditResultsArray[i].featureEditResults.addResults[j].objectId];
												FeatureLayer(featureEditResultsArray[i].featureLayer).selectFeatures(m_query,FeatureLayer.SELECTION_ADD);
												j++;
												continue;
											}
											operationCompleteLabel.text = MERGE_FEATURES_OPERATION_FAILED;
											break;
										}
									}
									if(featureEditResultsArray[i].featureEditResults.deleteResults.length > 0)
									{
										k = 0;
										while(k < featureEditResultsArray[i].featureEditResults.deleteResults.length)
										{
											if(featureEditResultsArray[i].featureEditResults.deleteResults[k].success)
											{
												k++;
												continue;
											}
											operationCompleteLabel.text = MERGE_FEATURES_OPERATION_FAILED;
											break;
										}
									}
									if(operationCompleteLabel.text == MERGE_FEATURES_OPERATION_FAILED)
									{
										break;
									}
									i++;
								}
							}
							else
							{
								operationCompleteLabel.text = MERGE_FEATURES_OPERATION_FAILED;
							}
							m_applyingEdits = false;
							invalidateSkinState();
							operationCompleteLabel.includeInLayout = true;
							operationCompleteLabel.visible = true;
							operationCompleteLabel.visible = false;
						}
					};
					var adds:Array = [new Graphic(result as Geometry,null,ObjectUtil.copy(Graphic(token[0]).attributes))];
					var mergeOperation:MergeOperation = new MergeOperation(adds,token as Array,FeatureLayer(Graphic(token[0]).graphicsLayer),selectedFeaturesArray);
					m_undoManager.pushUndo(mergeOperation);
					callLater(updateUndoRedoButtons);
					operationStartLabel.text = MERGE_FEATURES_OPERATION_START;
					featureEditResultsArray = [];
					applyEditsResultCount = 0;
					m_undoRedoMergeAddsDeletesArray = selectedFeaturesArray;
					if(selectedFeaturesArray.length == 1)
					{
						FeatureLayer(Graphic(token[0]).graphicsLayer).applyEdits(adds,null,token as Array,true,new AsyncResponder(merge_applyEditsResult,merge_applyEditsFault,Graphic(token[0]).graphicsLayer));
					}
					else
					{
						FeatureLayer(Graphic(token[0]).graphicsLayer).applyEdits(adds,null,null,false,new AsyncResponder(merge_applyEditsResult,merge_applyEditsFault,Graphic(token[0]).graphicsLayer));
						i = 1;
						while(i < selectedFeaturesArray.length)
						{
							FeatureLayer(selectedFeaturesArray[i].featureLayer).applyEdits(null,null,selectedFeaturesArray[i].selectedFeatures as Array,true,new AsyncResponder(merge_applyEditsResult,merge_applyEditsFault,Graphic(token[i]).graphicsLayer));
							i++;
						}
					}
					if(!m_applyingEdits)
					{
						m_applyingEdits = true;
						invalidateSkinState();
					}
				};
				merge_faultHandler = function(fault:Fault, token:Object=null):void
				{
					m_mergeInProgress = false;
				};
				if(this.m_geometryService)
				{
					geometryServiceUnion(this.m_geometryService);
				}
				else if(GeometryServiceSingleton.instance.url)
				{
					geometryServiceUnion(GeometryServiceSingleton.instance);
				}
				else
				{
					this.m_mergeInProgress = false;
					fault = new Fault(null,ESRIMessageCodes.formatMessage(ESRIMessageCodes.GEOMETRYSERVICE_REQUIRED));
					dispatchEvent(new FaultEvent(FaultEvent.FAULT,true,false,fault));
				}
				
			}
			
		}
		
		private function reshapeButton_changeHandler(event:Event) : void {
			this.m_reshapeInProgress = false;
			this.m_creationInProgress = false;
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.m_drawTool.deactivate();
			if(this.reshapeButton.selected)
			{
				this.m_undoRedoReshapeOperation = true;
				this.m_mergeInProgress = false;
				this.m_cutInProgress = false;
				this.cutButton.selected = false;
				this.m_reshapeInProgress = true;
				if(this.map)
				{
					this.map.infoWindow.hide();
				}
				this.m_drawTool.activate(DrawTool.POLYLINE);
				this.m_drawTool.lineSymbol = new SimpleLineSymbol(SimpleLineSymbol.STYLE_SOLID,0,1,1);
				this.m_creationInProgress = true;
			}
		}
		
		private function key_downHandler(event:KeyboardEvent) : void {
			if(event.keyCode == Keyboard.ESCAPE)
			{
				if((this.m_drawStart) && (this.m_templateSelected))
				{
					this.m_graphicRemoved = true;
					this.m_drawTool.removeGraphic(this.m_currentlyDrawnGraphic);
					this.templatePicker.clearSelection();
				}
				else if(!this.m_graphicEditing)
				{
					this.m_doNotApplyEdits = true;
					this.m_editGraphic = null;
					this.m_editTool.deactivate();
					this.removeEditToolEventListeners();
					if(this.map)
					{
						this.map.infoWindow.hide();
					}
					this.clearSelection();
				}
				
			}
			if((event.ctrlKey) && (event.keyCode == 90) && (!event.shiftKey))
			{
				if((!this.m_undoRedoInProgress) && (this.m_undoManager.canUndo()))
				{
					this.performUndo();
				}
			}
			if((event.ctrlKey) && ((event.keyCode == 89) || (event.shiftKey) && (event.keyCode == 90)))
			{
				if((!this.m_undoRedoInProgress) && (this.m_undoManager.canRedo()))
				{
					this.performRedo();
				}
			}
		}
		
		private function map_keyDownHandler(event:KeyboardEvent) : void {
			var featureLayer:FeatureLayer = null;
			var selectedDeletableFeatures:Array = null;
			var feature:Graphic = null;
			var deleteFeaturesOperation:DeleteOperation = null;
			if(event.keyCode == Keyboard.DELETE)
			{
				if(this.m_tempNewFeature)
				{
					this.m_deletingTempGraphic = true;
					this.removeTempNewGraphic();
					this.map.infoWindow.hide();
				}
				else if(this.m_deleteEnabled)
				{
					this.m_featuresToBeDeleted = [];
					this.m_featureLayerDeleteResults = [];
					this.m_undoRedoAddDeleteOperation = false;
					for each(featureLayer in this.m_featureLayers)
					{
						if((featureLayer.selectedFeatures.length > 0) && (this.checkIfDeleteIsAllowed(featureLayer)) && (!this.m_graphicEditing))
						{
							selectedDeletableFeatures = [];
							for each(feature in featureLayer.selectedFeatures)
							{
								if(featureLayer.isDeleteAllowed(feature))
								{
									selectedDeletableFeatures.push(feature);
								}
							}
							if(selectedDeletableFeatures.length)
							{
								this.m_featuresToBeDeleted.push(
									{
										"selectedFeatures":selectedDeletableFeatures,
										"featureLayer":featureLayer
									});
								featureLayer.applyEdits(null,null,selectedDeletableFeatures);
							}
						}
					}
					if(this.m_featuresToBeDeleted.length)
					{
						deleteFeaturesOperation = new DeleteOperation(this.m_featuresToBeDeleted);
						this.m_undoManager.pushUndo(deleteFeaturesOperation);
						callLater(this.updateUndoRedoButtons);
						if(this.m_featuresToBeDeleted.length == 1)
						{
							if((this.m_featuresToBeDeleted[0].selectedFeatures as Array).length == 1)
							{
								this.operationStartLabel.text = DELETE_FEATURE_OPERATION_START;
							}
							else
							{
								this.operationStartLabel.text = DELETE_FEATURES_OPERATION_START;
							}
						}
						else
						{
							this.operationStartLabel.text = DELETE_FEATURES_OPERATION_START;
						}
						if(!this.m_applyingEdits)
						{
							this.m_applyingEdits = true;
							invalidateSkinState();
						}
						if(this.map)
						{
							this.map.infoWindow.hide();
						}
					}
				}
				
			}
		}
		
		private function map_mouseDownHandler(event:MapMouseEvent) : void {
			event.currentTarget.addEventListener(MouseEvent.MOUSE_MOVE,this.map_mouseMoveHandler);
			event.currentTarget.addEventListener(MouseEvent.MOUSE_UP,this.map_mouseUpHandler);
		}
		
		private function map_mouseMoveHandler(event:MouseEvent) : void {
			event.currentTarget.removeEventListener(MouseEvent.MOUSE_MOVE,this.map_mouseMoveHandler);
			event.currentTarget.removeEventListener(MouseEvent.MOUSE_UP,this.map_mouseUpHandler);
		}
		
		private function map_mouseUpHandler(event:MouseEvent) : void {
			var g:Graphic = null;
			var featureLayerOfEditor:Boolean = false;
			var i:Number = NaN;
			var clickOnSameFeature:Boolean = false;
			var editGraphicPartOfSelecttion:Boolean = false;
			var editFeatureLayer:FeatureLayer = null;
			var featureLayer:FeatureLayer = null;
			var p:Number = NaN;
			var objectId:Number = NaN;
			var j:Number = NaN;
			var point:Point = null;
			var mins:MapPoint = null;
			var maxs:MapPoint = null;
			var spatialReference:SpatialReference = null;
			var selectionExtent:Extent = null;
			var index:int = 0;
			this.m_attributeInspector.updateEnabled = this.updateAttributesEnabled;
			this.m_attributeInspector.deleteButtonVisible = this.deleteEnabled;
			event.currentTarget.removeEventListener(MouseEvent.MOUSE_MOVE,this.map_mouseMoveHandler);
			event.currentTarget.removeEventListener(MouseEvent.MOUSE_UP,this.map_mouseUpHandler);
			this.m_editPoint = this.map.toMapFromStage(event.stageX,event.stageY);
			if(!this.m_creationInProgress)
			{
				this.m_undoRedoAddDeleteOperation = false;
				this.m_undoRedoCutOperation = false;
				this.m_undoRedoReshapeOperation = false;
				this.m_undoRedoMergeOperation = false;
				if((event.target is Graphic) || (event.target.parent is Graphic) || (event.target.parent.parent is Graphic))
				{
					this.m_selectionMode = false;
					g = event.target is Graphic?Graphic(event.target):event.target.parent is Graphic?Graphic(event.target.parent):Graphic(event.target.parent.parent);
					if(this.m_tempNewFeature)
					{
						if((!(g.symbol == this.m_editTool.ghostVertexSymbol)) && (!(g.symbol == this.m_editTool.vertexSymbol)))
						{
							if(g !== this.m_tempNewFeature)
							{
								this.saveTempNewFeature();
							}
							else if((this.m_tempNewFeature.geometry is Polyline) || (this.m_tempNewFeature.geometry is Polygon))
							{
								if((this.m_lastActiveTempEdit == null) || (this.m_lastActiveTempEdit == ""))
								{
									this.m_lastActiveTempEdit = "moveEditVertices";
									this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_tempNewFeature]);
								}
								else if(this.m_lastActiveTempEdit == "moveEditVertices")
								{
									this.m_lastActiveTempEdit = "rotateShape";
									this.m_editTool.activate(EditTool.MOVE | EditTool.SCALE | EditTool.ROTATE,[this.m_tempNewFeature]);
								}
								else if(this.m_lastActiveTempEdit == "rotateShape")
								{
									this.m_lastActiveTempEdit = "moveEditVertices";
									this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_tempNewFeature]);
									this.map.infoWindow.show(this.m_editPoint);
								}
								
								
							}
							else
							{
								this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_tempNewFeature]);
								this.map.infoWindow.show(this.m_editPoint);
							}
							
						}
					}
					i = 0;
					while(i < this.m_featureLayers.length)
					{
						if(g.graphicsLayer === this.m_featureLayers[i])
						{
							featureLayerOfEditor = true;
							break;
						}
						i++;
					}
					if(featureLayerOfEditor)
					{
						if((!(g.symbol == this.m_editTool.ghostVertexSymbol)) && (!(g.symbol == this.m_editTool.vertexSymbol)))
						{
							if(((g.graphicsLayer) && (g.graphicsLayer is FeatureLayer)) && (g.graphicsLayer.loaded) && (FeatureLayer(g.graphicsLayer).isEditable))
							{
								this.m_isEdit = true;
								this.m_doNotApplyEdits = false;
								this.m_editClearSelection = false;
								this.m_selectionMode = false;
								if(this.m_editGraphic !== g)
								{
									if(this.m_editGraphic)
									{
										this.saveUnsavedAttributes(this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer));
										this.m_attributesSaved = true;
									}
									this.m_editGraphic = g;
									for each(featureLayer in this.m_featureLayers)
									{
										p = 0;
										while(p < featureLayer.selectedFeatures.length)
										{
											if(this.m_editGraphic === featureLayer.selectedFeatures[p])
											{
												editGraphicPartOfSelecttion = true;
												break;
											}
											p++;
										}
										if(editGraphicPartOfSelecttion)
										{
											break;
										}
									}
								}
								else
								{
									clickOnSameFeature = true;
									editGraphicPartOfSelecttion = true;
								}
								this.m_query = new Query();
								this.m_query.objectIds = [this.m_editGraphic.attributes[FeatureLayer(this.m_editGraphic.graphicsLayer).layerDetails.objectIdField]];
								editFeatureLayer = g.graphicsLayer as FeatureLayer;
								if(event.ctrlKey)
								{
									this.m_lastActiveEdit = "";
									if(!editGraphicPartOfSelecttion)
									{
										this.map.infoWindow.hide();
										this.m_editTool.deactivate();
										this.removeEditToolEventListeners();
										CursorManager.removeCursor(CursorManager.currentCursorID);
										editFeatureLayer.selectFeatures(this.m_query,FeatureLayer.SELECTION_ADD);
										this.m_editGraphic = null;
									}
									else
									{
										this.m_doNotApplyEdits = true;
										editFeatureLayer.selectFeatures(this.m_query,FeatureLayer.SELECTION_SUBTRACT);
									}
								}
								else if(editGraphicPartOfSelecttion)
								{
									if(!clickOnSameFeature)
									{
										if((this.m_updateGeometryEnabled) && (this.checkIfGeometryUpdateIsAllowed(editFeatureLayer)) && (editFeatureLayer.isUpdateAllowed(this.m_editGraphic)))
										{
											this.m_editTool.deactivate();
											this.removeEditToolEventListeners();
											this.m_lastActiveEdit = "moveEditVertices";
											this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
											this.addEditToolEventListeners();
										}
										this.updateAttributeInspector(editFeatureLayer,this.m_editGraphic);
										objectId = this.m_editGraphic.attributes[FeatureLayer(this.m_editGraphic.graphicsLayer).layerDetails.objectIdField];
										this.m_attributeInspector.activeFeatureIndex = 0;
										j = 0;
										while(j < this.m_attributeInspector.numFeatures)
										{
											if(this.m_attributeInspector.activeFeature.attributes[FeatureLayer(this.m_editGraphic.graphicsLayer).layerDetails.objectIdField] == objectId)
											{
												break;
											}
											this.m_attributeInspector.next();
											j++;
										}
										this.map.infoWindow.show(this.m_editPoint);
										this.map.infoWindow.closeButton.addEventListener(MouseEvent.MOUSE_DOWN,this.infoWindowCloseButtonMouseDownHandler);
									}
									else if((this.m_updateGeometryEnabled) && (this.checkIfGeometryUpdateIsAllowed(editFeatureLayer)) && (editFeatureLayer.isUpdateAllowed(this.m_editGraphic)))
									{
										this.m_editTool.deactivate();
										this.removeEditToolEventListeners();
										if((this.m_editGraphic.geometry is Polyline) || (this.m_editGraphic.geometry is Polygon))
										{
											if((this.m_lastActiveEdit == null) || (this.m_lastActiveEdit == ""))
											{
												this.m_lastActiveEdit = "moveEditVertices";
												this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
											}
											else if(this.m_lastActiveEdit == "moveEditVertices")
											{
												this.m_lastActiveEdit = "rotateShape";
												this.m_editTool.activate(EditTool.MOVE | EditTool.SCALE | EditTool.ROTATE,[this.m_editGraphic]);
											}
											else if(this.m_lastActiveEdit == "rotateShape")
											{
												this.m_lastActiveEdit = "moveEditVertices";
												this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
												this.updateAttributeInspector(editFeatureLayer,this.m_editGraphic);
												this.map.infoWindow.show(this.m_editPoint);
											}
											
											
										}
										else
										{
											this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
											this.updateAttributeInspector(editFeatureLayer,this.m_editGraphic);
											this.map.infoWindow.show(this.m_editPoint);
										}
										this.addEditToolEventListeners();
									}
									else
									{
										this.updateAttributeInspector(editFeatureLayer,this.m_editGraphic);
										this.map.infoWindow.show(this.m_editPoint);
									}
									
								}
								else
								{
									this.m_editClearSelection = true;
									if((this.m_updateGeometryEnabled) && (this.checkIfGeometryUpdateIsAllowed(editFeatureLayer)) && (editFeatureLayer.isUpdateAllowed(this.m_editGraphic)))
									{
										CursorManager.setCursor(this.moveCursor,CursorManagerPriority.HIGH,-16,-16);
										this.m_lastActiveEdit = "moveEditVertices";
										this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
										this.addEditToolEventListeners();
									}
									this.clearSelection();
									editFeatureLayer.selectFeatures(this.m_query,FeatureLayer.SELECTION_NEW);
								}
								
							}
						}
					}
				}
				else
				{
					this.m_isEdit = true;
					this.m_doNotApplyEdits = false;
					this.m_editClearSelection = false;
					this.m_selectionMode = true;
					if(this.m_tempNewFeature)
					{
						this.map.infoWindow.hide();
						this.saveTempNewFeature();
					}
					else if(this.m_editGraphic)
					{
						this.saveUnsavedAttributes(this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer));
						this.m_attributeInspector.refreshActiveFeature();
					}
					
					if(this.m_visibleSelectionModeFeatureLayers.length > 0)
					{
						selectFeaturesFromSelectionModeLayers = function(selectionMode:String):void
						{
							var selectedFeatures:Array = null;
							var selection_resultHandler:Function = null;
							var selection_faultHandler:Function = null;
							selection_resultHandler = function(features:Array):void
							{
								var feature:Graphic = null;
								index = index + 1;
								if((features) && (features.length))
								{
									for each(feature in features)
									{
										selectedFeatures.push(feature);
									}
								}
								if(index < m_visibleSelectionModeFeatureLayers.length)
								{
									FeatureLayer(m_visibleSelectionModeFeatureLayers[index]).selectFeatures(m_query,selectionMode,new Responder(selection_resultHandler,selection_faultHandler));
								}
								else
								{
									m_isEdit = !(selectedFeatures.length == 0);
									m_lastActiveEdit = !(selectedFeatures.length == 0)?"moveEditVertices":"rotateShape";
								}
							};
							selection_faultHandler = function(fault:Fault):void
							{
								index = index + 1;
								if(index < m_visibleSelectionModeFeatureLayers.length)
								{
									FeatureLayer(m_visibleSelectionModeFeatureLayers[index]).selectFeatures(m_query,selectionMode,new Responder(selection_resultHandler,selection_faultHandler));
								}
								else
								{
									m_isEdit = !(selectedFeatures.length == 0);
									m_lastActiveEdit = !(selectedFeatures.length == 0)?"moveEditVertices":"rotateShape";
								}
							};
							FeatureLayer(m_visibleSelectionModeFeatureLayers[index]).selectFeatures(m_query,selectionMode,new Responder(selection_resultHandler,selection_faultHandler));
							selectedFeatures = [];
						};
						point = this.map.toScreen(this.map.toMapFromStage(event.stageX,event.stageY));
						mins = this.map.toMapXY(point.x - 3,point.y + 3);
						maxs = this.map.toMapXY(point.x + 3,point.y - 3);
						spatialReference = FeatureLayer(this.m_featureLayers[0]).map.spatialReference;
						selectionExtent = new Extent(mins.x,mins.y,maxs.x,maxs.y,spatialReference);
						this.m_query = new Query();
						this.m_query.geometry = selectionExtent;
						index = 0;
						if(!event.ctrlKey)
						{
							this.m_editClearSelection = true;
							this.clearSelection();
							selectFeaturesFromSelectionModeLayers(FeatureLayer.SELECTION_NEW);
						}
						else
						{
							this.map.infoWindow.hide();
							this.m_editTool.deactivate();
							this.removeEditToolEventListeners();
							CursorManager.removeCursor(CursorManager.currentCursorID);
							selectFeaturesFromSelectionModeLayers(FeatureLayer.SELECTION_ADD);
						}
					}
					else if(!event.ctrlKey)
					{
						this.finishEditing();
					}
					
				}
			}
		}
		
		private function updateAttributeInspector(editFeatureLayer:FeatureLayer, editGraphic:Graphic) : void {
			if(!editFeatureLayer.isUpdateAllowed(editGraphic))
			{
				this.m_attributeInspector.updateEnabled = false;
			}
			if(!editFeatureLayer.isDeleteAllowed(editGraphic))
			{
				this.m_attributeInspector.deleteButtonVisible = false;
			}
		}
		
		private function clearSelection() : void {
			var fLayer1:FeatureLayer = null;
			for each(fLayer1 in this.m_featureLayers)
			{
				if(fLayer1.selectedFeatures.length > 0)
				{
					fLayer1.clearSelection();
				}
			}
			if(this.m_toolbarVisible)
			{
				this.deleteButton.enabled = false;
			}
		}
		
		private function customContextMenuSelect(event:ContextMenuEvent) : void {
			CursorManager.removeCursor(CursorManager.currentCursorID);
		}
		
		private function editor_contextMenuHandler(event:EditEvent) : void {
			this.m_map.infoWindow.hide();
			if(!this.m_tempNewFeature)
			{
				this.m_graphicEditing = true;
				this.m_undoVertexDeleteGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
			}
		}
		
		private function editor_vertexDeleteHandler(event:EditEvent) : void {
			var undoVertexDelete:EditGeometryOperation = null;
			if(!this.m_tempNewFeature)
			{
				this.m_redoVertexDeleteGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
				if(!this.m_doNotApplyEdits)
				{
					this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
					undoVertexDelete = new EditGeometryOperation(this.m_undoVertexDeleteGraphicGeometry,this.m_redoVertexDeleteGraphicGeometry,this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer),this.m_editTool,this.m_lastActiveEdit);
					this.m_undoManager.pushUndo(undoVertexDelete);
					FeatureLayer(this.m_editGraphic.graphicsLayer).applyEdits(null,[this.m_editGraphic],null);
					this.updateEditInformation(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
					this.m_lastUpdateOperation = "edit geometry";
					this.operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
					if(!this.m_applyingEdits)
					{
						this.m_applyingEdits = true;
						invalidateSkinState();
					}
				}
			}
		}
		
		private function editor_ghostVertexMouseDownHandler(event:EditEvent) : void {
			this.m_map.infoWindow.hide();
			if(!this.m_tempNewFeature)
			{
				this.m_graphicEditing = true;
				this.m_undoVertexAddGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
			}
		}
		
		private function editor_vertexAddHandler(event:EditEvent) : void {
			var undoVertexAdd:EditGeometryOperation = null;
			this.m_map.infoWindow.hide();
			if(!this.m_tempNewFeature)
			{
				this.m_graphicEditing = false;
				this.m_redoVertexAddGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
				if(!this.m_doNotApplyEdits)
				{
					this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
					undoVertexAdd = new EditGeometryOperation(this.m_undoVertexAddGraphicGeometry,this.m_redoVertexAddGraphicGeometry,this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer),this.m_editTool,this.m_lastActiveEdit);
					this.m_undoManager.pushUndo(undoVertexAdd);
					FeatureLayer(this.m_editGraphic.graphicsLayer).applyEdits(null,[this.m_editGraphic],null);
					this.updateEditInformation(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
					this.m_lastUpdateOperation = "edit geometry";
					this.operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
					if(!this.m_applyingEdits)
					{
						this.m_applyingEdits = true;
						invalidateSkinState();
					}
				}
			}
		}
		
		private function editor_vertexMoveStartHandler(event:EditEvent) : void {
			this.m_map.infoWindow.hide();
			if(!this.m_tempNewFeature)
			{
				this.m_graphicEditing = true;
				this.m_undoVertexMoveGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
			}
		}
		
		private function editor_vertexMoveFirstHandler(event:EditEvent) : void {
			if(!this.m_tempNewFeature)
			{
				this.m_editTool.addEventListener(EditEvent.VERTEX_MOVE_STOP,this.editor_vertexMoveStopHandler);
			}
		}
		
		private function editor_vertexMoveStopHandler(event:EditEvent) : void {
			var undoVertexMove:EditGeometryOperation = null;
			this.m_graphicEditing = false;
			this.m_editTool.removeEventListener(EditEvent.VERTEX_MOVE_STOP,this.editor_vertexMoveStopHandler);
			this.m_redoVertexMoveGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
			if(!this.m_doNotApplyEdits)
			{
				this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				undoVertexMove = new EditGeometryOperation(this.m_undoVertexMoveGraphicGeometry,this.m_redoVertexMoveGraphicGeometry,this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer),this.m_editTool,this.m_lastActiveEdit);
				this.m_undoManager.pushUndo(undoVertexMove);
				FeatureLayer(this.m_editGraphic.graphicsLayer).applyEdits(null,[this.m_editGraphic],null);
				this.updateEditInformation(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				this.m_lastUpdateOperation = "edit geometry";
				this.operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
				if(!this.m_applyingEdits)
				{
					this.m_applyingEdits = true;
					invalidateSkinState();
				}
			}
		}
		
		private function editor_graphicMoveFirstHandler(event:EditEvent) : void {
			this.m_map.infoWindow.hide();
			if(!this.m_tempNewFeature)
			{
				this.m_graphicEditing = true;
				this.m_undoGraphicMoveGraphicGeometry = ObjectUtil.copy(event.graphics[0].geometry) as Geometry;
				this.m_editTool.addEventListener(EditEvent.GRAPHICS_MOVE_STOP,this.editor_graphicMoveStopHandler);
			}
		}
		
		private function editor_graphicMoveStopHandler(event:EditEvent) : void {
			var undoGraphicMove:EditGeometryOperation = null;
			this.m_graphicEditing = false;
			this.m_editTool.removeEventListener(EditEvent.GRAPHICS_MOVE_STOP,this.editor_graphicMoveStopHandler);
			this.m_redoGraphicMoveGraphicGeometry = ObjectUtil.copy(event.graphics[0].geometry) as Geometry;
			if(!this.m_doNotApplyEdits)
			{
				this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				undoGraphicMove = new EditGeometryOperation(this.m_undoGraphicMoveGraphicGeometry,this.m_redoGraphicMoveGraphicGeometry,this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer),this.m_editTool,this.m_lastActiveEdit);
				this.m_undoManager.pushUndo(undoGraphicMove);
				FeatureLayer(this.m_editGraphic.graphicsLayer).applyEdits(null,[this.m_editGraphic],null);
				this.updateEditInformation(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				this.m_lastUpdateOperation = "edit geometry";
				this.operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
				if(!this.m_applyingEdits)
				{
					this.m_applyingEdits = true;
					invalidateSkinState();
				}
			}
		}
		
		private function editor_rotateScaleVertexMoveStart(event:EditEvent) : void {
			this.m_map.infoWindow.hide();
			if(!this.m_tempNewFeature)
			{
				this.m_graphicEditing = true;
				this.m_undoGraphicScaleRotateGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
			}
		}
		
		private function editor_rotateScaleVertexMoveFirst(event:EditEvent) : void {
			if(!this.m_tempNewFeature)
			{
				this.m_editTool.addEventListener(EditEvent.GRAPHIC_ROTATE_STOP,this.editor_rotateScaleVertexMoveStop);
				this.m_editTool.addEventListener(EditEvent.GRAPHIC_SCALE_STOP,this.editor_rotateScaleVertexMoveStop);
			}
		}
		
		private function editor_rotateScaleVertexMoveStop(event:EditEvent) : void {
			var undoGraphicScaleRotate:EditGeometryOperation = null;
			this.m_graphicEditing = false;
			this.m_editTool.removeEventListener(EditEvent.GRAPHIC_ROTATE_STOP,this.editor_rotateScaleVertexMoveStop);
			this.m_editTool.removeEventListener(EditEvent.GRAPHIC_SCALE_STOP,this.editor_rotateScaleVertexMoveStop);
			this.m_redoGraphicScaleRotateGraphicGeometry = ObjectUtil.copy(event.graphic.geometry) as Geometry;
			if(!this.m_doNotApplyEdits)
			{
				this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				undoGraphicScaleRotate = new EditGeometryOperation(this.m_undoGraphicScaleRotateGraphicGeometry,this.m_redoGraphicScaleRotateGraphicGeometry,this.m_editGraphic,FeatureLayer(this.m_editGraphic.graphicsLayer),this.m_editTool,this.m_lastActiveEdit);
				this.m_undoManager.pushUndo(undoGraphicScaleRotate);
				FeatureLayer(this.m_editGraphic.graphicsLayer).applyEdits(null,[this.m_editGraphic],null);
				this.updateEditInformation(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				this.m_lastUpdateOperation = "edit geometry";
				this.operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
				if(!this.m_applyingEdits)
				{
					this.m_applyingEdits = true;
					invalidateSkinState();
				}
			}
		}
		
		private function activateEditToolAfterNormalize() : void {
			if(this.m_editGraphic)
			{
				if((this.m_editGraphic.geometry is Polyline) || (this.m_editGraphic.geometry is Polygon))
				{
					if((this.m_lastActiveEdit == "moveEditVertices") || (this.m_lastActiveEdit == null))
					{
						this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
					}
					else
					{
						this.m_editTool.activate(EditTool.MOVE | EditTool.SCALE | EditTool.ROTATE,[this.m_editGraphic]);
					}
				}
				else
				{
					this.m_editTool.activate(EditTool.EDIT_VERTICES | EditTool.MOVE,[this.m_editGraphic]);
				}
			}
		}
		
		private function addEditToolEventListeners() : void {
			this.m_editTool.addEventListener(EditEvent.CONTEXT_MENU_SELECT,this.editor_contextMenuHandler);
			this.m_editTool.addEventListener(EditEvent.GHOST_VERTEX_MOUSE_DOWN,this.editor_ghostVertexMouseDownHandler);
			this.m_editTool.addEventListener(EditEvent.VERTEX_ADD,this.editor_vertexAddHandler);
			this.m_editTool.addEventListener(EditEvent.VERTEX_DELETE,this.editor_vertexDeleteHandler);
			this.m_editTool.addEventListener(EditEvent.VERTEX_MOVE_START,this.editor_vertexMoveStartHandler);
			this.m_editTool.addEventListener(EditEvent.VERTEX_MOVE_FIRST,this.editor_vertexMoveFirstHandler);
			this.m_editTool.addEventListener(EditEvent.GRAPHICS_MOVE_FIRST,this.editor_graphicMoveFirstHandler);
			this.m_editTool.addEventListener(EditEvent.GRAPHIC_ROTATE_START,this.editor_rotateScaleVertexMoveStart);
			this.m_editTool.addEventListener(EditEvent.GRAPHIC_SCALE_START,this.editor_rotateScaleVertexMoveStart);
			this.m_editTool.addEventListener(EditEvent.GRAPHIC_ROTATE_FIRST,this.editor_rotateScaleVertexMoveFirst);
			this.m_editTool.addEventListener(EditEvent.GRAPHIC_SCALE_FIRST,this.editor_rotateScaleVertexMoveFirst);
		}
		
		private function removeEditToolEventListeners() : void {
			this.m_editTool.removeEventListener(EditEvent.CONTEXT_MENU_SELECT,this.editor_contextMenuHandler);
			this.m_editTool.removeEventListener(EditEvent.GHOST_VERTEX_MOUSE_DOWN,this.editor_ghostVertexMouseDownHandler);
			this.m_editTool.removeEventListener(EditEvent.VERTEX_ADD,this.editor_vertexAddHandler);
			this.m_editTool.removeEventListener(EditEvent.VERTEX_DELETE,this.editor_vertexDeleteHandler);
			this.m_editTool.removeEventListener(EditEvent.VERTEX_MOVE_START,this.editor_vertexMoveStartHandler);
			this.m_editTool.removeEventListener(EditEvent.VERTEX_MOVE_FIRST,this.editor_vertexMoveFirstHandler);
			this.m_editTool.removeEventListener(EditEvent.VERTEX_MOVE_STOP,this.editor_vertexMoveStopHandler);
			this.m_editTool.removeEventListener(EditEvent.GRAPHICS_MOVE_FIRST,this.editor_graphicMoveFirstHandler);
			this.m_editTool.removeEventListener(EditEvent.GRAPHICS_MOVE_STOP,this.editor_graphicMoveStopHandler);
			this.m_editTool.removeEventListener(EditEvent.GRAPHIC_ROTATE_START,this.editor_rotateScaleVertexMoveStart);
			this.m_editTool.removeEventListener(EditEvent.GRAPHIC_SCALE_START,this.editor_rotateScaleVertexMoveStart);
			this.m_editTool.removeEventListener(EditEvent.GRAPHIC_ROTATE_FIRST,this.editor_rotateScaleVertexMoveFirst);
			this.m_editTool.removeEventListener(EditEvent.GRAPHIC_SCALE_FIRST,this.editor_rotateScaleVertexMoveFirst);
		}
		
		private function attributeInspector_faultHandler(fault:Fault, token:Object=null) : void {
			this.m_applyingEdits = false;
			invalidateSkinState();
		}
		
		private function attributeInspector_editsCompleteHandler(featureEditResults:FeatureEditResults, token:Object=null) : void {
			var updateResult:FeatureEditResult = null;
			var feature:Graphic = null;
			var attributeObject:Object = null;
			var featureLayer:FeatureLayer = null;
			this.m_applyingEdits = false;
			invalidateSkinState();
			for each(updateResult in featureEditResults.updateResults)
			{
				feature = token.feature;
				if(updateResult.success === false)
				{
					for each(attributeObject in this.m_activeFeatureChangedAttributes)
					{
						feature.attributes[attributeObject.field.name] = this.m_activeFeatureChangedAttributes.oldValue;
					}
					if(this.attributeInspector.activeFeature === feature)
					{
						this.attributeInspector.refreshActiveFeature();
					}
				}
				else if((feature) && (feature.graphicsLayer))
				{
					if(feature.graphicsLayer is FeatureLayer)
					{
						featureLayer = feature.graphicsLayer as FeatureLayer;
						this.updateEditInformation(feature,featureLayer);
					}
					feature.refresh();
				}
				
				this.m_activeFeatureChangedAttributes = [];
			}
		}
		
		private function updateUndoRedoButtons() : void {
			if(this.m_undoManager.peekRedo())
			{
				this.m_undoManager.clearRedo();
			}
			if(this.m_toolbarVisible)
			{
				this.setButtonStates();
			}
		}
		
		private function findDynamicMapServiceLayer(featureLayer:FeatureLayer) : ArcGISDynamicMapServiceLayer {
			var arcgisDynamicMapServiceLayer:ArcGISDynamicMapServiceLayer = null;
			var featureServiceURL:String = null;
			var mapServiceURL:String = null;
			var layer:Layer = null;
			if(this.m_featureLayerToDynamicMapServiceLayer[featureLayer])
			{
				arcgisDynamicMapServiceLayer = this.m_featureLayerToDynamicMapServiceLayer[featureLayer];
			}
			else
			{
				featureServiceURL = featureLayer.url.substring(0,featureLayer.url.lastIndexOf("/"));
				mapServiceURL = featureServiceURL.replace("FeatureServer","MapServer");
				for each(layer in this.map.layers)
				{
					if((layer is ArcGISDynamicMapServiceLayer) && (ArcGISDynamicMapServiceLayer(layer).url == mapServiceURL))
					{
						if(featureLayer.gdbVersion)
						{
							if((ArcGISDynamicMapServiceLayer(layer).gdbVersion) && (ArcGISDynamicMapServiceLayer(layer).gdbVersion == featureLayer.gdbVersion))
							{
								arcgisDynamicMapServiceLayer = ArcGISDynamicMapServiceLayer(layer);
								this.m_featureLayerToDynamicMapServiceLayer[featureLayer] = arcgisDynamicMapServiceLayer;
								break;
							}
							continue;
						}
						arcgisDynamicMapServiceLayer = ArcGISDynamicMapServiceLayer(layer);
						this.m_featureLayerToDynamicMapServiceLayer[featureLayer] = arcgisDynamicMapServiceLayer;
						break;
					}
				}
			}
			return arcgisDynamicMapServiceLayer;
		}
		
		private function checkIfGeometryUpdateIsAllowed(featureLayer:FeatureLayer) : Boolean {
			var result:* = false;
			if(featureLayer.layerDetails is FeatureLayerDetails)
			{
				result = (featureLayer.layerDetails as FeatureLayerDetails).allowGeometryUpdates;
			}
			return result;
		}
		
		private function checkIfDeleteIsAllowed(featureLayer:FeatureLayer) : Boolean {
			var result:* = false;
			if(featureLayer.isEditable)
			{
				if(featureLayer.layerDetails is FeatureLayerDetails)
				{
					result = (featureLayer.layerDetails as FeatureLayerDetails).isDeleteAllowed;
				}
			}
			return result;
		}
		
		private function showAttributeInspector(graphic:Graphic) : void {
			var multipoint:Multipoint = null;
			var polyline:Polyline = null;
			var polygon:Polygon = null;
			switch(graphic.geometry.type)
			{
				case Geometry.MAPPOINT:
					this.map.infoWindow.show(graphic.geometry as MapPoint,this.m_stagePointInfoWindow);
					break;
				case Geometry.MULTIPOINT:
					multipoint = graphic.geometry as Multipoint;
					this.map.infoWindow.show(multipoint.points[0] as MapPoint,this.m_stagePointInfoWindow);
					break;
				case Geometry.POLYLINE:
					polyline = graphic.geometry as Polyline;
					this.map.infoWindow.show((polyline.paths[0] as Array)[0] as MapPoint,this.m_stagePointInfoWindow);
					break;
				case Geometry.POLYGON:
					polygon = graphic.geometry as Polygon;
					if((!isNaN(polygon.extent.center.x)) && (!isNaN(polygon.extent.center.y)))
					{
						this.map.infoWindow.show((polygon.rings[0] as Array)[0] as MapPoint,this.m_stagePointInfoWindow);
					}
					break;
			}
			this.map.infoWindow.closeButton.addEventListener(MouseEvent.MOUSE_DOWN,this.infoWindowCloseButtonMouseDownHandler);
		}
		
		private function removeTempNewGraphic() : void {
			if(this.m_deletingTempGraphic)
			{
				this.m_attributeInspector.refresh();
				this.m_deletingTempGraphic = false;
			}
			this.map.defaultGraphicsLayer.remove(this.m_tempNewFeature);
			this.m_tempNewFeature = null;
			this.m_activeFeatureChangedAttributes = [];
			if(this.m_toolbarVisible)
			{
				this.deleteButton.enabled = false;
			}
		}
		
		private function finishEditing() : void {
			this.m_infoWindowCloseButtonClicked = false;
			this.m_lastActiveEdit = "";
			this.m_isEdit = false;
			this.m_doNotApplyEdits = true;
			if(this.m_editGraphic)
			{
				this.m_editGraphic = null;
			}
			CursorManager.removeCursor(CursorManager.currentCursorID);
			this.m_editTool.deactivate();
			this.removeEditToolEventListeners();
			this.m_stagePointInfoWindow = null;
			this.map.infoWindow.hide();
			this.clearSelection();
		}
		
		private function infoWindowCloseButtonMouseDownHandler(event:MouseEvent) : void {
			this.map.infoWindow.closeButton.removeEventListener(MouseEvent.MOUSE_DOWN,this.infoWindowCloseButtonMouseDownHandler);
			if(this.m_tempNewFeature)
			{
				this.saveTempNewFeature();
			}
			else
			{
				this.saveUnsavedAttributes(this.attributeInspector.activeFeature,this.attributeInspector.activeFeatureLayer);
				this.m_attributeInspector.refreshActiveFeature();
			}
		}
		
		private function saveTempNewFeature() : void {
			if(this.m_attributeInspector.validate())
			{
				this.addNewFeature(this.m_tempNewFeature,this.m_tempNewFeatureLayer);
			}
			else
			{
				this.m_deletingTempGraphic = true;
				this.removeTempNewGraphic();
				this.map.infoWindow.hide();
			}
		}
		
		private function saveUnsavedAttributes(feature:Graphic, featureLayer:FeatureLayer) : void {
			var attributes:Object = null;
			var objectIdField:String = null;
			var attributeObject:Object = null;
			var attributeUpdateOperation:EditAttributesOperation = null;
			var feature1:Graphic = null;
			var updates:Array = null;
			if(this.m_activeFeatureChangedAttributes.length)
			{
				attributes = {};
				objectIdField = featureLayer.layerDetails.objectIdField;
				attributes[objectIdField] = feature.attributes[objectIdField];
				for each(attributeObject in this.m_activeFeatureChangedAttributes)
				{
					attributes[attributeObject.field.name] = attributeObject.newValue;
					feature.attributes[attributeObject.field.name] = attributeObject.newValue;
				}
				attributeUpdateOperation = new EditAttributesOperation(feature,this.m_activeFeatureChangedAttributes,this.attributeInspector);
				this.m_undoManager.pushUndo(attributeUpdateOperation);
				callLater(this.updateUndoRedoButtons);
				feature1 = new Graphic(null,null,attributes);
				updates = [feature1];
				featureLayer.applyEdits(null,updates,null,false,new AsyncResponder(this.attributeInspector_editsCompleteHandler,this.attributeInspector_faultHandler,{"feature":feature}));
				this.m_lastUpdateOperation = "edit attribute";
				this.operationStartLabel.text = UPDATE_FEATURE_OPERATION_START;
				if(!this.m_applyingEdits)
				{
					this.m_applyingEdits = true;
					invalidateSkinState();
				}
			}
		}
		
		private function updateEditInformation(feature:Graphic, featureLayer:FeatureLayer) : void {
			var userId:String = null;
			var editFieldsInfo:EditFieldsInfo = featureLayer.editFieldsInfo;
			if((editFieldsInfo) && (editFieldsInfo.editorField))
			{
				if(featureLayer.userId)
				{
					userId = featureLayer.userId;
					feature.attributes[editFieldsInfo.editorField] = editFieldsInfo.realm?userId + "@" + editFieldsInfo.realm:userId;
				}
				else
				{
					feature.attributes[editFieldsInfo.editorField] = "";
				}
			}
			if((editFieldsInfo) && (editFieldsInfo.editDateField))
			{
				feature.attributes[editFieldsInfo.editDateField] = new Date().time;
			}
			if(this.attributeInspector.activeFeature === feature)
			{
				this.attributeInspector.refreshActiveFeature();
			}
		}
		
		private function refreshDynamicMapServiceLayer(featureLayer:FeatureLayer) : void {
			var dynamicMapServiceLayer:ArcGISDynamicMapServiceLayer = null;
			if(featureLayer.mode == FeatureLayer.MODE_SELECTION)
			{
				dynamicMapServiceLayer = this.findDynamicMapServiceLayer(featureLayer);
				if(dynamicMapServiceLayer)
				{
					dynamicMapServiceLayer.refresh();
				}
			}
		}
		
		public function set updateAttributesEnabled(param1:Boolean) : void {
			var _loc3_:Object = this.updateAttributesEnabled;
			if(_loc3_ !== param1)
			{
				this._546952159updateAttributesEnabled = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"updateAttributesEnabled",_loc3_,param1));
				}
			}
		}
		
		public function set toolbarMergeVisible(param1:Boolean) : void {
			var _loc3_:Object = this.toolbarMergeVisible;
			if(_loc3_ !== param1)
			{
				this._1160858571toolbarMergeVisible = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"toolbarMergeVisible",_loc3_,param1));
				}
			}
		}
		
		public function set updateGeometryEnabled(param1:Boolean) : void {
			var _loc3_:Object = this.updateGeometryEnabled;
			if(_loc3_ !== param1)
			{
				this._1030763930updateGeometryEnabled = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"updateGeometryEnabled",_loc3_,param1));
				}
			}
		}
		
		public function set addEnabled(param1:Boolean) : void {
			var _loc3_:Object = this.addEnabled;
			if(_loc3_ !== param1)
			{
				this._298640224addEnabled = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"addEnabled",_loc3_,param1));
				}
			}
		}
		
		public function set createOptions(param1:CreateOptions) : void {
			var _loc3_:Object = this.createOptions;
			if(_loc3_ !== param1)
			{
				this._997042690createOptions = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"createOptions",_loc3_,param1));
				}
			}
		}
		
		public function set featureLayers(param1:Array) : void {
			var _loc3_:Object = this.featureLayers;
			if(_loc3_ !== param1)
			{
				this._1730434088featureLayers = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"featureLayers",_loc3_,param1));
				}
			}
		}
		
		public function set undoAndRedoItemLimit(param1:int) : void {
			var _loc3_:Object = this.undoAndRedoItemLimit;
			if(_loc3_ !== param1)
			{
				this._1765640073undoAndRedoItemLimit = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"undoAndRedoItemLimit",_loc3_,param1));
				}
			}
		}
		
		public function set toolbarVisible(param1:Boolean) : void {
			var _loc3_:Object = this.toolbarVisible;
			if(_loc3_ !== param1)
			{
				this._1563241591toolbarVisible = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"toolbarVisible",_loc3_,param1));
				}
			}
		}
		
		public function set map(param1:Map) : void {
			var _loc3_:Object = this.map;
			if(_loc3_ !== param1)
			{
				this._107868map = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"map",_loc3_,param1));
				}
			}
		}
		
		public function set showTemplateSwatchOnCursor(param1:Boolean) : void {
			var _loc3_:Object = this.showTemplateSwatchOnCursor;
			if(_loc3_ !== param1)
			{
				this._1701569304showTemplateSwatchOnCursor = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"showTemplateSwatchOnCursor",_loc3_,param1));
				}
			}
		}
		
		public function set geometryService(param1:GeometryService) : void {
			var _loc3_:Object = this.geometryService;
			if(_loc3_ !== param1)
			{
				this._1579241955geometryService = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"geometryService",_loc3_,param1));
				}
			}
		}
		
		public function set deleteEnabled(param1:Boolean) : void {
			var _loc3_:Object = this.deleteEnabled;
			if(_loc3_ !== param1)
			{
				this._1814366442deleteEnabled = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"deleteEnabled",_loc3_,param1));
				}
			}
		}
		
		public function set toolbarCutVisible(param1:Boolean) : void {
			var _loc3_:Object = this.toolbarCutVisible;
			if(_loc3_ !== param1)
			{
				this._1691214251toolbarCutVisible = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"toolbarCutVisible",_loc3_,param1));
				}
			}
		}
		
		public function set toolbarReshapeVisible(param1:Boolean) : void {
			var _loc3_:Object = this.toolbarReshapeVisible;
			if(_loc3_ !== param1)
			{
				this._385871969toolbarReshapeVisible = param1;
				if(this.hasEventListener("propertyChange"))
				{
					this.dispatchEvent(PropertyChangeEvent.createUpdateEvent(this,"toolbarReshapeVisible",_loc3_,param1));
				}
			}
		}
		
		override protected function get skinParts() : Object {
			return _skinParts;
		}
		
	}
}