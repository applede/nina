module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    watch: {
      public_files: {
        files: ['public/*.css', 'public/*.js'],
        options: {
          livereload: true,
        },
      },
      slim: {
        files: 'views/*.slim',
        tasks: ['slim'],
        options: {
          livereload: true,
        }
      },
    },
    slim: {
      dist: {
        files: [{
          expand: true,
          cwd: 'views',
          src: ['*.slim'],
          dest: 'public/views',
          ext: '.html'
        }],
        options: {
          pretty: true,
          option: "attr_list_delims={'('=>')'}"
        },
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-slim');

  // Default task(s).
  grunt.registerTask('default', ['watch', 'slim']);

};
