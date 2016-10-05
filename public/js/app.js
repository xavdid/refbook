var app = angular
    .module('Refbook', [])
    .controller('PaypalController', function($scope, $http){
        $scope.currencies = [
            {
                label: "AUD",
                code: "AS9ML7EUA3L8E",
                quan: "$23"
            },
            {
                label: "CAD",
                code: "UJE6ZNE497XSQ",
                quan: "$23"
            },
            {
                label: "EUR",
                code: "J2DZLFHGF6GYG",
                quan: "€15"
            },
            {
                label: "GBP",
                code: "WK532LMGBZLTE",
                quan: "£10"
            },
            {
                label: "USD",
                code: "4AFVSRFMP4WDC",
                quan: "$16"
            }
        ];

        $http.get("/currency")
            .then(function(resp){
                $scope.i = resp.data.i;
                $scope.currency = $scope.currencies[$scope.i];
            });
    });
