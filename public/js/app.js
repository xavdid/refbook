var app = angular
    .module('Refbook', [])
    .controller('PaypalController', function($scope, $http){
        $scope.currencies = [
            {
                label: "AUD",
                code: "K5UBECVDPZEGN",
                quan: "$21"
            },
            {
                label: "CAD",
                code: "S4D7VGQ33DLXG",
                quan: "$22"
            },
            {
                label: "EUR",
                code: "LXQLYPBHFSFNQ",
                quan: "€16"
            },
            {
                label: "GBP",
                code: "RZ8NXMVPA5TYW",
                quan: "£12"
            },
            {
                label: "USD",
                code: "WRVHF3X2SS2FS",
                quan: "$20"
            }
        ];

        $http.get("/currency")
            .then(function(resp){
                $scope.i = resp.data.i;
                $scope.currency = $scope.currencies[$scope.i];
            });
    });