package com.example.athan_call_to_success.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.*
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.*

private const val TAG = "WatchMainActivity"

enum class WatchScreen {
    Home, PrayerTimes, Qibla, Tracker
}

class WatchMainActivity : ComponentActivity(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null
    
    // Synced data state
    private val syncDataState = mutableStateOf<String?>(null)
    
    // Compass orientation state
    private val headingState = mutableStateOf(0f)

    private val dataReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "Data update broadcast received")
            loadCachedData()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Sensors
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        loadCachedData()
        requestSyncFromPhone()

        setContent {
            AthanWatchAppTheme {
                MainWatchNavigation()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter("com.example.athan.WEAR_DATA_UPDATED")
        registerReceiver(dataReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        
        rotationSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    override fun onStop() {
        unregisterReceiver(dataReceiver)
        sensorManager.unregisterListener(this)
        super.onStop()
    }

    private fun loadCachedData() {
        val prefs = getSharedPreferences("athan_wear_prefs", Context.MODE_PRIVATE)
        val data = prefs.getString("sync_data", null)
        Log.d(TAG, "Loaded cache: $data")
        syncDataState.value = data
    }

    private fun requestSyncFromPhone() {
        Log.d(TAG, "Requesting sync from phone")
        val messageClient = Wearable.getMessageClient(this)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                messageClient.sendMessage(node.id, "/request_sync", null)
            }
        }
    }

    fun sendTrackerToggleToPhone(prayerName: String, completed: Boolean) {
        val messageClient = Wearable.getMessageClient(this)
        val json = JSONObject().apply {
            put("prayerName", prayerName)
            put("completed", completed)
        }
        val data = json.toString().toByteArray()
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                messageClient.sendMessage(node.id, "/tracker_update", data)
            }
        }
        
        // Optimistically update local cache
        syncDataState.value?.let { currentJson ->
            try {
                val obj = JSONObject(currentJson)
                val tracker = obj.optJSONObject("tracker") ?: JSONObject()
                tracker.put(prayerName, completed)
                obj.put("tracker", tracker)
                val newJson = obj.toString()
                syncDataState.value = newJson
                getSharedPreferences("athan_wear_prefs", Context.MODE_PRIVATE)
                    .edit()
                    .putString("sync_data", newJson)
                    .apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update local cache: $e")
            }
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ROTATION_VECTOR) {
            val rotationMatrix = FloatArray(9)
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            val orientation = FloatArray(3)
            SensorManager.getOrientation(rotationMatrix, orientation)
            val headingRad = orientation[0]
            var headingDeg = Math.toDegrees(headingRad.toDouble()).toFloat()
            headingDeg = (headingDeg + 360f) % 360f
            headingState.value = headingDeg
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    @Composable
    fun MainWatchNavigation() {
        var currentScreen by remember { mutableStateOf(WatchScreen.Home) }
        val syncData by syncDataState
        val heading by headingState

        val parsedData = remember(syncData) {
            if (syncData != null) {
                runCatching { JSONObject(syncData!!) }.getOrNull()
            } else {
                null
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF1C1B1F))
        ) {
            when (currentScreen) {
                WatchScreen.Home -> WatchHomeScreen(
                    data = parsedData,
                    onNavigate = { currentScreen = it },
                    onRequestSync = { requestSyncFromPhone() }
                )
                WatchScreen.PrayerTimes -> WatchPrayerTimesScreen(
                    data = parsedData,
                    onBack = { currentScreen = WatchScreen.Home }
                )
                WatchScreen.Qibla -> WatchQiblaScreen(
                    data = parsedData,
                    heading = heading,
                    onBack = { currentScreen = WatchScreen.Home }
                )
                WatchScreen.Tracker -> WatchTrackerScreen(
                    data = parsedData,
                    onToggle = { name, completed -> sendTrackerToggleToPhone(name, completed) },
                    onBack = { currentScreen = WatchScreen.Home }
                )
            }
        }
    }
}

// ── UI Screens ──────────────────────────────────────────────────────────────

@Composable
fun WatchHomeScreen(
    data: JSONObject?,
    onNavigate: (WatchScreen) -> Unit,
    onRequestSync: () -> Unit
) {
    val listState = rememberScalingLazyListState()
    
    // Parse next prayer countdown
    val nextPrayerName = data?.optString("nextPrayerName", "Athan") ?: "Athan"
    val nextPrayerTimeStr = data?.optString("nextPrayerTime", "") ?: ""
    
    val countdownText = remember(nextPrayerTimeStr) {
        if (nextPrayerTimeStr.isNotEmpty()) {
            try {
                val format = SimpleDateFormat("HH:mm", Locale.getDefault())
                val parsedTime = format.parse(nextPrayerTimeStr)
                if (parsedTime != null) {
                    val cal = Calendar.getInstance()
                    val now = Calendar.getInstance()
                    val pCal = Calendar.getInstance().apply {
                        time = parsedTime
                        set(Calendar.YEAR, now.get(Calendar.YEAR))
                        set(Calendar.MONTH, now.get(Calendar.MONTH))
                        set(Calendar.DAY_OF_MONTH, now.get(Calendar.DAY_OF_MONTH))
                    }
                    if (pCal.before(now)) {
                        pCal.add(Calendar.DAY_OF_MONTH, 1)
                    }
                    val diffMs = pCal.timeInMillis - now.timeInMillis
                    val diffHrs = diffMs / 3600000
                    val diffMins = (diffMs % 3600000) / 60000
                    if (diffHrs > 0) "${diffHrs}h ${diffMins}m" else "${diffMins}m"
                } else {
                    "--"
                }
            } catch (e: Exception) {
                "--"
            }
        } else {
            "Open Phone App"
        }
    }

    ScalingLazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 20.dp)
    ) {
        item {
            Text(
                text = "Next: $nextPrayerName",
                fontSize = 13.sp,
                fontWeight = FontWeight.Normal,
                color = Color(0xFF8A8A92),
                textAlign = TextAlign.Center
            )
        }
        item {
            Text(
                text = countdownText,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00796B),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }
        item {
            Button(
                onClick = { onNavigate(WatchScreen.PrayerTimes) },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2C2B30)),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 2.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Start,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Text("⏰  Prayer Times", fontSize = 14.sp)
                }
            }
        }
        item {
            Button(
                onClick = { onNavigate(WatchScreen.Qibla) },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2C2B30)),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 2.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Start,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Text("🧭  Qibla Direction", fontSize = 14.sp)
                }
            }
        }
        item {
            Button(
                onClick = { onNavigate(WatchScreen.Tracker) },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2C2B30)),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 2.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Start,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
                ) {
                    Text("✅  Daily Tracker", fontSize = 14.sp)
                }
            }
        }
        item {
            Button(
                onClick = onRequestSync,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E1E1E)),
                modifier = Modifier
                    .wrapContentSize()
                    .padding(top = 8.dp)
            ) {
                Text("Sync Phone 🔄", fontSize = 11.sp, color = Color.Gray)
            }
        }
    }
}

@Composable
fun WatchPrayerTimesScreen(data: JSONObject?, onBack: () -> Unit) {
    val listState = rememberScalingLazyListState()
    val timesObj = data?.optJSONObject("prayerTimes")
    
    val prayers = listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")

    ScalingLazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 20.dp)
    ) {
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxWidth().clickable { onBack() }.padding(bottom = 6.dp)
            ) {
                Text("← Back", fontSize = 12.sp, color = Color.Gray)
            }
        }
        item {
            Text(
                "Prayer Times",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00796B),
                modifier = Modifier.padding(bottom = 6.dp)
            )
        }
        
        if (timesObj == null) {
            item {
                Text(
                    "Open app on phone to sync prayer times",
                    fontSize = 12.sp,
                    color = Color.LightGray,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 10.dp)
                )
            }
        } else {
            prayers.forEach { name ->
                val timeStr = timesObj.optString(name, "--:--")
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFF2C2B30), shape = CircleShape)
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(name, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text(timeStr, color = Color(0xFF00796B), fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun WatchQiblaScreen(data: JSONObject?, heading: Float, onBack: () -> Unit) {
    val lat = data?.optDouble("lat", Double.NaN) ?: Double.NaN
    val lng = data?.optDouble("lng", Double.NaN) ?: Double.NaN

    val bearing = remember(lat, lng) {
        if (!lat.isNaN() && !lng.isNaN()) {
            val φ1 = Math.toRadians(lat)
            val φ2 = Math.toRadians(21.4225)
            val Δλ = Math.toRadians(39.8262 - lng)
            val x = sin(Δλ) * cos(φ2)
            val y = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
            (Math.toDegrees(atan2(x, y)) + 360.0).toFloat() % 360.0f
        } else {
            0f
        }
    }

    val distanceKm = remember(lat, lng) {
        if (!lat.isNaN() && !lng.isNaN()) {
            val r = 6371.0
            val dLat = Math.toRadians(21.4225 - lat)
            val dLon = Math.toRadians(39.8262 - lng)
            val a = sin(dLat / 2) * sin(dLat / 2) +
                    cos(Math.toRadians(lat)) * cos(Math.toRadians(21.4225)) *
                    sin(dLon / 2) * sin(dLon / 2)
            (2.0 * r * asin(sqrt(a))).toInt()
        } else {
            -1
        }
    }

    // Relative angle of Mecca from current heading
    val relativeAngle = (bearing - heading + 360f) % 360f
    
    // Smooth compass animation
    val animatedAngle by animateFloatAsState(targetValue = -heading)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onBack() }
                .padding(top = 4.dp),
            contentAlignment = Alignment.Center
        ) {
            Text("← Home", fontSize = 12.sp, color = Color.Gray)
        }

        if (lat.isNaN()) {
            Text(
                "Open phone app to sync GPS location",
                fontSize = 12.sp,
                color = Color.LightGray,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 12.dp)
            )
            Spacer(modifier = Modifier.height(10.dp))
        } else {
            // Interactive Compass
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF2C2B30)),
                contentAlignment = Alignment.Center
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val center = Offset(size.width / 2, size.height / 2)
                    val radius = size.width / 2

                    // Rotate the dial based on current heading
                    rotate(animatedAngle, center) {
                        // Draw North marker
                        drawCircle(Color.Red, radius = 4f, center = Offset(center.x, center.y - radius + 12f))
                        
                        // Draw compass lines
                        drawLine(
                            Color.LightGray,
                            start = Offset(center.x, 10f),
                            end = Offset(center.x, 20f),
                            strokeWidth = 2f
                        )
                        drawLine(
                            Color.LightGray,
                            start = Offset(center.x, size.height - 10f),
                            end = Offset(center.x, size.height - 20f),
                            strokeWidth = 2f
                        )
                    }

                    // Draw Mecca relative green pointer
                    rotate(bearing - heading, center) {
                        val path = Path().apply {
                            moveTo(center.x, center.y - radius + 10f)
                            lineTo(center.x - 8f, center.y - radius + 25f)
                            lineTo(center.x + 8f, center.y - radius + 25f)
                            close()
                        }
                        drawPath(path, Color(0xFF00796B))
                    }
                    
                    // Center dot
                    drawCircle(Color.White, radius = 5f, center = center)
                }
            }

            Text(
                text = "${relativeAngle.toInt()}° Mecca",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00796B)
            )
            
            Text(
                text = if (distanceKm > 0) "%,d km to Mecca".format(distanceKm) else "",
                fontSize = 11.sp,
                color = Color.Gray
            )
        }
    }
}

@Composable
fun WatchTrackerScreen(
    data: JSONObject?,
    onToggle: (String, Boolean) -> Unit,
    onBack: () -> Unit
) {
    val listState = rememberScalingLazyListState()
    val trackerObj = data?.optJSONObject("tracker")
    val prayers = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")

    ScalingLazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 20.dp)
    ) {
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxWidth().clickable { onBack() }.padding(bottom = 6.dp)
            ) {
                Text("← Back", fontSize = 12.sp, color = Color.Gray)
            }
        }
        item {
            Text(
                "Daily Tracker",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF00796B),
                modifier = Modifier.padding(bottom = 6.dp)
            )
        }

        if (trackerObj == null) {
            item {
                Text(
                    "Open phone app to sync tracker checklist",
                    fontSize = 12.sp,
                    color = Color.LightGray,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 12.dp)
                )
            }
        } else {
            prayers.forEach { name ->
                val isCompleted = trackerObj.optBoolean(name, false)
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFF2C2B30), shape = CircleShape)
                            .clickable { onToggle(name, !isCompleted) }
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(name, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Icon(
                            imageVector = if (isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                            contentDescription = null,
                            tint = if (isCompleted) Color(0xFF00796B) else Color.LightGray,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun AthanWatchAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = ColorScheme(
            primary = Color(0xFF00796B),
            onPrimary = Color.white,
            secondary = Color(0xFF00BFA5),
            onSecondary = Color.black,
            onSurface = Color.white,
            onSurfaceVariant = Color.lightGray,
            background = Color(0xFF1C1B1F),
            onBackground = Color.white,
            error = Color(0xFFCF6679),
            onError = Color.black,
            errorContainer = Color(0xFFCF6679),
            onErrorContainer = Color.black,
            primaryContainer = Color(0xFF00796B),
            onPrimaryContainer = Color.white,
            secondaryContainer = Color(0xFF00BFA5),
            onSecondaryContainer = Color.black,
            surfaceContainer = Color(0xFF2C2B30),
            surfaceContainerLow = Color(0xFF1C1B1F),
            surfaceContainerHigh = Color(0xFF3C3B40),
            outline = Color.gray,
            outlineVariant = Color.darkGray
        ),
        content = content
    )
}

val Color.Companion.white get() = Color(0xFFFFFFFF)
val Color.Companion.black get() = Color(0xFF000000)
val Color.Companion.gray get() = Color(0xFF888888)
val Color.Companion.lightGray get() = Color(0xFFCCCCCC)
val Color.Companion.darkGray get() = Color(0xFF333333)
