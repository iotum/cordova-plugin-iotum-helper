const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadHelpers(exec) {
    const context = {
        exports: {},
        require: function (name) {
            assert.equal(name, 'cordova/exec');
            return exec;
        }
    };
    const source = fs.readFileSync(path.join(__dirname, '../www/iotum_helpers.js'), 'utf8');
    vm.runInNewContext(source, context);
    return context.exports;
}

for (const action of ['getFocusStatus', 'requestFocusStatusAuthorization']) {
    test(action + ' forwards callbacks and invokes the matching native action', function () {
        const success = function () {};
        const error = function () {};
        let calls = 0;
        const helpers = loadHelpers(function (onSuccess, onError, service, nativeAction, args) {
            calls += 1;
            assert.equal(onSuccess, success);
            assert.equal(onError, error);
            assert.equal(service, 'IotumHelper');
            assert.equal(nativeAction, action);
            assert.equal(Array.isArray(args), true);
            assert.equal(args.length, 0);
        });

        helpers[action](success, error);
        assert.equal(calls, 1);
    });

    for (const isFocused of [true, false, null]) {
        test(action + ' passes through isFocused=' + isFocused, function () {
            const status = { supported: true, authorizationStatus: 'authorized', isFocused };
            const helpers = loadHelpers(function (success) {
                success(status);
            });

            helpers[action](function (result) {
                assert.equal(result, status);
                assert.equal(result.isFocused, isFocused);
            });
        });
    }

    test(action + ' forwards native errors', function () {
        const failure = 'Invalid action';
        const helpers = loadHelpers(function (success, error) {
            error(failure);
        });

        helpers[action](assert.fail, function (result) {
            assert.equal(result, failure);
        });
    });

    for (const status of [
        { supported: false, authorizationStatus: 'unavailable', isFocused: null },
        { supported: true, authorizationStatus: 'unavailable', isFocused: null }
    ]) {
        test(action + ' preserves unavailable status with supported=' + status.supported, function () {
            const helpers = loadHelpers(function (success) {
                success(status);
            });

            helpers[action](function (result) {
                assert.equal(result, status);
                assert.equal(result.supported, status.supported);
                assert.equal(result.authorizationStatus, 'unavailable');
                assert.equal(result.isFocused, null);
            }, assert.fail);
        });
    }
}