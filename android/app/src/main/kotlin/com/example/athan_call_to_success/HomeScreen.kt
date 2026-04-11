package com.example.athan_call_to_success

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

/**
 * The Android Auto home screen.
 *
 * Displays two options matching the app's homepage:
 *   - Qibla Finder  →  [QiblaScreen]
 *   - Quran         →  [QuranScreen]
 */
class HomeScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val itemList = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle("Qibla Finder")
                    .addText("Find the direction of prayer")
                    .setOnClickListener { screenManager.push(QiblaScreen(carContext)) }
                    .build()
            )
            .addItem(
                Row.Builder()
                    .setTitle("Quran")
                    .addText("Browse the Holy Quran")
                    .setOnClickListener { screenManager.push(QuranScreen(carContext)) }
                    .build()
            )
            .build()

        return ListTemplate.Builder()
            .setTitle("Athan – Call to Success")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(itemList)
            .build()
    }
}
