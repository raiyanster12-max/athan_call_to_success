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
import androidx.mediarouter.media.MediaRouteSelector;
import androidx.annotation.NonNull;
import com.salamay.googlecast.ChromeCastViewFactory;
import com.salamay.googlecast.Model.AudioData;
import com.google.android.gms.cast.CastDevice;
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
  private MediaRouter.Callback discoveryCallback;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    applicationContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "googlecast");
    channel.setMethodCallHandler(this);
    flutterPluginBinding.getPlatformViewRegistry().registerViewFactory("ChromeCastButton",new ChromeCastViewFactory());
    connectionstatechanenel=new EventChannel(flutterPluginBinding.getBinaryMessenger(),chromecastconnectionstate);
    messagestatechannel=new EventChannel(flutterPluginBinding.getBinaryMessenger(), chromecastmediamessage);
    
    // Initialize session for background execution where activity is null.
    // Use the UI thread to ensure CastContext.getSharedInstance doesn't crash.
    new Handler(Looper.getMainLooper()).post(() -> {
      if (chromeCastSession == null) {
        try {
          // Force CastContext initialization early to catch potential errors
          CastContext.getSharedInstance(applicationContext);
          chromeCastSession = new ChromeCastSession(applicationContext);
          if (connectionstatechanenel != null) {
              connectionstatechanenel.setStreamHandler(chromeCastSession);
          }
          Log.i(TAG, "ChromeCastSession initialized successfully in onAttachedToEngine");
        } catch (Exception e) {
          Log.e(TAG, "Failed to initialize ChromeCastSession in onAttachedToEngine: " + e.getMessage(), e);
        }
      }
    });
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
      if (chromeCastSession != null) {
          // Trigger a session check before reporting state
          new Handler(Looper.getMainLooper()).post(() -> {
              try {
                  CastSession s = CastContext.getSharedInstance(applicationContext)
                          .getSessionManager().getCurrentCastSession();
                  if (s != null && s.isConnected()) {
                      chromeCastSession.startSession(s);
                  }
              } catch (Exception ignored) {}
          });
      }

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
      stopDiscovery(result);
    } else if(call.method.equals("getDiscoveredDevices")) {
      getDiscoveredDevices(result);
    } else if(call.method.equals("reconnectToDevice")) {
      String deviceName = call.argument("deviceName");
      if (deviceName == null || deviceName.isEmpty()) {
        result.success(false);
      } else {
        reconnectToDevice(deviceName, result);
      }
    } else if(call.method.equals("connectToIp")) {
      String ip = call.argument("ip");
      if (ip == null || ip.isEmpty()) {
        result.success(false);
      } else {
        connectToIp(ip, result);
      }
    } else {
      result.notImplemented();
    }
  }


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    // DO NOT call chromeCastSession.endSession() here.
    // We want the Cast session to persist even if the Flutter engine is detached,
    // allowing it to be picked up again by a background service or the next activity attach.
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
    Log.i(TAG,"ON ATTACHED TO ACTIVITY");
    activity = binding.getActivity();
    ChromeCastViewFactory.activity=activity;
    
    // If we already have a session (from engine attach), just update the context/activity
    // and re-attach listeners if needed.
    if (chromeCastSession == null) {
        chromeCastSession = new ChromeCastSession(activity);
    } else {
        chromeCastSession.addSessionListener();
    }

    chromeCastSreamHandler= new ChromeCastSreamHandler();
    connectionstatechanenel.setStreamHandler(chromeCastSession);
    messagestatechannel.setStreamHandler(chromeCastSreamHandler);
    br = chromeCastSreamHandler;
    IntentFilter filter = new IntentFilter(ChromeCastSession.ACTION);
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        activity.getApplicationContext().registerReceiver(br, filter, Context.RECEIVER_EXPORTED);
    } else {
        activity.getApplicationContext().registerReceiver(br, filter);
    }
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
    activity = binding.getActivity();
    if (chromeCastSession == null) {
        chromeCastSession = new ChromeCastSession(activity);
    } else {
        chromeCastSession.addSessionListener();
    }
    chromeCastSreamHandler= new ChromeCastSreamHandler();
    connectionstatechanenel.setStreamHandler(chromeCastSession);
    messagestatechannel.setStreamHandler(chromeCastSreamHandler);
    br = chromeCastSreamHandler;
    IntentFilter filter = new IntentFilter(ChromeCastSession.ACTION);
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        activity.getApplicationContext().registerReceiver(br, filter, Context.RECEIVER_EXPORTED);
    } else {
        activity.getApplicationContext().registerReceiver(br, filter);
    }
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

  private void reconnectToDevice(final String deviceName, @NonNull final Result result) {
    final Handler handler = new Handler(Looper.getMainLooper());
    handler.post(new Runnable() {
      int retries = 0;
      @Override
      public void run() {
        try {
          CastContext castContext = CastContext.getSharedInstance(applicationContext);
          MediaRouter mediaRouter = MediaRouter.getInstance(applicationContext);

          // 1. Check if we're already connected to THIS device
          CastSession currentSession = castContext.getSessionManager().getCurrentCastSession();
          if (currentSession != null && currentSession.isConnected()) {
            CastDevice device = currentSession.getCastDevice();
            if (device != null && deviceName.equals(device.getFriendlyName())) {
              Log.i(TAG, "reconnectToDevice: already connected to " + deviceName);
              result.success(true);
              return;
            }
          }

          // 2. Scan discovered routes
          List<MediaRouter.RouteInfo> routes = mediaRouter.getRoutes();
          Log.d(TAG, "reconnectToDevice: scanning " + routes.size() + " routes for '" + deviceName + "' (try " + retries + ")");
          for (MediaRouter.RouteInfo route : routes) {
            if (deviceName.equals(route.getName())) {
              Log.i(TAG, "reconnectToDevice: found route, selecting");
              mediaRouter.selectRoute(route);
              result.success(true);
              return;
            }
          }

          // 3. Retry while discovery runs
          if (retries < 25) { // Wait up to 25s for mDNS to resolve
            retries++;
            handler.postDelayed(this, 1000);
          } else {
            Log.i(TAG, "reconnectToDevice: device '" + deviceName + "' not found after timeout");
            result.success(false);
          }
        } catch (Exception e) {
          Log.e(TAG, "reconnectToDevice failure", e);
          result.success(false);
        }
      }
    });
  }

  private void connectToIp(final String ip, @NonNull final Result result) {
    final Handler handler = new Handler(Looper.getMainLooper());
    handler.post(new Runnable() {
      int retries = 0;
      @Override
      public void run() {
        try {
          CastContext castContext = CastContext.getSharedInstance(applicationContext);
          MediaRouter mediaRouter = MediaRouter.getInstance(applicationContext);

          // 1. Check if we're already connected to THIS IP
          CastSession currentSession = castContext.getSessionManager().getCurrentCastSession();
          if (currentSession != null && currentSession.isConnected()) {
            CastDevice device = currentSession.getCastDevice();
            if (device != null && device.getIpAddress() != null) {
              if (ip.equals(device.getIpAddress().getHostAddress())) {
                Log.i(TAG, "connectToIp: already connected to " + ip);
                result.success(true);
                return;
              }
            }
          }

          // 2. Scan routes by IP
          List<MediaRouter.RouteInfo> routes = mediaRouter.getRoutes();
          Log.d(TAG, "connectToIp: scanning " + routes.size() + " routes for IP " + ip + " (try " + retries + ")");
          for (MediaRouter.RouteInfo route : routes) {
            CastDevice d = CastDevice.getFromBundle(route.getExtras());
            if (d != null && d.getIpAddress() != null) {
              String deviceIp = d.getIpAddress().getHostAddress();
              if (ip.equals(deviceIp)) {
                Log.i(TAG, "connectToIp: found route by IP, selecting");
                mediaRouter.selectRoute(route);
                result.success(true);
                return;
              }
            }
          }

          // 3. Retry while discovery runs
          if (retries < 20) { // Wait up to 20s for IP discovery
            retries++;
            handler.postDelayed(this, 1000);
          } else {
            Log.i(TAG, "connectToIp: IP " + ip + " not found after timeout");
            result.success(false);
          }
        } catch (Exception e) {
          Log.e(TAG, "connectToIp failure", e);
          result.success(false);
        }
      }
    });
  }

  private void startDiscovery(@NonNull Result result) {
    new Handler(Looper.getMainLooper()).post(() -> {
      try {
        CastContext castContext = CastContext.getSharedInstance(applicationContext);
        MediaRouter mediaRouter = MediaRouter.getInstance(applicationContext);
        MediaRouteSelector selector = castContext.getMergedSelector();

        if (discoveryCallback == null) {
            discoveryCallback = new MediaRouter.Callback() {
                @Override
                public void onRouteAdded(MediaRouter router, MediaRouter.RouteInfo route) {
                    super.onRouteAdded(router, route);
                    Log.d(TAG, "Route added: " + route.getName());
                }
            };
        }
        
        // Force active scan to ensure devices are found even in background/when idle
        mediaRouter.removeCallback(discoveryCallback);
        mediaRouter.addCallback(selector, discoveryCallback, MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN);
        
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

  private void stopDiscovery(@NonNull Result result) {
      new Handler(Looper.getMainLooper()).post(() -> {
          try {
              if (discoveryCallback != null) {
                  MediaRouter.getInstance(applicationContext).removeCallback(discoveryCallback);
                  discoveryCallback = null;
              }
              result.success(true);
          } catch (Exception e) {
              result.error("STOP_DISCOVERY_FAILED", e.toString(), null);
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
