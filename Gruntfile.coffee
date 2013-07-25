module.exports = ->
  # Project configuration
  @initConfig
    pkg: @file.readJSON 'package.json'

    # Browser version building
    component:
      install:
        options:
          action: 'install'
    component_build:
      'dataflow-noflo':
        output: './build/'
        config: './component.json'
        scripts: true
        styles: false
        plugins: ['coffee']
        configure: (builder) ->
          # Enable Component plugins
          json = require 'component-json'
          builder.use json()
          # Copy files
          builder.copyFiles()

    # Fix broken Component aliases, as mentioned in
    # https://github.com/anthonyshort/component-coffee/issues/3
    combine:
      browser:
        input: 'build/dataflow-noflo.js'
        output: 'build/dataflow-noflo.js'
        tokens: [
          token: '.coffee'
          string: '.js'
        ]

    # JavaScript minification for the browser
    uglify:
      options:
        report: 'min'
      noflo:
        files:
          './build/dataflow-noflo.min.js': ['./build/dataflow-noflo.js']

    # Simple host
    connect:
      options:
        port: 8000,
        hostname: '*' # available from ipaddress:8000 on same network (or name.local:8000)
      uses_defaults: {}
    
    # Automated recompilation and testing when developing
    watch:
      files: ['src/*.coffee']
      tasks: ['build']

    # Release automation
    bumpup: ['package.json', 'component.json']
    
    tagrelease:
      file: 'package.json'
      prefix: ''
      
    exec:
      npm_publish:
        cmd: 'npm publish'

  # Grunt plugins used for building
  @loadNpmTasks 'grunt-component'
  @loadNpmTasks 'grunt-component-build'
  @loadNpmTasks 'grunt-combine'
  @loadNpmTasks 'grunt-contrib-uglify'
  # @loadNpmTasks 'grunt-contrib-copy'

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-contrib-connect'
  @loadNpmTasks 'grunt-contrib-watch'
  @loadNpmTasks 'grunt-coffeelint'

  # Grunt plugins used for release automation
  # @loadNpmTasks 'grunt-bumpup'
  # @loadNpmTasks 'grunt-tagrelease'
  # @loadNpmTasks 'grunt-exec'

  @registerTask 'dev', ['connect', 'watch']
  @registerTask 'build', ['component', 'component_build', 'combine', 'uglify']
  @registerTask 'default', ['test']
