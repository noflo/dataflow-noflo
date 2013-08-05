{Dataflow} = require '/meemoo-dataflow'

NofloBase = Dataflow::node 'noflo-base'
Subgraph = Dataflow::node 'dataflow-subgraph'

# Register our Subgraph node
NofloSubgraph = Dataflow::node 'noflo-subgraph'

NofloSubgraph.Model = Subgraph.Model.extend
  defaults: ->
    defaults = Subgraph.Model::defaults.call(this)
    defaults.type = "noflo-subgraph"
    graph = {}
    defaults

  initialize: ->
    Subgraph.Model::initialize.call this

  isSubgraph: -> true

  unload: ->
    # Stop any processes that need to be stopped

  toJSON: ->
    json = Subgraph.Model::toJSON.call(this)
    json

  inputs: []
  outputs: []

NofloSubgraph.View = Subgraph.View.extend
  initialize: (options) ->
    Subgraph.View::initialize.call this, options

