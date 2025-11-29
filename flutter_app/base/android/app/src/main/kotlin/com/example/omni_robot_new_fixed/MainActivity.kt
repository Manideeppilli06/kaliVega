package com.example.omni_robot_new

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "bluetooth_classic"
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothSocket: BluetoothSocket? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when(call.method) {
                "getPairedDevices" -> {
                    val pairedDevices = mutableListOf<Map<String, String>>()
                    bluetoothAdapter?.bondedDevices?.forEach { device ->
                        pairedDevices.add(mapOf("name" to device.name, "address" to device.address))
                    }
                    result.success(pairedDevices)
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    val device = bluetoothAdapter?.getRemoteDevice(address)
                    try {
                        val uuid = device?.uuids?.get(0)?.uuid ?: UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                        bluetoothSocket = device?.createRfcommSocketToServiceRecord(uuid)
                        bluetoothSocket?.connect()
                        result.success(true)
                    } catch (e: IOException) {
                        Log.e("Bluetooth", "Connection failed", e)
                        result.success(false)
                    }
                }
                "sendData" -> {
                    val data = call.argument<String>("data")
                    try {
                        bluetoothSocket?.outputStream?.write(data?.toByteArray())
                        result.success(true)
                    } catch (e: IOException) {
                        Log.e("Bluetooth", "Send failed", e)
                        result.success(false)
                    }
                }
                "disconnect" -> {
                    try {
                        bluetoothSocket?.close()
                        result.success(true)
                    } catch (e: IOException) {
                        Log.e("Bluetooth", "Disconnect failed", e)
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
