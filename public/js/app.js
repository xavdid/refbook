var app = angular
    .module('Refbook', [])
    
    .controller('JSController', ['$scope', function($scope){
        $scope.j = "david";
    }]);