package com.iotum.iotumhelper;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import android.util.Rational;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class IotumHelper extends CordovaPlugin {

    private static final String TAG = "IotumHelper";

    private boolean pipActive = false;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("log")) {
            String message = args.getString(0);
            if (message != null && !message.isEmpty()) {
                logMessage(message);
            }
            return true;
        }

        if (action.equals("isPictureInPictureSupported")) {
            return isPictureInPictureSupported(callbackContext);
        }

        if (action.equals("enterPictureInPicture")) {
            JSONObject options = args.length() > 0 ? args.getJSONObject(0) : new JSONObject();
            return enterPictureInPicture(options, callbackContext);
        }

        if (action.equals("exitPictureInPicture")) {
            return exitPictureInPicture(callbackContext);
        }

        if (action.equals("setPictureInPictureFrame")) {
            // Frame pushing is iOS-only; on Android this is a no-op.
            callbackContext.success();
            return true;
        }

        return false;
    }

    // -------------------------------------------------------------------------
    // Picture in Picture
    // -------------------------------------------------------------------------

    /**
     * Returns true when the device supports PiP (Android 7.0+ with the feature present).
     */
    private boolean isPictureInPictureSupported(CallbackContext callbackContext) {
        boolean supported = false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            PackageManager pm = cordova.getActivity().getPackageManager();
            supported = pm.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE);
        }
        callbackContext.success(supported ? 1 : 0);
        return true;
    }

    /**
     * Enter Picture in Picture mode.
     *
     * options:
     *   aspectRatioWidth  – integer, default 16
     *   aspectRatioHeight – integer, default 9
     *
     * The "mode" and "url" options are accepted for API compatibility with iOS but
     * have no effect on Android – the whole activity is shown in the PiP window.
     */
    private boolean enterPictureInPicture(JSONObject options, CallbackContext callbackContext) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            callbackContext.error("Picture in Picture is not supported on this Android version");
            return true;
        }

        final int ratioWidth  = options.optInt("aspectRatioWidth",  16);
        final int ratioHeight = options.optInt("aspectRatioHeight", 9);

        cordova.getActivity().runOnUiThread(() -> {
            try {
                Activity activity = cordova.getActivity();

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    PictureInPictureParams params = new PictureInPictureParams.Builder()
                            .setAspectRatio(new Rational(ratioWidth, ratioHeight))
                            .build();
                    activity.enterPictureInPictureMode(params);
                } else {
                    // Android 7.0 – 7.1 (API 24–25): no params support
                    activity.enterPictureInPictureMode();
                }

                pipActive = true;
                // Fire start event immediately – the activity is now entering PiP
                fireJsEvent("cordova.plugins.iotumHelper.PictureInPicture.fireOnStart();");
                callbackContext.success();
            } catch (Exception e) {
                Log.e(TAG, "enterPictureInPicture failed: " + e.getMessage());
                callbackContext.error(e.getMessage());
            }
        });

        return true;
    }

    /**
     * Exit Picture in Picture mode by relaunching the activity, which causes the
     * system to expand the PiP window back to full screen.
     */
    private boolean exitPictureInPicture(CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(() -> {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
                        && cordova.getActivity().isInPictureInPictureMode()) {
                    // Relaunching the activity brings it back to full-screen from PiP.
                    Activity activity = cordova.getActivity();
                    Intent intent = new Intent(activity, activity.getClass());
                    intent.setFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                    activity.startActivity(intent);
                }
                pipActive = false;
                callbackContext.success();
            } catch (Exception e) {
                Log.e(TAG, "exitPictureInPicture failed: " + e.getMessage());
                callbackContext.error(e.getMessage());
            }
        });
        return true;
    }

    // -------------------------------------------------------------------------
    // Lifecycle – detect when the user exits PiP (e.g. expands the window)
    // -------------------------------------------------------------------------

    @Override
    public void onResume(boolean multitasking) {
        super.onResume(multitasking);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            boolean inPip = cordova.getActivity().isInPictureInPictureMode();

            if (pipActive && !inPip) {
                // Activity resumed from PiP mode – notify JS
                pipActive = false;
                fireJsEvent("cordova.plugins.iotumHelper.PictureInPicture.fireOnStop();");
            }
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private void logMessage(String message) {
        Log.i(TAG, message);
    }

    private void fireJsEvent(String js) {
        webView.loadUrl("javascript:" + js);
    }
}