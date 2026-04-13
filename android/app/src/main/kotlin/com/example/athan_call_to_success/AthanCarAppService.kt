package com.example.athan_call_to_success

import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * Entry-point for the Android Auto / Android Automotive OS integration.
 *
 * The Car App Library discovers this service via the intent-filter declared in
 * AndroidManifest.xml and delegates all UI rendering to [AthanSession].
 */
class AthanCarAppService : CarAppService() {

    /**
     * In debug builds, allow any host so the Desktop Head Unit (DHU) and
     * other testing tools work out of the box.  In release/production builds
     * restrict connections to the Car App Library's curated allowlist
     * (`hosts_allowlist_sample`), which contains the package names and
     * signing-certificate hashes for all known, Google-verified Android Auto
     * and Android Automotive OS hosts.  This is the standard production
     * validator recommended in the Car App Library documentation.
     */
    override fun createHostValidator(): HostValidator {
        val isDebuggable =
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        return if (isDebuggable) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
    }

    override fun onCreateSession(): Session = AthanSession()
}
