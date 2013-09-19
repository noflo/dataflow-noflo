{Dataflow} = require '/meemoo-dataflow'
noflo = require 'noflo'

# Base NoFlo component registrations to Dataflow
require './component'
require './subgraph'

# Load the Dataflow base node type
Base = Dataflow::node 'base'
Graph = Dataflow::module 'graph'

# Load the NoFlo types
NofloBase = Dataflow::node 'noflo-base'
NofloSubgraph = Dataflow::node 'noflo-subgraph'

# Make plugin
DataflowNoflo = Dataflow::plugin("noflo")
DataflowNoflo.initialize = (dataflow) ->
  # Plugin: source
  dataflow.plugins.source.listeners false

  # Plugin: log
  dataflow.plugins.log.listeners false

  # Overwrite loadGraph to sync with NoFlo
  # dataflow.loadGraph = (graph) ->
  #   g = new noflo.Graph graph
  #   DataflowNoflo.registerGraph g, dataflow
  #   g


DataflowNoflo.aliases = {}

DataflowNoflo.registerGraph = (graph, dataflow, callback, main = true) ->
  # Prepare empty Dataflow graph
  if main
    dataflowGraph = dataflow.loadGraph {}
  else
    dataflowGraph = new Graph.Model
      dataflow: dataflow

  # Provide a reference to the NoFlo graph
  dataflowGraph.nofloGraph = graph

  # Provide a backreference to the Dataflow graph
  graph.dataflowGraph = dataflowGraph

  # Load components and prepare the Dataflow graph
  DataflowNoflo.loadComponents graph.baseDir, ->
    # We don't want to use base components directly
    dataflow.plugins.library.update
      exclude: [
        "base"
        "base-resizable"
        "dataflow-subgraph"
        "noflo-base"
        "noflo-subgraph"
      ]

    DataflowNoflo.loadGraph graph, dataflow, ->
      callback dataflowGraph if callback

DataflowNoflo.registerAlias = (name) ->
  parts = name.split '/'
  if parts.length is 2 and !DataflowNoflo.aliases[parts[1]]
    DataflowNoflo.aliases[parts[1]] = name

DataflowNoflo.loadComponents = (baseDir, ready) ->
  cl = new noflo.ComponentLoader()
  cl.baseDir = baseDir
  cl.listComponents (types) ->
    readyAfter = _.after Object.keys(types).length, ready
    for name of types
      DataflowNoflo.registerAlias name
      cl.load name, (component) ->
        DataflowNoflo.registerComponent name, component
        do readyAfter

DataflowNoflo.loadGraph = (graph, dataflow, callback) ->
  # When df graph changes update source plugin with NoFlo graph
  graph.dataflowGraph.on "change", (dfGraph) ->
    dataflow.plugins.source.show JSON.stringify graph.toJSON(), null, 2
  
  # -    
  # Noflo to Dataflow
  # -
  graph.on "addNode", (node) ->
    DataflowNoflo.addNode node, graph.dataflowGraph, dataflow
    dataflow.plugins.log.add "node added: " + node.id
  graph.on "addEdge", (edge) ->
    DataflowNoflo.addEdge edge, graph.dataflowGraph, dataflow
    dataflow.plugins.log.add "edge added."
  graph.on "addInitial", (iip) ->
    DataflowNoflo.addInitial iip, graph.dataflowGraph, dataflow
    dataflow.plugins.log.add "IIP added: " + JSON.stringify(iip)
  graph.on "removeNode", (node) ->
    if node.dataflowNode?
      node.dataflowNode.remove()
    dataflow.plugins.log.add "node removed: " + node.id
  graph.on "removeEdge", (edge) ->
    if edge.from.node? and edge.to.node?
      if edge.dataflowEdge?
        edge.dataflowEdge.remove()
    dataflow.plugins.log.add "edge removed."

  # -    
  # Dataflow to Noflo
  # -
  dataflow.on "node:add", (dfGraph, node) ->
    return unless dfGraph is graph.dataflowGraph
    unless node.nofloNode?
      # Convert ID to string
      node.nofloNode = graph.addNode node.id.toString(), node.type,
        x: node.get "x"
        y: node.get "y"
    # Sync rename
    node.on "change:label", (node, newName) ->
      oldName = node.nofloNode.id
      graph.renameNode oldName, newName
    # Sync position
    node.on "change:x change:y", ->
      node.nofloNode.metadata.x = node.get 'x'
      node.nofloNode.metadata.y = node.get 'y'
    # Add IIPs from state
    if node.attributes.state
        console.log node.get "state"
        for port in node.get "state"
          console.log port
    # Sync state
    node.on "change:state", (port, value) ->
      metadata = {}
      for iip in graph.initializers
        continue unless iip
        if iip.to.node is node.nofloNode.id and iip.to.port is port
          return if iip.from.data is value
          metadata = iip.metadata
          graph.removeInitial node.nofloNode.id, port
      graph.addInitial value, node.nofloNode.id, port, metadata
    node.on "bang", (port) ->
      metadata = {}
      for iip in graph.initializers
        continue unless iip
        if iip.to.node is node.nofloNode.id and iip.to.port is port
          metadata = iip.metadata
          graph.removeInitial node.nofloNode.id, port
      graph.addInitial true, node.nofloNode.id, port, metadata

  dataflow.on "edge:add", (dfGraph, edge) ->
    return unless dfGraph is graph.dataflowGraph
    unless edge.nofloEdge?
      try
        edge.nofloEdge = graph.addEdge edge.source.parentNode.nofloNode.id, edge.source.id, edge.target.parentNode.nofloNode.id, edge.target.id,
          route: edge.get 'route'
      catch error
        # Not added, probably multiple w/o array port https://github.com/noflo/noflo/issues/90

    edge.on 'change:route', ->
      edge.nofloEdge.metadata.route = edge.get 'route'

  dataflow.on "node:remove", (dfGraph, node) ->
    return unless dfGraph is graph.dataflowGraph
    if node.nofloNode?
      graph.removeNode node.nofloNode.id

  dataflow.on "edge:remove", (dfGraph, edge) ->
    return unless dfGraph is graph.dataflowGraph
    if edge.nofloEdge?
      edge = edge.nofloEdge
      graph.removeEdge edge.from.node, edge.from.port, edge.to.node, edge.to.port

  nodesReady = _.after graph.nodes.length, ->
    # Add edges and IIPs
    for edge in graph.edges
      DataflowNoflo.addEdge edge, graph.dataflowGraph, dataflow
    for iip in graph.initializers
      DataflowNoflo.addInitial iip, graph.dataflowGraph, dataflow
    callback graph.dataflowGraph if callback

  # Start by adding nodes. These can be async as subgraphs may have to
  # be registered
  _.each graph.nodes, (node) ->
    DataflowNoflo.addNode node, graph.dataflowGraph, dataflow, nodesReady


DataflowNoflo.getComponent = (name, dataflow) ->
  type = dataflow.node name
  unless type.Model
    if DataflowNoflo.aliases[node.component]
      type = dataflow.node(DataflowNoflo.aliases[node.component])
    else
      throw new Error "Component #{node.component} not available"
  type

DataflowNoflo.addNode = (node, dataflowGraph, dataflow, ready) ->
  unless node
    ready null if ready
    return
  unless node.dataflowNode?
    # Load the component node
    type = DataflowNoflo.getComponent node.component, dataflow
    dfNode = new type.Model
      id: node.id
      label: node.id
      x: ( if node.metadata.x? then node.metadata.x else 300 )
      y: ( if node.metadata.y? then node.metadata.y else 300 )
      parentGraph: dataflowGraph
    # Reference each other
    dfNode.nofloNode = node
    node.dataflowNode = dfNode

    # Load subgraphs
    if dfNode.isSubgraph()
      subgraph = dfNode.nofloComponent.network.graph
      DataflowNoflo.registerGraph subgraph, dataflow, (dfGraph) ->
        dfNode.graph = dfGraph
        dataflowGraph.nodes.add dfNode
        ready node.dataflowNode if ready
      , false
      return

    # Add to graph
    dataflowGraph.nodes.add dfNode

  ready node.dataflowNode if ready

DataflowNoflo.addEdge = (edge, dataflowGraph, dataflow) ->
  return unless edge
  # Add edge
  unless edge.dataflowEdge?
    Edge = dataflow.module 'edge'
    unless edge.metadata
      edge.metadata = {}
    dfEdge = new Edge.Model
      id: edge.from.node + ":" + edge.from.port + "::" + edge.to.node + ":" + edge.to.port
      parentGraph: dataflowGraph
      source:
        node: edge.from.node
        port: edge.from.port
      target:
        node: edge.to.node
        port: edge.to.port
      route: (if edge.metadata.route? then edge.metadata.route else 0)

    # Reference each other
    dfEdge.nofloEdge = edge
    edge.dataflowEdge = dfEdge

    # Add to graph
    dataflowGraph.edges.add dfEdge

DataflowNoflo.addInitial = (iip, dataflowGraph) ->
  # Set IIP
  node = dataflowGraph.nodes.get(iip.to.node)
  if node
    port = node.inputs.get(iip.to.port)
    if port
      node.setState iip.to.port, iip.from.data

DataflowNoflo.registerComponent = (name, component, ready) ->
  toPortDefinition = (port, name) -> id: name, type: port.type

  base = NofloBase
  if component.isSubgraph()
    base = NofloSubgraph
    
  newType = Dataflow::node name
  newType.Model = base.Model.extend
    defaults: -> _.extend {}, Base.Model::defaults.call(this),
      type: name
      graph: {}
    inputs: _.map component.inPorts, toPortDefinition
    outputs: _.map component.outPorts, toPortDefinition
    nofloComponent: component
  newType.View = base.View.extend()
  do ready if ready
