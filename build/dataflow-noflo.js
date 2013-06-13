(function() {
  var Base, DataflowNoflo, NofloBase, baseExtender, makeDataflowNode;

  Base = Dataflow.prototype.node("base");

  NofloBase = Dataflow.prototype.node("noflo-base");

  NofloBase.Model = Base.Model.extend({
    defaults: function() {
      var defaults;
      defaults = Base.Model.prototype.defaults.call(this);
      defaults.type = "noflo-base";
      return defaults;
    },
    initialize: function() {
      return Base.Model.prototype.initialize.call(this);
    },
    unload: function() {},
    toJSON: function() {
      var json;
      json = Base.Model.prototype.toJSON.call(this);
      return json;
    },
    inputs: [],
    outputs: []
  });

  NofloBase.View = Base.View.extend({
    initialize: function() {
      return Base.View.prototype.initialize.call(this);
    }
  });

  baseExtender = function(name, component) {
    var dfi, dfo, extender, inName, inputs, nfi, nfo, outName, outputs;
    inputs = [];
    for (inName in component.inPorts) {
      nfi = component.inPorts[inName];
      dfi = {
        id: inName,
        type: nfi.type
      };
      inputs.push(dfi);
    }
    outputs = [];
    for (outName in component.outPorts) {
      nfo = component.outPorts[outName];
      dfo = {
        id: outName,
        type: nfo.type
      };
      outputs.push(dfo);
    }
    extender = {
      defaults: function() {
        var defaults;
        defaults = NofloBase.Model.prototype.defaults.call(this);
        defaults.type = name;
        return defaults;
      },
      inputs: inputs,
      outputs: outputs
    };
    return extender;
  };

  makeDataflowNode = function(name, component) {
    var newType;
    newType = Dataflow.prototype.node(name);
    newType.Model = NofloBase.Model.extend(baseExtender(name, component));
    return newType.View = NofloBase.View.extend();
  };

  DataflowNoflo = Dataflow.prototype.plugin("noflo");

  DataflowNoflo.initialize = function(dataflow) {
    var noflo;
    noflo = require("noflo");
    return DataflowNoflo.registerGraph = function(graph) {
      var cl, dataflowGraph, sourceChanged;
      cl = new noflo.ComponentLoader();
      cl.baseDir = graph.baseDir;
      cl.listComponents(function(types) {
        var name, _results;
        _results = [];
        for (name in types) {
          _results.push(cl.load(name, function(component) {
            return makeDataflowNode(name, component);
          }));
        }
        return _results;
      });
      dataflow.plugins.library.update({
        exclude: ["base", "base-resizable", "test", "noflo-base"]
      });
      dataflow.plugins.source.listeners(false);
      sourceChanged = function(graph) {
        return dataflow.plugins.source.show(JSON.stringify(graph.toJSON(), null, 2));
      };
      sourceChanged(graph);
      dataflow.plugins.log.listeners(false);
      graph.on("addNode", function(node) {
        dataflow.plugins.log.add("node added: " + JSON.stringify(node));
        return sourceChanged(graph);
      });
      graph.on("removeNode", function(node) {
        dataflow.plugins.log.add("node removed: " + JSON.stringify(node));
        return sourceChanged(graph);
      });
      graph.on("addEdge", function(edge) {
        dataflow.plugins.log.add("edge added: " + JSON.stringify(edge));
        return sourceChanged(graph);
      });
      graph.on("removeEdge", function(edge) {
        dataflow.plugins.log.add("edge removed: " + JSON.stringify(edge));
        return sourceChanged(graph);
      });
      dataflowGraph = dataflow.loadGraph({});
      dataflowGraph.nofloGraph = graph;
      graph.dataflowGraph = dataflowGraph;
      graph.on("addNode", function(node) {
        var dfNode, type;
        if (node.dataflowNode == null) {
          type = dataflow.node(node.component);
          dfNode = new type.Model({
            id: node.id,
            label: node.id,
            x: (node.metadata.x !== undefined ? node.metadata.x : Math.floor(Math.random() * 800)),
            y: (node.metadata.y !== undefined ? node.metadata.y : Math.floor(Math.random() * 600)),
            parentGraph: dataflowGraph
          });
          dfNode.nofloNode = node;
          node.dataflowNode = dfNode;
          dataflowGraph.nodes.add(dfNode);
        }
        return node.dataflowNode;
      });
      graph.on("addEdge", function(edge) {
        var Edge, dfEdge, node, port;
        if ((edge.from.node != null) && (edge.to.node != null)) {
          if (edge.dataflowEdge == null) {
            Edge = dataflow.module("edge");
            dfEdge = new Edge.Model({
              id: edge.from.node + ":" + edge.from.port + "::" + edge.to.node + ":" + edge.to.port,
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
            dfEdge.nofloEdge = edge;
            edge.dataflowEdge = dfEdge;
            return dataflowGraph.edges.add(dfEdge);
          }
        } else if ((edge.from.data != null) && (edge.to.node != null)) {
          node = dataflowGraph.nodes.get(edge.to.node);
          if (node) {
            port = node.inputs.get(edge.to.port);
            if (port) {
              node.setState(edge.to.port, edge.from.data);
              if (port.view) {
                return port.view.$("input").val(edge.from.data);
              }
            }
          } else {

          }
        }
      });
      graph.on("removeNode", function(node) {
        if (node.dataflowNode != null) {
          return node.dataflowNode.remove();
        }
      });
      graph.on("removeEdge", function(edge) {
        if ((edge.from.node != null) && (edge.to.node != null)) {
          if (edge.dataflowEdge != null) {
            return edge.dataflowEdge.remove();
          }
        }
      });
      dataflow.on("node:add", function(dfGraph, node) {
        if (node.nofloNode == null) {
          return node.nofloNode = graph.addNode(node.id, node.type, {
            x: node.get("x"),
            y: node.get("y")
          });
        }
      });
      dataflow.on("edge:add", function(dfGraph, edge) {
        if (edge.nofloEdge == null) {
          return edge.nofloEdge = graph.addEdge(edge.source.parentNode.id, edge.source.id, edge.target.parentNode.id, edge.target.id);
        }
      });
      dataflow.on("node:remove", function(dfGraph, node) {
        if (node.nofloNode != null) {
          return graph.removeNode(node.nofloNode.id);
        }
      });
      dataflow.on("edge:remove", function(dfGraph, edge) {
        if (edge.nofloEdge != null) {
          return graph.removeEdge(edge.source.parentNode.id, edge.source.id);
        }
      });
      return dataflowGraph;
    };
  };

}).call(this);
