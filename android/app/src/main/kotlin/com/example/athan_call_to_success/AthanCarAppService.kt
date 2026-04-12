package com.example.athan_call_to_success

import android.util.Log
import androidx.car.app.CarAppService
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.validation.HostValidator

const val TAG = "AthanCar"

class AthanCarAppService : CarAppService() {
    override fun onCreateSession(): Session = AthanCarSession()

    override fun createHostValidator(): HostValidator {
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }
}

private class AthanCarSession : Session() {
    override fun onCreateScreen(intent: android.content.Intent): Screen {
        Log.d(TAG, "AthanCarSession: onCreateScreen called")
        return CarHomeScreen(carContext)
    }
}

private class CarHomeScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): ListTemplate {
        Log.d(TAG, "CarHomeScreen: onGetTemplate called")
        val itemList = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle("Homepage")
                    .addText("Daily prayer dashboard and Qibla finder")
                    .setBrowsable(true)
                    .setOnClickListener {
                        Log.d(TAG, "CarHomeScreen: Homepage row clicked")
                        screenManager.push(CarHomepageScreen(carContext))
                        Log.d(TAG, "CarHomeScreen: Homepage screen pushed to manager")
                    }
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle("Quran Page")
                    .addText("Quran browsing")
                    .setBrowsable(true)
                    .setOnClickListener {
                        Log.d(TAG, "CarHomeScreen: Quran row clicked")
                        screenManager.push(CarQuranScreen(carContext))
                        Log.d(TAG, "CarHomeScreen: Quran screen pushed to manager")
                    }
                    .build(),
            )
            .build()

        Log.d(TAG, "CarHomeScreen: Returning ListTemplate with 2 items")
        return ListTemplate.Builder()
            .setSingleList(itemList)
            .setHeaderAction(Action.APP_ICON)
            .setTitle("Athan Call to Success")
            .build()
    }
}

private class CarHomepageScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): PaneTemplate {
        Log.d(TAG, "CarHomepageScreen: onGetTemplate called")
        val pane = Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle("Homepage")
                    .addText("Homepage is available in Android Auto mode.")
                    .addText("Qibla finder is included on this page.")
                    .build(),
            )
            .addRow(
                Row.Builder()
                    .setTitle("Qibla Finder")
                    .addText("Direction guidance is available from Homepage.")
                    .build(),
            )
            .build()

        Log.d(TAG, "CarHomepageScreen: Returning PaneTemplate")
        return PaneTemplate.Builder(pane)
            .setTitle("Homepage")
            .setHeaderAction(Action.BACK)
            .build()
    }
}

private class CarQuranScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): PaneTemplate {
        Log.d(TAG, "CarQuranScreen: onGetTemplate called")
        val pane = Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle("Quran Page")
                    .addText("Quran Page is available in Android Auto mode")
                    .addText("for reading access.")
                    .build(),
            )
            .build()

        Log.d(TAG, "CarQuranScreen: Returning PaneTemplate")
        return PaneTemplate.Builder(pane)
            .setTitle("Quran Page")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
