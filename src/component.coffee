{Dataflow} = require '/meemoo-dataflow'

# Load the Dataflow base node type
Base = Dataflow::node 'base'

# Register our own base NoFlo component type
NofloBase = Dataflow::node 'noflo-base'

# Define the Backbone Model for NoFlo components
NofloBase.Model = Base.Model.extend
  defaults: ->
    defaults = Base.Model::defaults.call(this)
    defaults.type = 'noflo-base'
    defaults

  initialize: ->
    Base.Model::initialize.call this

  isSubgraph: -> false

  unload: ->
    # Stop any processes that need to be stopped

  toJSON: ->
    json = Base.Model::toJSON.call(this)
    json

  inputs: []
  outputs: []

# Define the Backbone View for NoFlo components
NofloBase.View = Base.View.extend()
