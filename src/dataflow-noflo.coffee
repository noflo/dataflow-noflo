# Make types
# Dependencies
Base = Dataflow::node("base")
NofloBase = Dataflow::node("noflo-base")

NofloBase.Model = Base.Model.extend(
  defaults: ->
    defaults = Base.Model::defaults.call(this)
    defaults.type = "noflo-base"
    defaults

  initialize: ->
    Base.Model::initialize.call this

  unload: ->
    # Stop any processes that need to be stopped

  toJSON: ->
    json = Base.Model::toJSON.call(this)
    json

  inputs: []
  outputs: []
)

NofloBase.View = Base.View.extend(initialize: ->
  Base.View::initialize.call this
)

baseExtender = (name, component) ->
  inputs = []
  for inName of component.inPorts
    nfi = component.inPorts[inName]
    dfi =
      id: inName
      type: nfi.type 
    inputs.push dfi
  outputs = []
  for outName of component.outPorts
    nfo = component.outPorts[outName]
    dfo =
      id: outName
      type: nfo.type
    outputs.push dfo
  extender =
    defaults: ->
      defaults = NofloBase.Model::defaults.call(this)
      defaults.type = name
      defaults
    inputs: inputs
    outputs: outputs

  extender

makeDataflowNode = (name, component) ->
  newType = Dataflow::node(name)
  newType.Model = NofloBase.Model.extend( baseExtender(name, component) )
  newType.View = NofloBase.View.extend()


# Make plugin
DataflowNoflo = Dataflow::plugin("noflo")
DataflowNoflo.initialize = (dataflow) ->
  noflo = require("noflo")
  DataflowNoflo.registerGraph = (graph) ->
    
    # Plugin: library
    cl = new noflo.ComponentLoader()
    cl.baseDir = graph.baseDir
    cl.listComponents (types) ->
      for name of types
        cl.load name, (component) ->
          makeDataflowNode name, component

    # Might have to wait for the load callbacks
    dataflow.plugins.library.update exclude: ["base", "noflo-base"]
    
    # Plugin: source
    dataflow.plugins.source.listeners false ;

    sourceChanged = (graph) -> 
      dataflow.plugins.source.show( JSON.stringify graph.toJSON(), null, 2 )

    sourceChanged graph
    
    # Plugin: log
    dataflow.plugins.log.listeners false;

    graph.on "addNode", (node) ->
      dataflow.plugins.log.add "node added: " + JSON.stringify(node)
      sourceChanged graph

    graph.on "removeNode", (node) ->
      dataflow.plugins.log.add "node removed: " + JSON.stringify(node)
      sourceChanged graph

    graph.on "addEdge", (edge) ->
      dataflow.plugins.log.add "edge added: " + JSON.stringify(edge)
      sourceChanged graph

    graph.on "removeEdge", (edge) ->
      dataflow.plugins.log.add "edge removed: " + JSON.stringify(edge)
      sourceChanged graph
    
    # -
    # Sync Dataflow and Noflo graphs
    # -

    dataflowGraph = dataflow.loadGraph({})
    dataflowGraph.nofloGraph = graph
    graph.dataflowGraph = dataflowGraph

    # -    
    # Noflo to Dataflow
    # -    

    graph.on "addNode", (node) ->
      unless node.dataflowNode?
        type = dataflow.node(node.component)
        dfNode = new type.Model(
          id: node.id
          label: node.id
          x: (if node.metadata.x isnt `undefined` then node.metadata.x else Math.floor(Math.random() * 800))
          y: (if node.metadata.y isnt `undefined` then node.metadata.y else Math.floor(Math.random() * 600))
          parentGraph: dataflowGraph
        )
        # Reference each other
        dfNode.nofloNode = node
        node.dataflowNode = dfNode
        # Add to graph
        dataflowGraph.nodes.add dfNode
      node.dataflowNode

    graph.on "addEdge", (edge) ->
      if edge.from.node? and edge.to.node?
        # Add edge
        unless edge.dataflowEdge?
          Edge = dataflow.module("edge");
          dfEdge = new Edge.Model(
            id: edge.from.node + ":" + edge.from.port + "::" + edge.to.node + ":" + edge.to.port
            parentGraph: dataflowGraph
            source:
              node: edge.from.node
              port: edge.from.port
            target:
              node: edge.to.node
              port: edge.to.port
          )
          # Reference each other
          dfEdge.nofloEdge = edge;
          edge.dataflowEdge = dfEdge;
          # Add to graph
          dataflowGraph.edges.add dfEdge

      else if edge.from.data? and edge.to.node?
        # Set IIP
        node = dataflowGraph.nodes.get(edge.to.node)
        if node
          port = node.inputs.get(edge.to.port)
          if port
            node.setState edge.to.port, edge.from.data
            if port.view
              port.view.$("input").val edge.from.data
        else
          #TODO: added IIP before node?

    graph.on "removeNode", (node) ->
      if node.dataflowNode?
        node.dataflowNode.remove()

    graph.on "removeEdge", (edge) ->
      if edge.from.node? and edge.to.node?
        if edge.dataflowEdge?
          edge.dataflowEdge.remove()

    # -    
    # Dataflow to Noflo
    # -

    dataflow.on "node:add", (dfGraph, node) -> 
      unless node.nofloNode?
        node.nofloNode = graph.addNode node.id, node.type, 
          x: node.get "x"
          y: node.get "y"

    dataflow.on "edge:add", (dfGraph, edge) -> 
      unless edge.nofloEdge?
        edge.nofloEdge = graph.addEdge edge.source.parentNode.id, edge.source.id, edge.target.parentNode.id, edge.target.id

    dataflow.on "node:remove", (dfGraph, node) -> 
      if node.nofloNode?
        graph.removeNode node.nofloNode.id

    dataflow.on "edge:remove", (dfGraph, edge) -> 
      if edge.nofloEdge?
        # graph.removeEdge edge.source.parentNode.id, edge.source.id
        for _edge,index in graph.edges
          if _edge is edge
            graph.emit 'removeEdge', edge
            graph.edges.splice index, 1


    # return
    dataflowGraph



# Dataflow::loadGraph = (graph) ->
#   g = new noflo.Graph graph ;
#   DataflowNoflo.registerGraph g ;
#   g
