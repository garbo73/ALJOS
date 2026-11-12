package com.aljos.launcher;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.net.Uri;
import android.widget.Toast;
import android.view.ViewTreeObserver;

// ALJOS as an app: the Home screen in a window of its own. See HomeScreen for everything else.
public class MainActivity extends Activity {
    HomeScreen screen;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        screen = new HomeScreen(this);
        screen.applyExtras(getIntent());
        setContentView(screen);
        if (getIntent() != null && getIntent().getBooleanExtra("pick_wallpaper", false)) {
            openWallpaperPicker();
            getIntent().removeExtra("pick_wallpaper");
        }
    }

    void openWallpaperPicker() {
        try {
            Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            pick.addCategory(Intent.CATEGORY_OPENABLE);
            pick.setType("image/*");
            startActivityForResult(pick, 42);
        } catch (Exception e) {
            try {
                Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
                pick.setType("image/*");
                startActivityForResult(Intent.createChooser(pick, "Elegir imagen"), 42);
            } catch (Exception ignored) {
                Toast.makeText(this, "No hay selector de imágenes disponible", Toast.LENGTH_LONG).show();
            }
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == 42 && resultCode == RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri != null) screen.importWallpaper(uri);
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        screen.applyExtras(intent);
        if (intent != null && intent.getBooleanExtra("pick_wallpaper", false)) {
            intent.removeExtra("pick_wallpaper");
            openWallpaperPicker();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        HomeService.pausedUntil = 0;
        screen.onShown(false);
        // Once this has drawn, the overlay covering Amazon's launcher can step aside. Not sooner, or
        // Amazon's launcher shows through for a moment.
        screen.getViewTreeObserver().addOnPreDrawListener(new ViewTreeObserver.OnPreDrawListener() {
            @Override public boolean onPreDraw() {
                screen.getViewTreeObserver().removeOnPreDrawListener(this);
                screen.postDelayed(HomeService::appShown, 150);
                return true;
            }
        });
    }

    // Fire TV starts on Amazon's home screen; this opens ALJOS as soon as the TV has booted, or ALJOS has updated.
    public static class Boot extends BroadcastReceiver {
        @Override
        public void onReceive(Context c, Intent i) {
            c.startActivity(new Intent(c, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
    }
}
