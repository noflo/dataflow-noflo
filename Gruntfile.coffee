module.exports = ->
  # Project configuration
  @initConfig
    pkg: @file.readJSON 'package.json'

    # CoffeeScript compilation
    coffee:
      src:
        expand: true
        cwd: 'src'
        src: ['**.coffee']
        dest: 'build'
        ext: '.js'
    
    # Simple host
    connect:
      options:
        port: 8000,
        hostname: '*' # available from ipaddress:8000 on same network (or name.local:8000)
      uses_defaults: {}
    
    # Automated recompilation and testing when developing
    watch:
      files: ['src/*.coffee']
      tasks: ['coffee']

    # Release automation
    bumpup: ['package.json', 'component.json']
    
    tagrelease:
      file: 'package.json'
      prefix: ''
      
    exec:
      npm_publish:
        cmd: 'npm publish'

  # Grunt plugins used for building
  @loadNpmTasks 'grunt-contrib-coffee'
  # @loadNpmTasks 'grunt-component'
  # @loadNpmTasks 'grunt-component-build'
  # @loadNpmTasks 'grunt-combine'
  # @loadNpmTasks 'grunt-contrib-uglify'
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
  @registerTask 'default', ['test']
