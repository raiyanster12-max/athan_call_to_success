package com.salamay.googlecast;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;
import android.view.ContextThemeWrapper;
import android.os.Handler;
import android.os.Looper;

import androidx.mediarouter.app.MediaRouteChooserDialog;
import androidx.mediarouter.media.MediaRouter;
import androidx.annotation.NonNull;
import com.salamay.googlecast.ChromeCastViewFactory;
import com.salamay.googlecast.Model.AudioData;
import com.google.android.gms.cast.framework.CastButtonFactory;
import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.cast.framework.CastSession;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

/** GooglecastPlugin */
public class GooglecastPlugin implements FlutterPlugin, MethodCallHandler,ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private Activity activity;
  private String TAG="GooglecastPlugin";
  private ChromeCastSession chromeCastSession;
  private ChromeCastSreamHandler chromeCastSreamHandler;
  private static final String chromecastconnectionstate="com.salamay.googlecast/connectionstate";
  private static final String chromecastmediamessage="com.salamay.googlecast/messagestream";
  private EventChannel connectionstatechanenel;
  private EventChannel messagestatechannel;
  private BroadcastReceiver br;
  private Context applicationContext;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    applicationContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "googlecast");
    channel.setMethodCallHandler(this);
    flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("ChromeCastButton",new ChromeCastViewFactory());
    connectionstatechanenel=new EventChannel(flutterPluginBinding.getBinaryMessenger(),chromecastconnectionstate);
    messagestatechannel=new EventChannel(flutterPluginBinding.getBinaryMessenger(), chromecastmediamessage);
    
    // Initialize for background execution where activity is null
    if (chromeCastSession == null) {
      try {
        chromeCastSession = new ChromeCastSession(applicationContext);
      } catch (Exception e) {
        Log.e(TAG, "Failed to initialize ChromeCastSession in background", e);
      }
    }
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if(call.method.equals("isConnected")) {
      if (chromeCastSession != null && chromeCastSession.isConnected()) {
        result.success(true);
      } else {
        // Fallback: check CastContext directly (handles background isolate where
        // chromeCastSession may be null due to main-thread init constraint).
        try {
          CastSession s = CastContext.getSharedInstance(applicationContext)
              .getSessionManager().getCurrentCastSession();
          result.success(s != null && s.isConnected());
        } catch (Exception e) {
          result.success(false);
        }
      }
    } else if(call.method.equals("debugState")) {
      HashMap<String, Object> data = new HashMap<>();
      if (chromeCastSession == null) {
        data.put("initialized", false);
        data.put("connected", false);
        data.put("hasSession", false);
        data.put("hasRemoteMediaClient", false);
        data.put("playbackState", "UNKNOWN");
      } else {
        data.put("initialized", true);
        data.put("connected", chromeCastSession.isConnected());
        data.put("hasSession", chromeCastSession.hasSession());
        data.put("hasRemoteMediaClient", chromeCastSession.hasRemoteMediaClient());
        data.put("playbackState", chromeCastSession.playbackStateName());
      }
      result.success(data);
    } else if(call.method.equals("showCastDialog")) {
      showCastDialog(result);
    } else if(call.method.equals("startDiscovery")) {
      startDiscovery(result);
    } else if(call.method.equals("loadAudio")){
      if(call.hasArgument("url")){
        loadAudio(call);
        result.success(true);
      } else {
        result.error("BAD_ARGS", "Missing required arg: url", null);
      }
    }else if(call.method.equals("playAudio")){
      playAudio();
      result.success(true);
    }else if(call.method.equals("pauseAudio")){
      pauseAudio();
      result.success(true);
    }else if(call.method.equals("stopAudio")){
      stopMedia();
      result.success(true);
    } else if(call.method.equals("stopDiscovery")) {
      result.success(null);
    } else if(call.method.equals("getDiscoveredDevices")) {
      getDiscoveredDevices(result);
    } else if(call.method.equals("reconnectToDevice")) {
      String deviceName = call.argument("deviceName");
      if (deviceName == null || deviceName.isEmpty()) {
        result.success(false);
      } else {
        reconnectToDevice(deviceName, result);
      }
    } else {
      result.notImplemented();
    }
  }


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (chromeCastSession != null) {
      chromeCastSession.endSession();
    }
    if (channel != null) {
      channel.setMethodCallHandler(null);
    }
    if (connectionstatechanenel != null) {
      connectionstatechanenel.setStreamHandler(null);
    }
    if (messagestatechannel != null) {
      messagestatechannel.setStreamHandler(null);
    }
  }

  @Override
  public void  onAttachedToActivity(@NonNull ActivityPluginBinding  binding) {
    setupResources(binding);
  }
  public void setupResources(@NonNull ActivityPluginBinding binding){
    Log.i(TAG,"ON ATTACHED TO ACTIVITY");
    activity = binding.getActivity();
    ChromeCastViewFactory.activity=activity;
    chromeCastSession=new ChromeCastSession(activity);
    chromeCastSreamHandler= new ChromeCastSreamHandler();
    connectionstatechanenel.setStreamHandler(chromeCastSession);
    messagestatechannel.setStreamHandler(chromeCastSreamHandler);
    br = chromeCastSreamHandler;
    IntentFilter filter = new IntentFilter(ChromeCastSession.ACTION);
    activity.getApplicationContext().registerReceiver(br, filter);
  }
  public void freeResources(){
    Log.i(TAG,"ON DETACHED TO ACTIVITY");
    try{
      if (activity != null && br != null) {
        activity.getApplicationContext().unregisterReceiver(br);
      }
      if (connectionstatechanenel != null) {
        connectionstatechanenel.setStreamHandler(null);
      }
      if (messagestatechannel != null) {
        messagestatechannel.setStreamHandler(null);
      }
      if (chromeCastSession != null) {
        chromeCastSession.removeSessionListener();
      }
      activity = null;
    }catch (Exception e){
      Log.i(TAG,e.toString());
    }
  }
  @Override
  public void onDetachedFromActivityForConfigChanges() {
    freeResources();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding  binding) {
    Log.i(TAG,"ON RE-ATTACHED TO ACTIVITY");
    setupResources(binding);
  }

  @Override
  public void onDetachedFromActivity() {
   freeResources();
  }

  private void loadAudio(MethodCall call){
    String url=call.argument("url");
    String title=call.argument("title");
    String subtitle=call.argument("subtitle");
    String imgUrl=call.argument("imgUrl");
    Log.i(TAG,"url: "+url);
    Log.i(TAG,"title: "+title);
    Log.i(TAG,"subtitle: "+subtitle);
    Log.i(TAG,"imgUrl: "+imgUrl);
    AudioData audioData=new AudioData();
    audioData.setTitle(title);
    audioData.setSubtitle(subtitle);
    audioData.setImgUrl(imgUrl);
    audioData.setAudioUrl(url);
    chromeCastSession.loadMedia(audioData);
  }
  
  private void playAudio(){
    chromeCastSession.playMedia();
  }
  private void pauseAudio(){
    chromeCastSession.pauseMedia();
  }
  private void stopMedia(){
    chromeCastSession.stopMedia();
  }

  private void showCastDialog(@NonNull Result result) {
    try {
      if (activity == null) {
        Log.e(TAG, "showCastDialog: activity is null");
        result.error("NO_ACTIVITY", "Activity is not attached", null);
        return;
      }

      Log.i(TAG, "showCastDialog: launching chooser dialog");
      activity.runOnUiThread(() -> {
        try {
          final ContextThemeWrapper themedContext =
                  new ContextThemeWrapper(activity, R.style.GoogleCastChooserDialogTheme);
          final MediaRouteChooserDialog chooserDialog = new MediaRouteChooserDialog(themedContext);
          chooserDialog.setRouteSelector(CastContext.getSharedInstance(activity).getMergedSelector());
          chooserDialog.show();
          Log.i(TAG, "showCastDialog: chooser displayed");
          result.success(true);
        } catch (Exception e) {
          Log.e(TAG, "showCastDialog failed", e);
          result.error("SHOW_DIALOG_FAILED", e.toString(), null);
        }
      });
    } catch (Exception e) {
      Log.e(TAG, "showCastDialog outer failure", e);
      result.error("SHOW_DIALOG_FAILED", e.toString(), null);
    }
  }

  private void getDiscoveredDevices(@NonNull Result result) {
    new Handler(Looper.getMainLooper()).post(() -> {
      try {
        CastContext.getSharedInstance(applicationContext);
        MediaRouter mediaRouter = MediaRouter.getInstance(applicationContext);
        List<String> names = new ArrayList<>();
        for (MediaRouter.RouteInfo route : mediaRouter.getRoutes()) {
          if (!route.isDefault() && route.isEnabled() && !route.getName().isEmpty()) {
            names.add(route.getName());
          }
        }
        Log.i(TAG, "getDiscoveredDevices: found " + names.size() + " routes");
        result.success(names);
      } catch (Exception e) {
        Log.e(TAG, "getDiscoveredDevices failed", e);
        result.success(new ArrayList<>());
      }
    });
  }

  private void reconnectToDevice(String deviceName, @NonNull Result result) {
    new Handler(Looper.getMainLooper()).post(() -> {
      try {
        // Ensure CastContext is initialized so its MediaRouter callback is registered.
        CastContext.getSharedInstance(applicationContext);
        MediaRouter mediaRouter = MediaRouter.getInstance(applicationContext);
        List<MediaRouter.RouteInfo> routes = mediaRouter.getRoutes();
        Log.i(TAG, "reconnectToDevice: scanning " + routes.size() + " routes for '" + deviceName + "'");
        for (MediaRouter.RouteInfo route : routes) {
          if (deviceName.equals(route.getName())) {
            Log.i(TAG, "reconnectToDevice: found route, selecting");
            mediaRouter.selectRoute(route);
            result.success(true);
            return;
          }
        }
        Log.i(TAG, "reconnectToDevice: route not yet discovered");
        result.success(false);
      } catch (Exception e) {
        Log.e(TAG, "reconnectToDevice failed", e);
        result.success(false);
      }
    });
  }

  private void startDiscovery(@NonNull Result result) {
    new Handler(Looper.getMainLooper()).post(() -> {
      try {
        // Accessing CastContext initializes discovery.
        CastContext.getSharedInstance(applicationContext);
        // chromeCastSession may be null when called from a background isolate
        // (onAttachedToEngine runs off-main-thread and the constructor throws).
        // Re-initialize here on the main thread so isConnected() works after discovery.
        if (chromeCastSession == null) {
          try {
            chromeCastSession = new ChromeCastSession(applicationContext);
          } catch (Exception e) {
            Log.e(TAG, "startDiscovery: ChromeCastSession init failed", e);
          }
        }
        result.success(true);
      } catch (Exception e) {
        Log.e(TAG, "startDiscovery failed", e);
        result.error("START_DISCOVERY_FAILED", e.toString(), null);
      }
    });
  }


  public static class ChromeCastSreamHandler extends BroadcastReceiver implements EventChannel.StreamHandler {
    private EventChannel.EventSink eventSink;
    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
      this.eventSink=eventSink;
      
    }

    @Override
    public void onCancel(Object o) {
      eventSink=null;
    }
    @Override
    public void onReceive(Context context, Intent intent) {
      if(intent!=null){
        String data=intent.getStringExtra("message");
        if(data!=null&&eventSink!=null){
          eventSink.success(data);
        }
      }
    }
  }
}
