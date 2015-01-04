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
      when('/settings', {
        templateUrl: 'views/settings.html',
        controller: 'SettingsCtrl'
      }).
      otherwise({
        redirectTo: '/home'
      });
  }]);

var ninaControllers = angular.module('ninaControllers', []);

ninaControllers.controller('HomeCtrl', ['$scope', '$http', function ($scope, $http) {
}]);

ninaControllers.controller('TransferCtrl', ['$scope', '$http', function ($scope, $http) {
	$http.get('transfers.json').success(function(data) {
    $scope.transfers = data;
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
}]);

ninaControllers.controller('TVShowCtrl', ['$scope', '$http', function ($scope, $http) {
  $http.get('tvshows.json').success(function(data) {
    $scope.tvshows = data;
  });

  $scope.search = function() {
    $http.post('search_tvshow.json', {search_term:$scope.search_term});
  }
}]);

ninaControllers.controller('SettingsCtrl', ['$scope', '$http', function ($scope, $http) {
  $http.get('settings.json').success(function(data) {
    $scope.settings = data;
  });

  $scope.save = function() {
    $http.post('settings.json', {tvshow_folder:$scope.tvshow_folder}).
      success(function(data, status, headers, config) {
        $scope.show_error = false;
      }).
      error(function(data, status, headers, config) {
        $scope.error_msg = data;
        $scope.show_error = true;
      });
  }
}]);