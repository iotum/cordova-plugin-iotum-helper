var exec = require('cordova/exec');

// Namespace the IDs to this document so a stale stop cannot cancel a new page's watch.
var textScaleWatchPrefix = Math.random().toString(36).slice(2) + ':';
var nextTextScaleWatchId = 0;

exports.watchTextScale = function (onScale, onError) {
	var id = textScaleWatchPrefix + nextTextScaleWatchId++;
	var stopped = false;

	exec(function (scale) {
		if (!stopped && typeof onScale === 'function') {
			onScale(scale);
		}
	}, function (error) {
		if (!stopped) {
			stopped = true;
			if (typeof onError === 'function') {
				onError(error);
			}
		}
	}, 'IotumHelper', 'watchTextScale', [id]);

	return function unsubscribe() {
		if (!stopped) {
			stopped = true;
			exec(null, null, 'IotumHelper', 'unwatchTextScale', [id]);
		}
	};
};

exports.getFocusStatus = function (success, error) {
	exec(success, error, 'IotumHelper', 'getFocusStatus', []);
};

exports.requestFocusStatusAuthorization = function (success, error) {
	exec(success, error, 'IotumHelper', 'requestFocusStatusAuthorization', []);
};

exports.setAppBackgroundColor = function (argb) {
	exec(null, null, 'IotumHelper', 'setAppBackgroundColor', [argb]);
};

exports.hideKeyboardAccessoryBar = function (hide) {
	exec(null, null, 'IotumHelper', 'hideKeyboardAccessoryBar', [hide]);
};

exports.log = function (message) {
	exec(null, null, "IotumHelper", "log", [message]);
}

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
