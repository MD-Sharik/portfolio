package com.arrowescape.inappupdate;

import android.app.Activity;
import android.util.ArraySet;

import androidx.annotation.NonNull;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.InstallStateUpdatedListener;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.InstallStatus;
import com.google.android.play.core.install.model.UpdateAvailability;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Set;

/**
 * Google Play In-App Updates for Godot.
 *
 * GDScript API (Engine.get_singleton("InAppUpdatePlugin")):
 *   checkForUpdate()          -> update_available(priority, stalenessDays) | no_update | check_failed(msg)
 *   startUpdate(immediate)    -> update_started | update_failed(code)
 *                                (flexible: update_progress(0..1) ... update_downloaded)
 *   completeUpdate()          installs a downloaded flexible update and restarts the app
 *
 * Only works for builds installed from Google Play (internal testing, closed testing or production).
 */
public class InAppUpdatePlugin extends GodotPlugin {
    private static final String NAME = "InAppUpdatePlugin";

    /** Our own code for "the update type was not allowed by Play". */
    private static final int ERR_NOT_ALLOWED = -2;
    /** Our own code for "startUpdate() called before checkForUpdate()". */
    private static final int ERR_NO_INFO = -3;

    private AppUpdateManager manager;
    private AppUpdateInfo lastInfo;

    private final InstallStateUpdatedListener installListener = state -> {
        int status = state.installStatus();
        if (status == InstallStatus.DOWNLOADING) {
            long total = state.totalBytesToDownload();
            float fraction = total > 0 ? (float) state.bytesDownloaded() / (float) total : 0f;
            emitSignal("update_progress", fraction);
        } else if (status == InstallStatus.DOWNLOADED) {
            emitSignal("update_downloaded");
        } else if (status == InstallStatus.FAILED) {
            emitSignal("update_failed", state.installErrorCode());
        }
    };

    public InAppUpdatePlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return NAME;
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new ArraySet<>();
        signals.add(new SignalInfo("update_available", Integer.class, Integer.class));
        signals.add(new SignalInfo("no_update"));
        signals.add(new SignalInfo("check_failed", String.class));
        signals.add(new SignalInfo("update_started"));
        signals.add(new SignalInfo("update_progress", Float.class));
        signals.add(new SignalInfo("update_downloaded"));
        signals.add(new SignalInfo("update_failed", Integer.class));
        return signals;
    }

    private AppUpdateManager manager() {
        if (manager == null) {
            Activity activity = getActivity();
            if (activity == null) {
                return null;
            }
            manager = AppUpdateManagerFactory.create(activity);
            manager.registerListener(installListener);
        }
        return manager;
    }

    @UsedByGodot
    public void checkForUpdate() {
        runOnHostThread(() -> {
            AppUpdateManager m = manager();
            if (m == null) {
                emitSignal("check_failed", "no activity");
                return;
            }
            m.getAppUpdateInfo()
                .addOnSuccessListener(info -> {
                    lastInfo = info;
                    if (info.installStatus() == InstallStatus.DOWNLOADED) {
                        emitSignal("update_downloaded");
                    } else if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                            && (info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
                                || info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE))) {
                        Integer stale = info.clientVersionStalenessDays();
                        emitSignal("update_available", info.updatePriority(), stale == null ? 0 : stale);
                    } else {
                        emitSignal("no_update");
                    }
                })
                .addOnFailureListener(e -> emitSignal("check_failed", String.valueOf(e.getMessage())));
        });
    }

    @UsedByGodot
    public void startUpdate(boolean immediate) {
        runOnHostThread(() -> {
            AppUpdateManager m = manager();
            Activity activity = getActivity();
            if (m == null || activity == null || lastInfo == null) {
                emitSignal("update_failed", ERR_NO_INFO);
                return;
            }
            int type = immediate ? AppUpdateType.IMMEDIATE : AppUpdateType.FLEXIBLE;
            if (!lastInfo.isUpdateTypeAllowed(type)) {
                emitSignal("update_failed", ERR_NOT_ALLOWED);
                return;
            }
            m.startUpdateFlow(lastInfo, activity, AppUpdateOptions.newBuilder(type).build())
                .addOnSuccessListener(resultCode -> {
                    if (resultCode == Activity.RESULT_OK) {
                        emitSignal("update_started");
                    } else {
                        emitSignal("update_failed", resultCode);   // RESULT_CANCELED = user said no
                    }
                })
                .addOnFailureListener(e -> emitSignal("update_failed", -1));
        });
    }

    @UsedByGodot
    public void completeUpdate() {
        runOnHostThread(() -> {
            AppUpdateManager m = manager();
            if (m != null) {
                m.completeUpdate();
            }
        });
    }

    @Override
    public void onMainResume() {
        // An update may have finished downloading while the game was in the background, and an
        // immediate update that was interrupted must be resumed.
        if (manager == null) {
            return;
        }
        manager.getAppUpdateInfo().addOnSuccessListener(info -> {
            lastInfo = info;
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                emitSignal("update_downloaded");
            } else if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                Activity activity = getActivity();
                if (activity != null) {
                    manager.startUpdateFlow(info, activity, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build());
                }
            }
        });
    }

    @Override
    public void onMainDestroy() {
        if (manager != null) {
            manager.unregisterListener(installListener);
        }
    }
}
