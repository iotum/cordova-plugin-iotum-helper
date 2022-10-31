var exec = require('cordova/exec');

exports.setAppBackgroundColor = function (argb) {
	cordova.exec(null, null, 'IotumHelper', 'setAppBackgroundColor', [argb]);
};

exports.hideKeyboardAccessoryBar = function (hide) {
	cordova.exec(null, null, 'IotumHelper', 'hideKeyboardAccessoryBar', [hide]);
};

var keyboard = Object.freeze({
	fireOnShow: function (height) {
		keyboard.isVisible = true;
		cordova.fireWindowEvent('keyboardDidShow', { height });
	},

	fireOnHide: function () {
		keyboard.isVisible = false;
		cordova.fireWindowEvent('keyboardDidHide');
	},

	isVisible: false,
});

exports.Keyboard = keyboard;
