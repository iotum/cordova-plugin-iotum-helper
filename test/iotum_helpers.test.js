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

test('watchTextScale streams numeric updates and unsubscribes idempotently', function () {
    const calls = [];
    const scales = [];
    const helpers = loadHelpers((success, error, service, action, args) => {
        calls.push({ success, error, service, action, args });
    });

    const unsubscribe = helpers.watchTextScale(scale => scales.push(scale), assert.fail);
    const watch = calls[0];
    assert.equal(watch.service, 'IotumHelper');
    assert.equal(watch.action, 'watchTextScale');
    assert.equal(watch.args.length, 1);
    assert.equal(typeof watch.args[0], 'string');

    watch.success(1);
    watch.success(0.9);
    watch.success(1.7);
    unsubscribe();
    unsubscribe();
    watch.success(2);
    watch.error('Late native error');

    assert.deepEqual(scales, [1, 0.9, 1.7]);
    assert.equal(calls.length, 2);
    assert.equal(calls[1].service, 'IotumHelper');
    assert.equal(calls[1].action, 'unwatchTextScale');
    assert.equal(calls[1].args[0], watch.args[0]);
});

test('a fresh or concurrent watch is independent of an earlier watch', function () {
    const watches = new Map();
    const exec = (success, error, service, action, [id]) => {
        if (action === 'watchTextScale') {
            assert.equal(watches.has(id), false);
            watches.set(id, success);
        } else {
            assert.equal(watches.delete(id), true);
        }
    };
    const original = loadHelpers(exec);
    const first = original.watchTextScale(assert.fail, assert.fail);
    const second = original.watchTextScale(assert.fail, assert.fail);
    const scales = [];
    const fresh = loadHelpers(exec).watchTextScale(scale => scales.push(scale), assert.fail);

    first();
    second();
    assert.equal(watches.size, 1);
    for (const success of watches.values()) {
        success(1.7);
    }
    assert.deepEqual(scales, [1.7]);
    fresh();
    assert.equal(watches.size, 0);
});

test('watchTextScale reports terminal errors once', function () {
    const errors = [];
    let fail;
    let emit;
    const helpers = loadHelpers((success, error, service, action) => {
        assert.equal(action, 'watchTextScale');
        fail = error;
        emit = success;
    });

    const unsubscribe = helpers.watchTextScale(assert.fail, error => errors.push(error));
    fail('Unavailable');
    fail('Another error');
    emit(1);
    unsubscribe();
    assert.deepEqual(errors, ['Unavailable']);
});

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