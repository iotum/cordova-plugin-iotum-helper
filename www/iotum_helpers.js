var exec = require('cordova/exec');

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

/**
 * Check whether Picture in Picture (PiP) is supported on the current device.
 * @param {Function} successCallback - called with a boolean
 * @param {Function} errorCallback
 */
exports.isPictureInPictureSupported = function (successCallback, errorCallback) {
	exec(successCallback, errorCallback, 'IotumHelper', 'isPictureInPictureSupported', []);
};

/**
 * Enter Picture in Picture mode.
 * @param {Object}   options
 * @param {string}   [options.mode='webrtc']         - 'webrtc' | 'webview'
 * @param {string}   [options.url]                   - URL to load (webview mode only)
 * @param {number}   [options.aspectRatioWidth=16]   - PiP window width ratio
 * @param {number}   [options.aspectRatioHeight=9]   - PiP window height ratio
 * @param {Function} successCallback
 * @param {Function} errorCallback
 */
exports.enterPictureInPicture = function (options, successCallback, errorCallback) {
	exec(successCallback, errorCallback, 'IotumHelper', 'enterPictureInPicture', [options || {}]);
};

/**
 * Exit Picture in Picture mode.
 * @param {Function} successCallback
 * @param {Function} errorCallback
 */
exports.exitPictureInPicture = function (successCallback, errorCallback) {
	exec(successCallback, errorCallback, 'IotumHelper', 'exitPictureInPicture', []);
};

/**
 * Push a video frame into the active WebRTC PiP window.
 * The frame must be a base64-encoded JPEG or PNG image.
 * Call this repeatedly (e.g. from requestAnimationFrame) to animate the PiP content.
 * @param {string}   base64ImageData - base64-encoded image (no data-URI prefix)
 * @param {Function} [successCallback]
 * @param {Function} [errorCallback]
 */
exports.setPictureInPictureFrame = function (base64ImageData, successCallback, errorCallback) {
	exec(successCallback || null, errorCallback || null, 'IotumHelper', 'setPictureInPictureFrame', [base64ImageData]);
};

var pip = {
	isActive: false,

	fireOnStart: function () {
		pip.isActive = true;
		cordova.fireWindowEvent('pipModeChanged', { active: true });
	},

	fireOnStop: function () {
		pip.isActive = false;
		cordova.fireWindowEvent('pipModeChanged', { active: false });
	},
};

exports.PictureInPicture = pip;
