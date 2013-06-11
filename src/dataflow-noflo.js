( function(Dataflow) {
 
  var DataflowNoflo = Dataflow.prototype.plugin("noflo");

  DataflowNoflo.initialize = function(dataflow){

    var noflo = require('noflo');

    DataflowNoflo.registerGraph = function(graph) {
      // Show graph

      // Plugin: library
      var cl = new noflo.ComponentLoader();
      cl.baseDir = graph.baseDir;
      cl.listComponents(function(c){
        console.log( c );
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
      graph.on("addEdge", function(edge){
        dataflow.plugins.log.add( "edge added: " + JSON.stringify(edge) );
        sourceChanged(graph);
      });
      graph.on("removeNode", function(node){
        dataflow.plugins.log.add( "node removed: " + JSON.stringify(node) );
        sourceChanged(graph);
      });
      graph.on("removeEdge", function(edge){
        dataflow.plugins.log.add( "edge removed: " + JSON.stringify(edge) );
        sourceChanged(graph);
      });

    };

    Dataflow.prototype.loadGraph = function (graph) {
      var g = new noflo.Graph(graph);
      DataflowNoflo.registerGraph(g);
      return g;
    };

  };

}(Dataflow) );
