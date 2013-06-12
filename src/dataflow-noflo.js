( function(Dataflow) {
 
  // Make types
  // Dependencies
  var Base = Dataflow.prototype.node("base");
  var NofloBase = Dataflow.prototype.node("noflo-base");

  NofloBase.Model = Base.Model.extend({
    defaults: function(){
      var defaults = Base.Model.prototype.defaults.call(this);
      defaults.type = "noflo-base";
      return defaults;
    },
    initialize: function() {
      Base.Model.prototype.initialize.call(this);
    },
    unload: function(){
      // Stop any processes that need to be stopped
    },
    toJSON: function(){
      var json = Base.Model.prototype.toJSON.call(this);
      return json;
    },
    inputs:[],
    outputs:[]
  });

  NofloBase.View = Base.View.extend({
    initialize: function() {
      Base.View.prototype.initialize.call(this);
    }
  });

  var baseExtender = function(name, component) {
    console.log(component);
    var inputs = [];
    for (var inName in component.inPorts) {
      var nfi = component.inPorts[inName];
      var dfi = {
        "id": inName, 
        "type": nfi.type
      };
      inputs.push(dfi);
    }
    var outputs = [];
    for (var outName in component.outPorts) {
      var nfo = component.outPorts[outName];
      var dfo = {
        "id": outName, 
        "type": nfo.type
      };
      outputs.push(dfo);
    }
    return {
      defaults: function(){
        var defaults = NofloBase.Model.prototype.defaults.call(this);
        defaults.type = name;
        return defaults;
      },
      inputs: inputs,
      outputs: outputs
    };
  };

  var makeDataflowNode = function(name, component) {
    var newType = Dataflow.prototype.node(name);
    newType.Model = NofloBase.Model.extend( baseExtender(name, component) );
    newType.View = NofloBase.View.extend();
  };


  // Make plugin
  var DataflowNoflo = Dataflow.prototype.plugin("noflo");

  DataflowNoflo.initialize = function(dataflow){

    var noflo = require('noflo');

    DataflowNoflo.registerGraph = function(graph) {
      // Show graph
      dataflow.loadGraph({});

      // Plugin: library
      var cl = new noflo.ComponentLoader();
      cl.baseDir = graph.baseDir;
      cl.listComponents(function(types){
        for (name in types) {
          cl.load(name, function(component){
            makeDataflowNode(name, component);
          });
        }
      });
      // Might have to wait for the load callbacks
      dataflow.plugins.library.update({
        exclude: ["base", "base-resizable", "test", "noflo-base"]
      });


      // Plugin: source
      var sourceChanged = function(graph) {
        dataflow.plugins.source.show( JSON.stringify(graph.toJSON(), null, 2) );
      };
      sourceChanged(graph);

      // Plugin: log
      graph.on("addNode", function(node){
        dataflow.plugins.log.add( "node added: " + JSON.stringify(node) );
        sourceChanged(graph);
      });
      graph.on("removeNode", function(node){
        dataflow.plugins.log.add( "node removed: " + JSON.stringify(node) );
        sourceChanged(graph);
      });
      graph.on("addEdge", function(edge){
        dataflow.plugins.log.add( "edge added: " + JSON.stringify(edge) );
        sourceChanged(graph);
      });
      graph.on("removeEdge", function(edge){
        dataflow.plugins.log.add( "edge removed: " + JSON.stringify(edge) );
        sourceChanged(graph);
      });

    };

    // Dataflow.prototype.loadGraph = function (graph) {
    //   var g = new noflo.Graph(graph);
    //   DataflowNoflo.registerGraph(g);
    //   return g;
    // };

  };

}(Dataflow) );
