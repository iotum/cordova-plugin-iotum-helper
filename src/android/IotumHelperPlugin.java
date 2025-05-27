package com.iotum.iotumhelper;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import android.util.Log;

public class IotumHelper extends CordovaPlugin {

    private static final String TAG = "IotumHelper";

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("log")) {
            String message = args.getString(0);
            if (message != null && !message.isEmpty()) {
                logMessage(message);
            }
            return true;
        }
        return false;
    }

    private void logMessage(String message) {
        Log.i(TAG, message);
    }
}