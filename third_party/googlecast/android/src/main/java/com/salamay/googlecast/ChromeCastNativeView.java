package com.salamay.googlecast;

import android.content.Context;
import android.view.ContextThemeWrapper;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.mediarouter.app.MediaRouteButton;

import com.google.android.gms.cast.framework.CastButtonFactory;

import io.flutter.plugin.platform.PlatformView;

import java.util.Map;


public class ChromeCastNativeView implements PlatformView {

    @NonNull private final MediaRouteButton chromecastbutton;

    public ChromeCastNativeView(@NonNull Context context, int id, @Nullable Map<String, Object> creationParams) {
    // MediaRouteButton requires a non-translucent themed background.
    // Flutter's platform view context can be translucent, so wrap it.
    final ContextThemeWrapper themedContext =
            new ContextThemeWrapper(context, R.style.GoogleCastButtonTheme);

        chromecastbutton = new MediaRouteButton(
            themedContext,
            null,
            androidx.mediarouter.R.attr.mediaRouteButtonStyle
        );
    CastButtonFactory.setUpMediaRouteButton(themedContext, chromecastbutton);
    }


    @NonNull
    @Override
    public View getView() {
        return chromecastbutton;
    }

    @Override
    public void dispose() {
        // No-op.
    }

}
