package com.codeable.glass_forge

import android.content.Context
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The Android half of glass_forge's native signals.
 *
 * Only one of the two signals exists here. Thermal status is real
 * (`PowerManager`, API 29+). Reduce Transparency has no public Android
 * equivalent at all — the platform simply does not have the setting — so
 * `isReduceTransparencyEnabled` is answered with `notImplemented`, which the
 * Dart side turns into the null that means "unknown". Answering `false`
 * instead would be a claim about a user preference this platform never
 * collected.
 */
class GlassForgePlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var thermalChannel: EventChannel
    private var context: Context? = null
    private var thermalStreamHandler: ThermalStreamHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "glass_forge")
        channel.setMethodCallHandler(this)

        thermalChannel = EventChannel(flutterPluginBinding.binaryMessenger, "glass_forge/thermal")
        thermalStreamHandler = ThermalStreamHandler(flutterPluginBinding.applicationContext)
        thermalChannel.setStreamHandler(thermalStreamHandler)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "getThermalState" -> result.success(currentThermalName(context))
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        thermalChannel.setStreamHandler(null)
        thermalStreamHandler = null
        context = null
    }
}

/**
 * Collapses Android's seven thermal levels onto the four the wire carries.
 *
 * The wire vocabulary is iOS's because it is the coarser of the two and the
 * one that maps onto a decision. `LIGHT` is routine and must not degrade
 * anything; `MODERATE` is where the system starts shedding performance;
 * `SEVERE` and up are all "stop doing optional GPU work", and splitting them
 * further would add tiers nothing renders differently.
 *
 * Returns null below API 29, where `getCurrentThermalStatus` does not exist.
 * Null travels to Dart as "unknown", never as `nominal`.
 */
internal fun thermalStatusName(status: Int): String? =
    when (status) {
        PowerManager.THERMAL_STATUS_NONE -> "nominal"
        PowerManager.THERMAL_STATUS_LIGHT -> "fair"
        PowerManager.THERMAL_STATUS_MODERATE -> "serious"
        PowerManager.THERMAL_STATUS_SEVERE,
        PowerManager.THERMAL_STATUS_CRITICAL,
        PowerManager.THERMAL_STATUS_EMERGENCY,
        PowerManager.THERMAL_STATUS_SHUTDOWN -> "critical"
        else -> null
    }

/** Reads the current thermal status, or null when it is not readable. */
internal fun currentThermalName(context: Context?): String? {
    if (context == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
        return null
    }
    val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        ?: return null
    return thermalStatusName(power.currentThermalStatus)
}

/**
 * Pushes `PowerManager.addThermalStatusListener` changes to Dart.
 *
 * Registering no listener at all below API 29 is deliberate: an empty stream
 * is the accurate description of a platform with nothing to report, whereas
 * an error would make every Android 7/8/9 consumer handle a failure that is
 * not one.
 */
internal class ThermalStreamHandler(
    private val context: Context
) : EventChannel.StreamHandler {
    private var listener: PowerManager.OnThermalStatusChangedListener? = null

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?
    ) {
        if (events == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return

        // The first event carries the current value, so a Dart listener that
        // attaches before its one-shot query returns is not left waiting for
        // the device to change temperature.
        thermalStatusName(power.currentThermalStatus)?.let(events::success)

        val added = PowerManager.OnThermalStatusChangedListener { status ->
            thermalStatusName(status)?.let(events::success)
        }
        // The main executor, because Flutter channels are main-thread only
        // and the framework delivers thermal callbacks on whatever thread it
        // likes.
        power.addThermalStatusListener(context.mainExecutor, added)
        listener = added
    }

    override fun onCancel(arguments: Any?) {
        val active = listener ?: return
        listener = null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        power.removeThermalStatusListener(active)
    }
}
