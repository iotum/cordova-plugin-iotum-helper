package com.iotum.iotumhelper;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import android.util.Log;

public class IotumHelperPlugin extends CordovaPlugin {

    private static final String TAG = "IotumHelper";

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("getFocusStatus") || action.equals("requestFocusStatusAuthorization")) {
            getFocusStatus(callbackContext);
            return true;
        }
        if (action.equals("log")) {
            String message = args.getString(0);
            if (message != null && !message.isEmpty()) {
                logMessage(message);
            }
            return true;
        }
        return false;
    }

    private void getFocusStatus(CallbackContext callbackContext) throws JSONException {
        JSONObject status = new JSONObject();
        boolean supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M;
        status.put("supported", supported);
        status.put("authorizationStatus", "unavailable");
        status.put("isFocused", JSONObject.NULL);

        if (supported) {
            NotificationManager manager = (NotificationManager) cordova.getActivity()
                .getSystemService(Context.NOTIFICATION_SERVICE);

            if (manager != null) {
                status.put("authorizationStatus", "authorized");

                switch (manager.getCurrentInterruptionFilter()) {
                    case NotificationManager.INTERRUPTION_FILTER_ALL:
                        status.put("isFocused", false);
                        break;
                    case NotificationManager.INTERRUPTION_FILTER_PRIORITY:
                    case NotificationManager.INTERRUPTION_FILTER_ALARMS:
                    case NotificationManager.INTERRUPTION_FILTER_NONE:
                        status.put("isFocused", true);
                        break;
                    default:
                        break;
                }
            }
        }

        callbackContext.success(status);
    }

    private void logMessage(String message) {
        Log.i(TAG, message);
    }
}