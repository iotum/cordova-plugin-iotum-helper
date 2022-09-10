var exec = require('cordova/exec');

exports.setAppBackgroundColor = function (argb) {
	cordova.exec(null, null, 'IotumHelper', 'setAppBackgroundColor', [argb]);
};
