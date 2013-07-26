{Dataflow} = require '/meemoo-dataflow'
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

NofloBase.View = Base.View.extend
  initialize: (options) ->
    Base.View::initialize.call this, options

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

makeDataflowNodeProto = (name, component) ->
  newType = Dataflow::node(name)
  newType.Model = NofloBase.Model.extend( baseExtender(name, component) )
  newType.View = NofloBase.View.extend()


# Make plugin
DataflowNoflo = Dataflow::plugin("noflo")
DataflowNoflo.initialize = (dataflow) ->

  noflo = require("noflo")
  DataflowNoflo.registerGraph = (nofloGraph) ->

    # -
    # Sync Dataflow and Noflo graphs
    # -

    dataflowGraph = dataflow.loadGraph({})
    dataflowGraph.nofloGraph = nofloGraph
    nofloGraph.dataflowGraph = dataflowGraph

    # contextBar action: rename
    dataflow.addContext(
      id: "rename"
      icon: "edit"
      label: "rename"
      action: ->
        if dataflowGraph.selected.length > 0
          selected = dataflowGraph.selected[0]
          if selected.view
            selected.view.showControls()
      contexts: ["one"]
    )
    
    # Plugin: library
    cl = new noflo.ComponentLoader()
    cl.baseDir = nofloGraph.baseDir
    cl.listComponents (types) ->
      for name of types
        cl.load name, (component) ->
          makeDataflowNodeProto name, component

    # Might have to wait for the load callbacks?
    dataflow.plugins.library.update exclude: ["base", "noflo-base"]
    
    # Plugin: source
    dataflow.plugins.source.listeners false

    sourceChanged = (o) -> 
      dataflow.plugins.source.show( JSON.stringify(o.toJSON(), null, 2) )

    # When df graph changes update source with nf graph
    dataflowGraph.on "change", (dfGraph) ->
      sourceChanged nofloGraph
    
    # Plugin: log
    dataflow.plugins.log.listeners false

    nofloGraph.on "addNode", (node) ->
      dataflow.plugins.log.add "node added: " + JSON.stringify(node)

    nofloGraph.on "removeNode", (node) ->
      dataflow.plugins.log.add "node removed: " + JSON.stringify(node)

    nofloGraph.on "addEdge", (edge) ->
      dataflow.plugins.log.add "edge added: " + JSON.stringify(edge)

    nofloGraph.on "addInitial", (iip) ->
      dataflow.plugins.log.add "IIP added: " + JSON.stringify(iip)

    nofloGraph.on "removeEdge", (edge) ->
      dataflow.plugins.log.add "edge removed: " + JSON.stringify(edge)
    
    # -    
    # Noflo to Dataflow
    # -

    nofloGraph.on "addNode", (node) ->
      DataflowNoflo.addNode node, dataflowGraph

    nofloGraph.on "addEdge", (edge) ->
      DataflowNoflo.addEdge edge, dataflowGraph

    nofloGraph.on "addInitial", (iip) ->
      DataflowNoflo.addInitial iip, dataflowGraph

    nofloGraph.on "removeNode", (node) ->
      if node.dataflowNode?
        node.dataflowNode.remove()

    nofloGraph.on "removeEdge", (edge) ->
      if edge.from.node? and edge.to.node?
        if edge.dataflowEdge?
          edge.dataflowEdge.remove()

    # -    
    # Dataflow to Noflo
    # -

    dataflow.on "node:add", (dfGraph, node) -> 
      unless node.nofloNode?
        node.nofloNode = nofloGraph.addNode node.id, node.type, 
          x: node.get "x"
          y: node.get "y"
      # sync rename
      node.on "change:label", (node, newName) ->
        oldName = node.nofloNode.id
        node.nofloNode.id = newName
        for edge, index in nofloGraph.edges
          if edge.from? and edge.from.node is oldName
            edge.from.node = newName
          if edge.to? and edge.to.node is oldName
            edge.to.node = newName

    dataflow.on "edge:add", (dfGraph, edge) -> 
      unless edge.nofloEdge?
        edge.nofloEdge = nofloGraph.addEdge edge.source.parentNode.id, edge.source.id, edge.target.parentNode.id, edge.target.id

    dataflow.on "node:remove", (dfGraph, node) -> 
      if node.nofloNode?
        nofloGraph.removeNode node.nofloNode.id

    dataflow.on "edge:remove", (dfGraph, edge) -> 
      if edge.nofloEdge?
        for _edge, index in nofloGraph.edges
          if _edge is edge.nofloEdge
            nofloGraph.emit 'removeEdge', edge.nofloEdge
            nofloGraph.edges.splice index, 1 

    DataflowNoflo.addNode node, dataflowGraph for node in nofloGraph.nodes
    DataflowNoflo.addEdge edge, dataflowGraph for edge in nofloGraph.edges
    DataflowNoflo.addInitial iip, dataflowGraph for iip in nofloGraph.initializers

    # return
    dataflowGraph

  DataflowNoflo.addNode = (node, dataflowGraph) ->
    unless node.dataflowNode?
      type = dataflow.node(node.component)
      dfNode = new type.Model(
        id: node.id
        label: node.id
        x: ( if node.metadata.x? then node.metadata.x else 300 )
        y: ( if node.metadata.y? then node.metadata.y else 300 )
        parentGraph: dataflowGraph
      )
      # Reference each other
      dfNode.nofloNode = node
      node.dataflowNode = dfNode
      # Add to graph
      dataflowGraph.nodes.add dfNode
    node.dataflowNode

  DataflowNoflo.addEdge = (edge, dataflowGraph) ->
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

  DataflowNoflo.addInitial = (iip, dataflowGraph) ->
    # Set IIP
    node = dataflowGraph.nodes.get(iip.to.node)
    if node
      port = node.inputs.get(iip.to.port)
      if port
        node.setState iip.to.port, iip.from.data
        if port.view
          port.view.$input.children(".input").val iip.from.data
    else
      #TODO: added IIP before node?

# Dataflow::loadGraph = (graph) ->
#   g = new noflo.Graph graph
#   DataflowNoflo.registerGraph g
#   g
