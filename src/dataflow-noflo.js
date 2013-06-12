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


      // Sync Dataflow and Noflo graphs
      var dataflowGraph = dataflow.loadGraph({});

      // Noflo to Dataflow
      graph.on("addNode", function(node){
        var type = dataflow.node(node.component);
        var dfNode = new type.Model({
          id: node.id,
          label: node.id,
          x: node.metadata.x !== undefined ? node.metadata.x : Math.floor(Math.random()*800),
          y: node.metadata.y !== undefined ? node.metadata.y : Math.floor(Math.random()*600),
          parentGraph: dataflowGraph
        });
        dataflowGraph.nodes.add(dfNode);
      });
      graph.on("removeNode", function(node){
      });
      graph.on("addEdge", function(edge){
        if (edge.from.node) {
          // Add edge
          dataflowGraph.edges.add({
            id: edge.from.node+":"+edge.from.port+"→"+edge.to.node+":"+edge.to.port,
            parentGraph: dataflowGraph,
            source: {
              node: edge.from.node,
              port: edge.from.port
            },
            target: {
              node: edge.to.node,
              port: edge.to.port
            }
          });
        } else {
          // Set IIP
          var node = dataflowGraph.nodes.get( edge.to.node );
          if (node) {
            var port = node.inputs.get( edge.to.port );
            if (port) {
              node.setState(edge.to.port, edge.from.data);
              if (port.view) {
                port.view.$("input").val(edge.from.data);
              }
            }
          } else {
            // TODO
          }
        }

      });
      graph.on("removeEdge", function(edge){
      });

    };

    // Dataflow.prototype.loadGraph = function (graph) {
    //   var g = new noflo.Graph(graph);
    //   DataflowNoflo.registerGraph(g);
    //   return g;
    // };

  };

}(Dataflow) );
