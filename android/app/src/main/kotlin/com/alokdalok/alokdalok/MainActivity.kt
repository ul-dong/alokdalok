package com.alokdalok.alokdalok

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 눈 지킴이 발열·절전 백오프용 기기 상태 채널 (플러그인 없이 직접).
 *
 * `alokdalok/device_heat`:
 * - 앱 → `start`: 지금 상태를 돌려주고, 이때부터 바뀔 때마다 앱으로 `changed`를 보낸다.
 * - 상태 = { thermal: PowerManager.THERMAL_STATUS_* (0~6, API 29 미만은 -1 = 모름),
 *            powerSave: isPowerSaveMode, battery: 0~100 (모르면 -1) }
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var watching = false
    private var lastBattery = -2
    private var thermalListener: Any? = null

    private val power: PowerManager
        get() = getSystemService(Context.POWER_SERVICE) as PowerManager

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_BATTERY_CHANGED) {
                // 배터리 알림은 전압·온도가 바뀔 때마다 오므로 %가 바뀔 때만 알린다
                val level = batteryOf(intent)
                if (level == lastBattery) return
                lastBattery = level
            }
            send()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "alokdalok/device_heat",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        watch()
                        result.success(status())
                    }
                    "read" -> result.success(status())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun thermal(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) power.currentThermalStatus else -1

    private fun batteryOf(intent: Intent?): Int {
        if (intent == null) return -1
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        return if (level < 0 || scale <= 0) -1 else level * 100 / scale
    }

    private fun battery(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val v = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: Int.MIN_VALUE
        if (v in 0..100) return v
        return batteryOf(registerReceiverCompat(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)))
    }

    private fun status(): Map<String, Any> = mapOf(
        "thermal" to thermal(),
        "powerSave" to power.isPowerSaveMode,
        "battery" to battery(),
    )

    private fun send() {
        channel?.invokeMethod("changed", status())
    }

    private fun registerReceiverCompat(r: BroadcastReceiver?, filter: IntentFilter): Intent? =
        if (Build.VERSION.SDK_INT >= 33) {
            // 시스템 알림(배터리·절전)은 NOT_EXPORTED여도 받는다
            registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(r, filter)
        }

    private fun watch() {
        if (watching) return
        watching = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val l = PowerManager.OnThermalStatusChangedListener { send() }
            power.addThermalStatusListener(mainExecutor, l)
            thermalListener = l
        }
        val filter = IntentFilter().apply {
            addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }
        registerReceiverCompat(receiver, filter)
    }

    override fun onDestroy() {
        if (watching) {
            watching = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                (thermalListener as? PowerManager.OnThermalStatusChangedListener)?.let {
                    power.removeThermalStatusListener(it)
                }
            }
            thermalListener = null
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
        }
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }
}
