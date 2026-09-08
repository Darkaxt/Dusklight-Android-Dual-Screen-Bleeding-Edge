package dev.twilitrealm.dusk;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.Display;
import android.view.View;
import android.view.WindowManager;

import org.libsdl.app.SDLControllerManager;

/**
 * Hosts the companion screen on the device's DEFAULT display, for when the game
 * has been launched onto the secondary one ("Swap Screens").
 *
 * A Presentation cannot do this job. The framework refuses to attach
 * presentation windows to the default display, so the swapped layout needs a
 * real activity; unswapped, {@link DuskActivity.AuxPresentation} is still what
 * drives the second screen.
 */
public class DuskCompanionActivity extends Activity {
    private static final String TAG = "DuskActivity";

    /**
     * DuskActivity starts and finishes us, and both run in the same process, so
     * a static handle is enough to find the live instance. Volatile because the
     * finish comes from the game thread's pause path, not this activity's.
     */
    static volatile DuskCompanionActivity instance;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            // Focusable, deliberately, even though AuxPresentation is not.
            //
            // FLAG_NOT_FOCUSABLE was tried here and does keep the controller
            // with the game — but it also means this window cannot hide the
            // status bar or the gesture pill: applyImmersive() drives
            // WindowInsetsController, and the system only honours that from a
            // window that can take focus. On the default display, where the
            // real system bars live, that left them sitting on top of the
            // companion.
            //
            // So this window takes focus and hides the bars, and the gamepad
            // problem is solved at the other end instead — see
            // dispatchKeyEvent/onGenericMotionEvent below, which hand controller
            // input back to the game window.
            DuskActivity.applyImmersive(getWindow());
            getWindow().getDecorView().setBackgroundColor(Color.BLACK);

            setContentView(DuskActivity.createCompanionSurfaceView(
                this, DuskActivity.companionBufferSize(getDisplayCompat())));
            // Edge to edge, for the reason the Presentation consumes insets:
            // hiding the bars stops them being drawn but the content frame is
            // still inset for them, leaving a band the companion never fills.
            final View decor = getWindow().getDecorView();
            decor.setOnApplyWindowInsetsListener(
                (v, insets) -> android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R
                    ? android.view.WindowInsets.CONSUMED
                    : insets.consumeSystemWindowInsets());
            decor.requestApplyInsets();
        } catch (Throwable e) {
            // We share the game's process: throwing out of here would take the
            // game down with the companion. Drop the second screen instead.
            Log.e(TAG, "Companion activity failed", e);
            finish();
            // instance was never set, so onDestroy will not report for us —
            // and the game would otherwise wait forever on a launch that is
            // already dead, never falling back to a single-screen HUD.
            DuskActivity.onCompanionActivityChanged();
            return;
        }
        instance = this;
        Log.i(TAG, "Companion activity up on display " + getDisplayCompat().getDisplayId());
        // Only now is there really a second screen to draw on; the game
        // activity could not have known at startActivity() time.
        DuskActivity.onCompanionActivityChanged();
    }

    @SuppressWarnings("deprecation")  // getDefaultDisplay(), API 26-29 fallback
    private Display getDisplayCompat() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            Display d = getDisplay();
            if (d != null) {
                return d;
            }
        }
        return getWindowManager().getDefaultDisplay();
    }

    /**
     * Controller input that lands here belongs to the game.
     *
     * Key events go to whichever window holds focus, and touching the companion
     * moves focus to this one — so without this, picking something on the
     * companion left the gamepad dead until the player touched the game screen
     * again. Forwarding into the game activity's own dispatch puts the event
     * back on SDL's path; its window keeps its internal view focus whether or
     * not the system considers it the focused window.
     */
    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (isFromController(event.getDevice())) {
            DuskActivity game = DuskActivity.instance;
            if (game != null && game.dispatchKeyEvent(event)) {
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    /** Sticks and triggers, same reasoning as dispatchKeyEvent. */
    @Override
    public boolean onGenericMotionEvent(MotionEvent event) {
        if (SDLControllerManager.isDeviceSDLJoystick(event.getDeviceId())
            && SDLControllerManager.handleJoystickMotionEvent(event)) {
            return true;
        }
        return super.onGenericMotionEvent(event);
    }

    /**
     * Only real controllers are forwarded. Back/volume and the like must keep
     * working on this screen, and handing them to the game would swallow them.
     */
    private static boolean isFromController(InputDevice device) {
        if (device == null) {
            return false;
        }
        final int sources = device.getSources();
        return (sources & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
            || (sources & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK;
    }

    @Override
    protected void onDestroy() {
        if (instance == this) {
            instance = null;
            // Native must stop hiding the main-screen HUD for a companion that
            // no longer exists. Also covers the user swiping this task away
            // independently of the game, which dismissAux() never sees.
            DuskActivity.onCompanionActivityChanged();
        }
        super.onDestroy();
    }
}
