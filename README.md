# cordova-plugin-iotum-helper

## iOS Dynamic Type text scale

On iOS, call `cordova.plugins.iotumHelper.watchTextScale(onScale, onError)` after
Cordova's `deviceready` event. `onScale` receives a finite, positive number:
UIKit's preferred Body font point size for the web view's current content size
category divided by the preferred Body point size for the default Large
category. Large is `1`; smaller categories can report less than `1`, and larger
categories report more than `1`.

Each subscription receives an initial value, then receives updates only when
the ratio changes. The plugin checks on Dynamic Type changes and when the app
becomes active again. `onError`, if supplied, receives a terminal error.

```javascript
// After deviceready, when mounting the web consumer:
const unsubscribe = cordova.plugins.iotumHelper.watchTextScale(applyTextScale, console.error);

// When unmounting the web consumer:
unsubscribe();
```

The returned unsubscribe function is idempotent and only stops that
subscription. Cordova also clears subscriptions when the web view resets
(for example, on navigation or reload) or the plugin is disposed. Start a
fresh subscription when the consumer mounts again, and after `deviceready`
in a newly loaded document. There is no need to resubscribe on `resume`.
Do not call this API on Android or in a regular browser.

## iOS Focus Status

On iOS 15 and later, read the shared Focus status (including Do Not Disturb)
through Apple's public `INFocusStatusCenter` API. iOS does not reveal which Focus
is active and does not provide a separate Do Not Disturb flag.

Request permission from a user-initiated action before reading the status:

```javascript
cordova.plugins.iotumHelper.requestFocusStatusAuthorization(function (status) {
	console.log(status.authorizationStatus);
}, console.error);
```

Read the current status without prompting:

```javascript
cordova.plugins.iotumHelper.getFocusStatus(function (status) {
	if (status.isFocused === true) {
		console.log('Notifications are silenced by Focus.');
	} else if (status.isFocused === false) {
		console.log('Shared Focus status reports notifications are not silenced.');
	} else {
		console.log('Focus status is unknown or unavailable.');
	}
}, console.error);
```

Both functions take success and error callbacks and return this object through
the success callback:

| Property | Values |
| --- | --- |
| `supported` | `true` on iOS 15+, otherwise `false` |
| `authorizationStatus` | `notDetermined`, `restricted`, `denied`, `authorized`, or `unavailable` |
| `isFocused` | `true`, `false`, or `null` when unavailable or not authorized |

This is the status the user chooses to share, not an unrestricted device-wide
Focus detector. The user must allow access and enable Share Focus Status for the
active Focus. Do not interpret `null` as Focus being off, or a shared `false` as
proof that no Focus is active. Status is a snapshot; call again when needed or
when the app resumes.

The plugin weak-links `Intents.framework`, adds `NSFocusStatusUsageDescription`
and `NSUserActivityTypes` (`INStartCallIntent`) to the app's Info.plist, and adds
the Communication Notifications entitlement
(`com.apple.developer.usernotifications.communication`), which iOS requires for
reading Focus status. App Store validation rejects apps with this entitlement
unless `NSUserActivityTypes` lists `INStartCallIntent` or `INSendMessageIntent`
(ITMS-90894). Enable the Communication
Notifications capability for the host app's App ID and ensure its provisioning
profile supports the entitlement. Build with an iOS 15+ SDK. Reinstall/update the
plugin in the host Cordova app to apply the native configuration changes. On iOS
versions before 15, both functions return `supported: false` and `isFocused: null`
without requesting permission.

## Android Do Not Disturb

The same `getFocusStatus(success, error)` and
`requestFocusStatusAuthorization(success, error)` JavaScript functions work on
Android 6.0 (API 23) and later, with the same result properties. Android reads the
global DND interruption filter using `NotificationManager.getCurrentInterruptionFilter()`.

| Interruption filter | `isFocused` |
| --- | --- |
| Normal (`INTERRUPTION_FILTER_ALL`) | `false` |
| Priority only (`INTERRUPTION_FILTER_PRIORITY`) | `true` |
| Alarms only (`INTERRUPTION_FILTER_ALARMS`) | `true` |
| Total silence (`INTERRUPTION_FILTER_NONE`) | `true` |
| Unknown or unrecognized filter | `null` |

Reading this filter requires no permission, including no notification-policy
access or notification-posting permission. `requestFocusStatusAuthorization`
therefore returns the current status without opening settings or showing a
prompt. `authorizationStatus` is `authorized` when the notification service is
available, even if the filter is unknown. This does not grant permission to
change DND settings; the plugin only reads them.

Before API 23, both functions return `supported: false`,
`authorizationStatus: 'unavailable'`, and `isFocused: null`. If the notification
service is unavailable on a supported version, `supported` remains `true`,
`authorizationStatus` is `unavailable`, and `isFocused` is `null`.

An active DND mode may still allow calls or notifications through exceptions.
This does not detect silent/vibrate mode, per-app notification blocking, or
Digital Wellbeing's app-pausing Focus mode. Results are snapshots; read again
when needed or when the app resumes. Reinstall/update the plugin in the host
Cordova app and rebuild to apply the Android native and registration changes.

## Tests

Run the JavaScript bridge tests with `node --test test/iotum_helpers.test.js`.
For native Dynamic Type verification, start at Large (`1`), then change to a
smaller category and an accessibility category, both while the web view is
running and while the app is backgrounded. Check that resuming without changing
size does not emit again, and that stopping or reloading stops the old watch.
After reload, a fresh watch should report the current scale immediately.

Native Focus behavior must be verified on an iOS device with Focus off/on (including Do
Not Disturb), Share Focus Status off/on, and permission granted/denied. On Android,
verify DND off, priority only, alarms only, and total silence where available,
including without notification-policy access. Also verify reading again after
toggling DND while the app is in the background.