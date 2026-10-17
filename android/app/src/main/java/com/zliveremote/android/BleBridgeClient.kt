package com.zliveremote.android

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import java.nio.charset.StandardCharsets
import java.util.UUID

@SuppressLint("MissingPermission")
class BleBridgeClient(
    context: Context,
    private val onReadyChanged: (Boolean) -> Unit,
    private val onEvent: (BridgeEvent) -> Unit,
    private val onLog: (String) -> Unit
) {
    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F001")
        val COMMAND_UUID: UUID = UUID.fromString("A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F002")
        val EVENT_UUID: UUID = UUID.fromString("A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F003")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")
    }

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private val manager = appContext.getSystemService(BluetoothManager::class.java)
    private val adapter: BluetoothAdapter? get() = manager?.adapter

    private var gatt: BluetoothGatt? = null
    private var commandCharacteristic: BluetoothGattCharacteristic? = null
    private var eventCharacteristic: BluetoothGattCharacteristic? = null
    private var started = false
    private var scanning = false
    private var ready = false
    private var reconnectRunnable: Runnable? = null

    private var incoming = ByteArray(0)

    fun start() {
        if (started) {
            if (!ready && gatt == null) scan()
            return
        }

        started = true
        scan()
    }

    fun stop() {
        started = false
        reconnectRunnable?.let(handler::removeCallbacks)
        reconnectRunnable = null
        stopScan()
        resetGatt()
    }

    fun send(command: BridgeCommand) {
        val currentGatt = gatt
        val characteristic = commandCharacteristic

        if (!ready || currentGatt == null || characteristic == null) {
            log("Command ignored: bridge is not ready.")
            return
        }

        val payload = (command.json() + "\n").toByteArray(StandardCharsets.UTF_8)

        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            currentGatt.writeCharacteristic(
                characteristic,
                payload,
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            )
        } else {
            @Suppress("DEPRECATION")
            characteristic.apply {
                writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                value = payload
            }.let {
                @Suppress("DEPRECATION")
                if (currentGatt.writeCharacteristic(characteristic)) {
                    BluetoothGatt.GATT_SUCCESS
                } else {
                    BluetoothGatt.GATT_FAILURE
                }
            }
        }

        if (result != BluetoothGatt.GATT_SUCCESS) {
            log("BLE command write failed: $result")
        }
    }

    private fun scan() {
        if (!started || scanning || gatt != null) return

        val currentAdapter = adapter
        if (currentAdapter == null || !currentAdapter.isEnabled) {
            log("Bluetooth is off or unavailable.")
            onReady(false)
            reconnectSoon()
            return
        }

        val scanner = currentAdapter.bluetoothLeScanner
        if (scanner == null) {
            log("BLE scanner unavailable.")
            reconnectSoon()
            return
        }

        scanning = true
        log("Searching for Z Live Remote Bridge...")

        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner.startScan(listOf(filter), settings, scanCallback)
    }

    private fun stopScan() {
        if (!scanning) return
        try {
            adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (_: Throwable) {
        }
        scanning = false
    }

    private fun reconnectSoon() {
        if (!started) return

        reconnectRunnable?.let(handler::removeCallbacks)
        val runnable = Runnable {
            reconnectRunnable = null
            if (started && gatt == null) scan()
        }
        reconnectRunnable = runnable
        handler.postDelayed(runnable, 1_000)
    }

    private fun resetGatt() {
        onReady(false)
        commandCharacteristic = null
        eventCharacteristic = null
        incoming = ByteArray(0)

        try {
            gatt?.disconnect()
        } catch (_: Throwable) {
        }
        try {
            gatt?.close()
        } catch (_: Throwable) {
        }
        gatt = null
    }

    private fun onReady(value: Boolean) {
        if (ready == value) return
        ready = value
        handler.post { onReadyChanged(value) }
    }

    private fun handleBytes(value: ByteArray) {
        if (value.isEmpty()) return

        incoming += value

        while (true) {
            val newline = incoming.indexOf(0x0A.toByte())
            if (newline < 0) break

            val packet = incoming.copyOfRange(0, newline)
            incoming = incoming.copyOfRange(newline + 1, incoming.size)

            if (packet.isEmpty()) continue

            val line = packet.toString(StandardCharsets.UTF_8)
            val event = BridgeEvent.fromJson(line)

            if (event != null) {
                handler.post { onEvent(event) }
            } else {
                log("Could not decode event: $line")
            }
        }
    }

    private fun subscribeToEvents(service: BluetoothGattService) {
        val currentGatt = gatt ?: return

        commandCharacteristic = service.getCharacteristic(COMMAND_UUID)
        eventCharacteristic = service.getCharacteristic(EVENT_UUID)

        val event = eventCharacteristic
        if (commandCharacteristic == null || event == null) {
            log("Bridge characteristics are incomplete.")
            resetGatt()
            reconnectSoon()
            return
        }

        if (!currentGatt.setCharacteristicNotification(event, true)) {
            log("Could not enable event notifications.")
            resetGatt()
            reconnectSoon()
            return
        }

        val descriptor = event.getDescriptor(CCCD_UUID)
        if (descriptor == null) {
            log("Notification descriptor is missing.")
            resetGatt()
            reconnectSoon()
            return
        }

        val enable = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE

        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            currentGatt.writeDescriptor(descriptor, enable)
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = enable
            @Suppress("DEPRECATION")
            if (currentGatt.writeDescriptor(descriptor)) {
                BluetoothGatt.GATT_SUCCESS
            } else {
                BluetoothGatt.GATT_FAILURE
            }
        }

        if (result != BluetoothGatt.GATT_SUCCESS) {
            log("Could not subscribe to Bridge events: $result")
            resetGatt()
            reconnectSoon()
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            if (gatt != null) return

            stopScan()
            log("Found Z Live Remote Bridge.")

            gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                result.device.connectGatt(
                    appContext,
                    false,
                    gattCallback,
                    BluetoothGatt.TRANSPORT_LE
                )
            } else {
                @Suppress("DEPRECATION")
                result.device.connectGatt(appContext, false, gattCallback)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            scanning = false
            log("BLE scan failed: $errorCode")
            reconnectSoon()
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(
            callbackGatt: BluetoothGatt,
            status: Int,
            newState: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS &&
                newState == BluetoothProfile.STATE_CONNECTED
            ) {
                log("Bluetooth connected. Discovering service...")
                callbackGatt.discoverServices()
                return
            }

            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                log("Bridge disconnected.")
                onReady(false)

                try {
                    callbackGatt.close()
                } catch (_: Throwable) {
                }

                if (gatt === callbackGatt) {
                    gatt = null
                    commandCharacteristic = null
                    eventCharacteristic = null
                    incoming = ByteArray(0)
                }

                reconnectSoon()
            }
        }

        override fun onServicesDiscovered(callbackGatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                log("Service discovery failed: $status")
                resetGatt()
                reconnectSoon()
                return
            }

            val service = callbackGatt.getService(SERVICE_UUID)
            if (service == null) {
                log("Z Live Remote BLE service was not found.")
                resetGatt()
                reconnectSoon()
                return
            }

            subscribeToEvents(service)
        }

        override fun onDescriptorWrite(
            callbackGatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            if (descriptor.uuid != CCCD_UUID) return

            if (status == BluetoothGatt.GATT_SUCCESS) {
                log("Z Live Remote Bridge ready.")
                onReady(true)
            } else {
                log("Notification subscription failed: $status")
                resetGatt()
                reconnectSoon()
            }
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(
            callbackGatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            if (characteristic.uuid == EVENT_UUID) {
                @Suppress("DEPRECATION")
                handleBytes(characteristic.value ?: ByteArray(0))
            }
        }

        override fun onCharacteristicChanged(
            callbackGatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            if (characteristic.uuid == EVENT_UUID) {
                handleBytes(value)
            }
        }
    }

    private fun log(message: String) {
        handler.post { onLog(message) }
    }
}
