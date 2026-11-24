package com.notgovernor.tiltawort

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Listen-only BLE scanner. Empty ScanFilter, manufacturer 0x004C only.
/// Never connects. Never GATT.
class TiltListenPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "com.notgovernor.tiltawort/listen")
    private val events = EventChannel(messenger, "com.notgovernor.tiltawort/listen/events")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanning = false
    private var receiverRegistered = false
    private var permissionCb: ((Boolean) -> Unit)? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val data = result.scanRecord?.getManufacturerSpecificData(APPLE_COMPANY_ID) ?: return
            val payload = ArrayList<Int>(data.size)
            for (b in data) {
                payload.add(b.toInt() and 0xFF)
            }
            val rssi = result.rssi
            mainHandler.post {
                sink?.success(
                    hashMapOf(
                        "type" to "ad",
                        "companyId" to APPLE_COMPANY_ID,
                        "payload" to payload,
                        "rssi" to rssi,
                    ),
                )
            }
        }

        override fun onScanFailed(errorCode: Int) {
            mainHandler.post { emitAdapter(false) }
        }
    }

    private val adapterReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != BluetoothAdapter.ACTION_STATE_CHANGED) return
            val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
            when (state) {
                BluetoothAdapter.STATE_ON -> {
                    if (hasPermissions()) startScanIfPossible()
                }
                BluetoothAdapter.STATE_OFF, BluetoothAdapter.STATE_TURNING_OFF -> {
                    stopScanOnly()
                    emitAdapter(false)
                }
            }
        }
    }

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(result)
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQ_PERMISSIONS) return false
        val cb = permissionCb
        permissionCb = null
        cb?.invoke(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        return true
    }

    private fun start(result: MethodChannel.Result) {
        ensurePermissions { granted ->
            if (!granted) {
                emitAdapter(false)
                result.success(false)
                return@ensurePermissions
            }
            registerAdapterReceiver()
            val adapter = adapter()
            if (adapter == null) {
                emitAdapter(false)
                result.success(false)
                return@ensurePermissions
            }
            if (!adapter.isEnabled) {
                emitAdapter(false)
                result.success(true)
                return@ensurePermissions
            }
            startScanIfPossible()
            result.success(true)
        }
    }

    fun stop() {
        stopScanOnly()
        unregisterAdapterReceiver()
    }

    @SuppressLint("MissingPermission")
    private fun startScanIfPossible() {
        val adapter = adapter() ?: return
        if (!adapter.isEnabled) {
            emitAdapter(false)
            return
        }
        if (!hasPermissions()) {
            emitAdapter(false)
            return
        }
        stopScanOnly()
        val le = adapter.bluetoothLeScanner
        if (le == null) {
            emitAdapter(false)
            return
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        // Empty filter (same as Windows). Manufacturer 0x004C is applied in onScanResult.
        // Do not set PHY_LE_CODED.
        le.startScan(emptyList(), settings, scanCallback)
        scanner = le
        scanning = true
        emitAdapter(true)
    }

    @SuppressLint("MissingPermission")
    private fun stopScanOnly() {
        if (!scanning) {
            scanner = null
            return
        }
        try {
            scanner?.stopScan(scanCallback)
        } catch (_: Exception) {
        }
        scanning = false
        scanner = null
    }

    private fun adapter(): BluetoothAdapter? {
        val manager = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun emitAdapter(on: Boolean) {
        sink?.success(hashMapOf("type" to "adapter", "on" to on))
    }

    private fun neededPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun hasPermissions(): Boolean {
        return neededPermissions().all {
            ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun ensurePermissions(cb: (Boolean) -> Unit) {
        if (hasPermissions()) {
            cb(true)
            return
        }
        permissionCb = cb
        ActivityCompat.requestPermissions(activity, neededPermissions(), REQ_PERMISSIONS)
    }

    private fun registerAdapterReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(adapterReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(adapterReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterAdapterReceiver() {
        if (!receiverRegistered) return
        try {
            activity.unregisterReceiver(adapterReceiver)
        } catch (_: Exception) {
        }
        receiverRegistered = false
    }

    companion object {
        const val APPLE_COMPANY_ID = 0x004C
        const val REQ_PERMISSIONS = 24076
    }
}
