var ninaApp = angular.module('nina', [
  'ngRoute',
  // 'ui.bootstrap',
  // 'angucomplete-alt',
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

// ninaApp.directive('showEdit', function($compile) {
//   return {
//     scope: true,
//     link: function(scope, element, attrs) {
//       var el;
//       attrs.$observe('template', function(tpl) {
//         if (angular.isDefined(tpl)) {
//           console.log(tpl);
//           el = $compile(tpl)(scope);
//           element.html("");
//           element.append(el);
//         }
//       });
//     }
//   };
// });

var ninaControllers = angular.module('ninaControllers', []);

ninaControllers.controller('HomeCtrl', ['$scope', '$http', '$compile', function ($scope, $http) {
  $scope.test_run = function() {
    $http.get("/test_run").success(function(data) {
      $scope.results = data;
      $scope.show_result = true;
      // $scope.$apply();
      // var elem = document.querySelector('#result');
      // $(elem).html(data);
    });
  };
  $scope.add_rule = function() {
    var action = $('.ui.secondary.menu > .active').attr('data-tab');
    $http.post("/add_rule", {pattern:$scope.pattern, action:action}).success(function(data) {
      $scope.add_result = data;
      $scope.show_add_result = true;
    })
  }
  // $scope.active_class = function(str) {
  //   console.log(str);
  //   if ($scope.active == str) {
  //     return "active";
  //   } else {
  //     return "";
  //   }
  // }
  // $scope.ignore = function() {
  //   $scope.active = "ignore";
  // }
  // $scope.keep = function() {
  //   $scope.active = "keep";
  // }
  $('.menu .item').tab();
  $('.ui.selection.dropdown').dropdown();
  $scope.show_result = false;
  $scope.show_add_result = false;
  // $scope.active = "";
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

ninaControllers.controller('RulesCtrl', ['$scope', '$http', '$compile', function ($scope, $http) {
  $http.get('/rules').success(function(data) {
    $scope.rules = data;
  });
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
