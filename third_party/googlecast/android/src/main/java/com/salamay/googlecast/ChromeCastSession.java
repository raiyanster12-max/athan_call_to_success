package com.salamay.googlecast;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.cast.CastDevice;
import com.google.android.gms.cast.MediaInfo;
import com.google.android.gms.cast.MediaLoadRequestData;
import com.google.android.gms.cast.MediaMetadata;
import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.cast.framework.CastSession;
import com.google.android.gms.cast.framework.SessionManager;
import com.google.android.gms.cast.framework.SessionManagerListener;
import com.google.android.gms.cast.framework.media.RemoteMediaClient;
import com.google.android.gms.common.api.PendingResult;
import com.google.android.gms.common.api.Status;
import com.google.android.gms.common.images.WebImage;
import com.salamay.googlecast.Model.AudioData;

import java.util.Locale;

import io.flutter.plugin.common.EventChannel;

public class ChromeCastSession implements EventChannel.StreamHandler{
    private CastSession mCastSession;
    private SessionManager mSessionManager;
    private SessionManagerListener<CastSession> mSessionManagerListener;
    private String TAG="ChromeCastSessionListener";
    public static String ACTION="com.salamay.googlecast.mediamessage";
    private RemoteMediaClient remoteMediaClient;
    private EventChannel.EventSink connectionEvent;
    private Context context;
    private static final int UNKNOWN=0;
    private static final int IDLE=1;
    private static final int PLAYING=2;
    private static final int PAUSED=3;
    private static final int BUFFERING=4;
    private static final int LOADING=5;
    private int PLAYBACKSTATE=1;

    public ChromeCastSession(Context context){
        this.context=context;
        mSessionManager = CastContext.getSharedInstance(context).getSessionManager();
        mSessionManagerListener = new ChromeCastSessionListener();
        addSessionListener();
        mCastSession=mSessionManager.getCurrentCastSession();
        if(mCastSession!=null && mCastSession.isConnected()){
            startSession(mCastSession);
        }
    }
    public void addSessionListener(){
        if (mSessionManager != null && mSessionManagerListener != null) {
            // Remove first to avoid double registration if called multiple times
            mSessionManager.removeSessionManagerListener(mSessionManagerListener, CastSession.class);
            mSessionManager.addSessionManagerListener(mSessionManagerListener, CastSession.class);
        }
    }
    public void endSession(){
        if(mSessionManager!=null){
            if(remoteMediaClient!=null){
                remoteMediaClient.stop();
            }
            mSessionManager.endCurrentSession(true);
            mCastSession=null;
        }
    }
    public void removeSessionListener(){
        if (mSessionManager != null && mSessionManagerListener != null) {
            mSessionManager.removeSessionManagerListener(mSessionManagerListener, CastSession.class);
        }
        // DO NOT set mCastSession = null here. We want to maintain knowledge of the session
        // even if we are not listening to lifecycle events temporarily (e.g. activity detach).
    }

    public boolean isConnected(){
        if (mSessionManager != null) {
            CastSession session = mSessionManager.getCurrentCastSession();
            if (session != null && session.isConnected()) {
                if (mCastSession != session) {
                    startSession(session);
                }
                return true;
            }
        }
        return mCastSession != null && mCastSession.isConnected();
    }

    public boolean hasSession(){
        return mCastSession != null;
    }

    public boolean hasRemoteMediaClient(){
        return remoteMediaClient != null;
    }

    public String playbackStateName(){
        return playerStateName(PLAYBACKSTATE);
    }

    public void loadMedia(AudioData audioData){
        Log.i(TAG,"LOAD MEDIA");
        Log.i(TAG,audioData.getAudioUrl());
        if(mCastSession==null || !mCastSession.isConnected()){
            // If session is disconnected, try to refresh it from the manager before giving up
            mCastSession = mSessionManager.getCurrentCastSession();
            if (mCastSession != null && mCastSession.isConnected()) {
                startSession(mCastSession);
            } else {
                broadcastMessage("NO_CAST_SESSION");
                return;
            }
        }
        
        if (remoteMediaClient == null) {
            remoteMediaClient = mCastSession.getRemoteMediaClient();
            if (remoteMediaClient == null) {
                broadcastMessage("NO_REMOTE_MEDIA_CLIENT");
                return;
            }
        }

        MediaMetadata audioMetaData = new MediaMetadata(MediaMetadata.MEDIA_TYPE_MUSIC_TRACK);
        audioMetaData.putString(MediaMetadata.KEY_TITLE, audioData.getTitle());
        if(audioData.getSubtitle()!=null){
            audioMetaData.putString(MediaMetadata.KEY_SUBTITLE, audioData.getSubtitle());
        }
        if(audioData.getImgUrl()!=null){
            audioMetaData.addImage(new WebImage(Uri.parse(audioData.getImgUrl())));
        }

        final String contentType = inferContentType(audioData.getAudioUrl());
        broadcastMessage("LOAD_REQUEST(" + contentType + ")");

        MediaInfo mediaInfo = new MediaInfo.Builder(audioData.getAudioUrl())
                .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                .setContentType(contentType)
                .setMetadata(audioMetaData)
                .build();
        PendingResult<RemoteMediaClient.MediaChannelResult> s=remoteMediaClient.load(
                new MediaLoadRequestData.Builder().setMediaInfo(mediaInfo).setAutoplay(true).build()
        );
        s.addStatusListener(new PendingResult.StatusListener() {
            @Override
            public void onComplete(@NonNull Status status) {
                int statusCode = status.getStatusCode();
                String details = "LOAD_STATUS(" + statusCode + ":" + describeStatusCode(statusCode) + ")";
                Log.i(TAG, details);
                broadcastMessage(details);
                if(!status.isSuccess()){
                    broadcastMessage("ERROR(" + statusCode + ":" + describeStatusCode(statusCode) + ")");
                }
            }
        });
    }

    private void ensureSessionActive() {
        if (mSessionManager == null) {
            try {
                mSessionManager = CastContext.getSharedInstance(context).getSessionManager();
            } catch (Exception e) {
                Log.e(TAG, "Failed to get SessionManager in ensureSessionActive", e);
                return;
            }
        }
        
        CastSession current = mSessionManager.getCurrentCastSession();
        if (current != null && current.isConnected()) {
            if (mCastSession != current || remoteMediaClient == null) {
                startSession(current);
            }
        }
    }

    public void playMedia(){
        Log.i(TAG,"PLAY MEDIA");
        ensureSessionActive();
        if(mCastSession!=null && remoteMediaClient != null){
            if(PLAYBACKSTATE!=BUFFERING && PLAYBACKSTATE!=LOADING){
                remoteMediaClient.play();
            } else {
                broadcastMessage("PLAY_BLOCKED(" + playerStateName(PLAYBACKSTATE) + ")");
            }
        } else {
            broadcastMessage("PLAY_ERROR(NO_CAST_SESSION)");
        }
    }
    
    public void pauseMedia(){
        Log.i(TAG,"PAUSE MEDIA");
        ensureSessionActive();
        if(mCastSession!=null && remoteMediaClient != null){
            if(PLAYBACKSTATE!=BUFFERING && PLAYBACKSTATE!=LOADING){
                remoteMediaClient.pause();
                Log.i(TAG,"PAUSED");
            } else {
                broadcastMessage("PAUSE_BLOCKED(" + playerStateName(PLAYBACKSTATE) + ")");
            }
        } else {
            broadcastMessage("PAUSE_ERROR(NO_CAST_SESSION)");
        }
    }
    public void stopMedia(){
        Log.i(TAG,"STOP MEDIA");
        ensureSessionActive();
        if(mCastSession!=null && remoteMediaClient != null){
            remoteMediaClient.stop();
        } else {
            broadcastMessage("STOP_ERROR(NO_CAST_SESSION)");
        }
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        this.connectionEvent=eventSink;
        if(isConnected()){
            if(connectionEvent!=null){
                connectionEvent.success(true);
            }
        } else {
            if(connectionEvent!=null){
                connectionEvent.success(false);
            }
        }
        Log.i(TAG,"LISTENING TO CHROMECAST STREAM");
    }

    @Override
    public void onCancel(Object o) {
        connectionEvent=null;
    }
    public void startSession(CastSession castSession){
        if (mCastSession == castSession && remoteMediaClient != null) {
            // Session already active and registered
            return;
        }
        mCastSession = castSession;
        remoteMediaClient = castSession.getRemoteMediaClient();
        if(remoteMediaClient == null){
            broadcastMessage("NO_REMOTE_MEDIA_CLIENT");
            return;
        }
        remoteMediaClient.registerCallback(new RemoteMediaClient.Callback() {
            @Override
            public void onStatusUpdated() {
                super.onStatusUpdated();
                updateStatus();
            }
        });
        if(connectionEvent!=null){
            if (mCastSession.isConnected()){
                String deviceName = "";
                try {
                    CastDevice device = mCastSession.getCastDevice();
                    if (device != null && device.getFriendlyName() != null) {
                        deviceName = device.getFriendlyName();
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Could not get Cast device name", e);
                }
                broadcastMessage("SESSION_CONNECTED(" + deviceName + ")");
                connectionEvent.success(true);
            }else{
                broadcastMessage("SESSION_NOT_CONNECTED");
                connectionEvent.success(false);
            }
        }
    }
    public void updateStatus(){
        if(remoteMediaClient==null){
            broadcastMessage("NO_REMOTE_MEDIA_CLIENT");
            return;
        }
        int playerState=remoteMediaClient.getPlayerState();
        PLAYBACKSTATE=playerState;
        System.out.println(PLAYBACKSTATE);
        if(playerState==IDLE){
            broadcastMessage("IDLE");
            Log.i(TAG,"SENDING BROADCAST: STATUS IDLE");
        }else if(playerState==PLAYING){
            broadcastMessage("PLAYING");
            Log.i(TAG,"SENDING BROADCAST: STATUS PLAYING");
        }else if(playerState==PAUSED){
            broadcastMessage("PAUSED");
            Log.i(TAG,"SENDING BROADCAST: STATUS PAUSED");
        }else if(playerState==BUFFERING){
            broadcastMessage("BUFFERING");
            Log.i(TAG,"SENDING BROADCAST: STATUS BUFFERING");
            playMedia();
        }else if(playerState==LOADING){
            broadcastMessage("LOADING");
            Log.i(TAG,"SENDING BROADCAST: STATUS LOADING");
        }else if(playerState==UNKNOWN){
            broadcastMessage("UNKNOWN");
            Log.i(TAG,"SENDING BROADCAST: STATUS UNKNOWN");
        }
    }
    private class ChromeCastSessionListener implements SessionManagerListener<CastSession>{

        @Override
        public void onSessionResumed(@NonNull CastSession castSession, boolean b) {
            Log.i(TAG,"SESSION RESUMED");
            startSession(castSession);
        }

        @Override
        public void onSessionResuming(@NonNull  CastSession castSession, @NonNull String s) {
            mCastSession = castSession;
        }

        @Override
        public void onSessionStartFailed(@NonNull CastSession castSession, int i) {
            Log.i(TAG,"SESSION START FAILED "+String.valueOf(i));
            broadcastMessage("SESSION_START_FAILED(" + i + ")");
        }


        @Override
        public void onSessionStarted(@NonNull CastSession castSession, @NonNull String s) {
            Log.i(TAG,"SESSION STARTED "+s);
            startSession(castSession);
        }

        @Override
        public void onSessionStarting(@NonNull CastSession castSession) {
            Log.i(TAG,"SESSION STARTING");
            broadcastMessage("SESSION_STARTING");
        }

        @Override
        public void onSessionSuspended(@NonNull CastSession castSession, int i) {
            Log.i(TAG,"SESSION SUSPENDED");
            broadcastMessage("SESSION_SUSPENDED(" + i + ")");
        }

        @Override
        public void onSessionEnded(@NonNull CastSession castSession, int i) {
            Log.i(TAG,"SESSION ENDED with code: " + i + " (" + describeStatusCode(i) + ")");
            if (mCastSession == castSession) {
                mCastSession = null;
                remoteMediaClient = null;
            }
            broadcastMessage("SESSION_ENDED(" + i + ")");
            if(connectionEvent!=null){
                connectionEvent.success(false);
            }
        }

        @Override
        public void onSessionEnding(@NonNull CastSession castSession) {

        }

        @Override
        public void onSessionResumeFailed(@NonNull CastSession castSession, int i) {
            broadcastMessage("SESSION_RESUME_FAILED(" + i + ")");
            if(connectionEvent!=null){
                connectionEvent.success(false);
            }
        }
    }

    private void broadcastMessage(String message){
        Intent intent=new Intent();
        intent.setAction(ACTION);
        intent.putExtra("message",message);
        context.sendBroadcast(intent);
    }

    private String inferContentType(String url){
        if(url == null){
            return "audio/mpeg";
        }
        String normalized = url.toLowerCase(Locale.US);
        if(normalized.contains(".m3u8")) return "application/x-mpegURL";
        if(normalized.contains(".aac")) return "audio/aac";
        if(normalized.contains(".m4a")) return "audio/mp4";
        if(normalized.contains(".ogg")) return "audio/ogg";
        if(normalized.contains(".wav")) return "audio/wav";
        if(normalized.contains(".flac")) return "audio/flac";
        return "audio/mpeg";
    }

    private String describeStatusCode(int code){
        switch (code){
            case 0:
                return "SUCCESS";
            case 7:
                return "NETWORK_ERROR";
            case 8:
                return "INTERNAL_ERROR";
            case 13:
                return "ERROR";
            case 14:
                return "INTERRUPTED";
            case 15:
                return "TIMEOUT";
            case 2100:
                return "FAILED";
            case 2101:
                return "CANCELED";
            case 2102:
                return "NOT_ALLOWED";
            case 2103:
                return "REPLACED";
            case 2104:
                return "MESSAGE_SEND_BUFFER_TOO_FULL";
            case 2105:
                return "MEDIA_ERROR";
            case 2106:
                return "MEDIA_LOAD_FAILED";
            case 2107:
                return "MEDIA_LOAD_CANCELLED";
            case 2111:
                return "INVALID_REQUEST";
            default:
                return "CODE_" + code;
        }
    }

    private String playerStateName(int state){
        switch (state){
            case IDLE:
                return "IDLE";
            case PLAYING:
                return "PLAYING";
            case PAUSED:
                return "PAUSED";
            case BUFFERING:
                return "BUFFERING";
            case LOADING:
                return "LOADING";
            case UNKNOWN:
            default:
                return "UNKNOWN";
        }
    }
}
