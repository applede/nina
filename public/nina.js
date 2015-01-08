var ninaApp = angular.module('nina', [
  'ngRoute',
  'angucomplete-alt',
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

ninaApp.directive('showEdit', ['$http', '$compile', function($http, $compile) {
  function link(scope, element, attrs) {
    scope.$watch(attrs.show, function(value) {
      if (value) {
        $http.get('views/rule-edit.html').then(function(data) {
          el = $compile(data)(scope);
          element.html("");
          element.append(el);
        })
      }
    });
  }

  return {
    link: link
  };
}]);

ninaApp.directive('tvshowName', ['$http', '$q', function($http, $q) {
  return {
    require: 'ngModel',
    link: function(scope, elm, attrs, ctrl) {
      var usernames = ['Jim', 'John', 'Jill', 'Jackie'];

      ctrl.$asyncValidators.tvshow_name = function(modelValue, viewValue) {
        if (ctrl.$isEmpty(modelValue)) {
          // consider empty model valid
          return $q.when();
        }

        var def = $q.defer();

        $http.get('').success(function(data) {
          console.log(data);
          // Mock a delayed response
          if (usernames.indexOf(modelValue) === -1) {
            // The username is available
            def.resolve();
          } else {
            def.reject();
          }

        });

        return def.promise;
      };
    }
  };
}]);

var ninaControllers = angular.module('ninaControllers', []);

ninaControllers.controller('HomeCtrl', ['$scope', '$http', function ($scope, $http) {
}]);

ninaControllers.controller('TransferCtrl', ['$scope', '$http', '$compile', function ($scope, $http, $compile) {
	$http.get('transfers.json').success(function(data) {
    $scope.transfers = data;
  });
  $http.get('tvshows.json').success(function(data) {
    $scope.tvshows = data;
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
  $scope.test = function() {
    $http.post('test_rule.json', {pattern:$scope.pattern, kind:$scope.kind, name:$scope.name}).success(function(data) {
      $scope.test_result = data;
    })
  };
  $scope.show_rule = function(id) {
    $http.get('views/rule-edit.html').success(function(data) {
      var elem = document.querySelector('#trans_'+id);
      $(elem).after($compile(data)($scope));
    });
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
