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
}]);

ninaControllers.controller('TVShowCtrl', ['$scope', '$http', function ($scope, $http) {
  $http.get('tvshows.json').success(function(data) {
    $scope.tvshows = data;
  });

  $scope.search = function() {
    console.log($scope.search_term);
    $http.post('search_tvshow.json', {search_term:$scope.search_term}).
      success(function(data, status, headers, config) {
      });
  }
}]);