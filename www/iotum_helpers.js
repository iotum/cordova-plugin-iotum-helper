var exec = require('cordova/exec');

exports.setAppBackgroundColor = function (argb) {
	cordova.exec(null, null, 'IotumHelperPlugin', 'setAppBackgroundColor', [argb]);
};
