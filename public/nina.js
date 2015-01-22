var ninaApp = angular.module('nina', [
  'ngRoute',
  'ninaControllers'
]);

ninaApp.config(['$routeProvider',
  function($routeProvider) {
    $routeProvider.
      when('/home', {
        templateUrl: 'views/home.html',
        controller: 'HomeCtrl'
      }).
      when('/transfers', {
        templateUrl: 'views/transfers.html',
        controller: 'TransferCtrl'
      }).
      when('/tvshows', {
        templateUrl: 'views/tvshows.html',
        controller: 'TVShowCtrl'
      }).
      when('/rules', {
        templateUrl: 'views/rules.html',
        controller: 'RulesCtrl'
      }).
      when('/settings', {
        templateUrl: 'views/settings.html',
        controller: 'SettingsCtrl'
      }).
      otherwise({
        redirectTo: '/home'
      });
  }]);

ninaApp.directive('dropdown', ['$timeout', function ($timeout) {
  return {
    restrict: "EA",
    replace: true,
    scope: {
      ngModel: '=',
      data: '='
    },
    template: '<div class="ui compact selection dropdown"><input type="hidden" name="id"><div class="default text">Select</div><i class="dropdown icon"></i><div class="menu"><div class="item" ng-repeat="item in data" data-value="{{item.value}}">{{item.label}}</div></div></div>',
    link: function (scope, elm, attr) { 
      var changeBound = false;
      elm.dropdown({
        onShow: function() {
          if (!changeBound) {
            elm.dropdown({
              onChange: function(value) {                    
                scope.$apply(function(scope) {
                  scope.ngModel = value;
                });
              }
            })
            
            changeBound = true;
          }
        }
      });
      scope.$watch("ngModel", function(newValue, oldValue) {
        elm.dropdown('set selected', newValue);
      });
    }
  };
}]);

var ninaControllers = angular.module('ninaControllers', []);

function nina_actions() {
  return [
    { label: 'Ignore', value: 'ignore' },
    { label: 'Copy', value: 'copy' },
    { label: 'Unrar', value: 'unrar' },
  ];
}

function nina_kinds() {
  return [
    { label: 'TV Show', value: 'tvshow' },
    { label: 'Movie', value: 'movie' },
    { label: 'Porn', value: 'porn' },
  ];
}

ninaControllers.controller('HomeCtrl', ['$scope', '$http', '$compile', function ($scope, $http) {
  $('.ui.modal').modal();
  $('.menu .item').tab();
  $scope.actions = nina_actions();
  $scope.kinds = nina_kinds();

  $scope.test_run = function() {
    $http.get("/test_run").success(function(data) {
      $scope.results = data;
      $scope.show_result = true;
    });
  };
  $scope.run = function() {
    $http.get("/run").success(function(data) {
      $scope.results = data;
      $scope.show_result = true;
    });
  };
  $scope.result_class = function(r) {
    if (r.rule) {
      if (r.rule.action == "copy") {
        return "positive";
      } else if (r.rule.action == "ignore") {
        return "";
      } else if (r.rule.action == 'unrar') {
        return 'positive';
      }
    }
    return "negative";
  };
  $scope.show_rule = function(r) {
    if (r.rule && r.rule.action == 'copy') {
      return true;
    }
    return false;
  };
  $scope.edit_rule = function(r) {
    $scope.rule = angular.copy(r.rule);
    if (!$scope.rule.id) {
      $scope.rule = {pattern: "", action: "ignore", kind: "tvshow"};
    };
    $scope.example = r.file;
    $scope.test_rule();

    $('.ui.modal').modal('show');
  };
  $scope.test_rule = function() {
    $http.post("/test_rule", {rule: $scope.rule, example: $scope.example}).success(function(data) {
      $scope.dest = data.dest;
    });
  };
  $scope.done_rule = function() {
    var url;
    if ($scope.rule.id) {
      url = "/rule/" + $scope.rule.id;
    } else {
      url = "/add_rule";
    }
    $http.post(url, $scope.rule).success(function(data) {
      $('.ui.modal').modal('hide');
    });
  };
  $scope.confirm = function() {
    $http.get("/run").sucess(function(data) {
      $scope.results = data;
      $scope.show_result = false;
    });
  }
}]);

ninaControllers.controller('TransferCtrl', ['$scope', '$http', '$compile', function ($scope, $http, $compile) {
	$http.get('transfers.json').success(function(data) {
    // for dev
    $scope.transfers = data.slice(0, 1);
  });
  $http.get('tvshows.json').success(function(data) {
    $scope.tvshows = data.map(function(item) {
      return item.name;
    });
  });
  $scope.hides = {};
  $scope.toggle_hide = function(id) {
    $scope.hides[id] = !$scope.hides[id];
  };
  $scope.hide = function(id) {
    if ($scope.hides[id] == undefined) {
      $scope.hides[id] = true;
    }
    return $scope.hides[id];
  };
  $scope.test_rule = function(tid) {
    $http.post('test_rule.json', {tid:tid, pattern:$scope.pattern, kind:$scope.kind, name:$scope.selected_tvshow.title}).success(function(data) {
      $scope.test_result = data;
      $scope.go_disabled = !$scope.test_result.ok;
      $http.get('views/action-confirm.html').success(function(data) {
        var elem = document.querySelector('#result_'+tid);
        $(elem).html($compile(data)($scope));
      });
    });
  };
  $scope.show_rule = function(id) {
    $http.get('views/rule-edit.html').success(function(data) {
      var elem = document.querySelector('#trans_'+id);
      $scope.tid = id;
      $(elem).after($compile(data)($scope));
    });
  };
  $scope.action = 'Copy';
  $scope.is_action_copy = function() {
    return $scope.action == 'Copy';
  };
  $scope.change_action = function() {
    console.log("here");
    console.log($scope.action);
    if ($scope.action == "Copy") {
      $scope.is_action_copy = true;
    } else {
      $scope.is_action_copy = false;
    }
  };
  $scope.kind = 'TV Show';
  $scope.options = {
    action: ["Ignore", "Copy"],
    kind: ["TV Show", "Movie", "porn"]
  };
}]);

ninaControllers.controller('TVShowCtrl', ['$scope', '$http', function ($scope, $http) {
  $http.get('tvshows.json').success(function(data) {
    $scope.tvshows = data;
  });

  $scope.search = function() {
    $http.post('search_tvshow.json', {search_term:$scope.search_term}).success(function(data) {
      $scope.show_result = true;
      $scope.search_results = data;
    });
  };

  $scope.show_result = false;
}]);

ninaControllers.controller('RulesCtrl', ['$scope', '$http', function ($scope, $http) {
  $scope.actions = nina_actions();
  $scope.kinds = nina_kinds();
  
  $scope.up_rule = function(rule) {
  };
  $scope.down_rule = function(rule) {
    var next_rule = $scope.rules[rule.id];  // rule id is 1 based
    var next_rule_id = next_rule.id;
    var current_rule_id = rule.id;
    next_rule.id = current_rule_id;
    rule.id = next_rule_id;
    $http.post("/rule/" + rule.id, rule).success(function(data) {
      $http.post("/rule/" + next_rule.id, next_rule).success(function(data) {
        $http.get('/rules').success(function(data) {
          $scope.rules = data;
        });
      });
    });
  };
  $scope.edit_rule = function(rule) {
    $scope.rule = angular.copy(rule);

    $('.ui.modal').modal('show');
  };
  $scope.done_rule = function() {
    $http.post("/rule/" + $scope.rule.id, $scope.rule).success(function(data) {
      $('.ui.modal').modal('hide');
      if (data['id'] > 0) {
        $scope.rules[data['id'] - 1] = data;
        // $http.get('/rules').success(function(data) {
        //   $scope.rules = data;
        // });
      }
    });
  };
  $http.get('/rules').success(function(data) {
    $scope.rules = data;
  });
  $('.ui.modal').modal();
  $('.ui.selection.dropdown').dropdown();
}]);

ninaControllers.controller('SettingsCtrl', ['$scope', '$http', function ($scope, $http) {
  $http.get('settings.json').success(function(data) {
    $scope.settings = data;
  });

  $scope.save = function() {
    $http.post('settings.json', $scope.settings).
      success(function(data, status, headers, config) {
        $scope.show_error = false;
      }).
      error(function(data, status, headers, config) {
        $scope.error_msg = data;
        $scope.show_error = true;
      });
  }
}]);
