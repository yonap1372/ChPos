package com.example.chilascas_pos

import android.content.Context
import android.content.SharedPreferences
import android.hardware.usb.*
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "chilascas/usb_printer"
    private val VENDOR_ID = 0x0483
    private val PRODUCT_ID = 0x070B
    private lateinit var prefs: SharedPreferences

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = getSharedPreferences("chilascas_prefs", Context.MODE_PRIVATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "printTicket" -> {
                        val data = call.argument<String>("data") ?: ""
                        val tipo = call.argument<String>("tipo") ?: "cliente"
                        val success = printToUsbPrinter(data, tipo)
                        if (success) result.success("printed_$tipo")
                        else result.error("PRINT_ERROR", "No se pudo imprimir en $tipo", null)
                    }

                    "openDrawer" -> {
                        val opened = sendOpenDrawerCommand()
                        if (opened) result.success("drawer_ok")
                        else result.error("DRAWER_ERROR", "No se pudo abrir la caja", null)
                    }

                    "listarImpresoras" -> {
                        val list = listarImpresoras()
                        result.success(list)
                    }

                    "guardarAsignacion" -> {
                        val tipo = call.argument<String>("tipo") ?: return@setMethodCallHandler
                        val serial = call.argument<String>("serial") ?: return@setMethodCallHandler
                        prefs.edit().putString("printer_$tipo", serial).apply()
                        result.success("ok")
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun listarImpresoras(): List<Map<String, String>> {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val list = mutableListOf<Map<String, String>>()

        usbManager.deviceList.values.forEach { device ->
            if (device.vendorId == VENDOR_ID && device.productId == PRODUCT_ID) {
                list.add(
                    mapOf(
                        "name" to device.deviceName,
                        "serial" to (device.serialNumber ?: "sin_serial")
                    )
                )
            }
        }
        return list
    }

    private fun printToUsbPrinter(data: String, tipo: String): Boolean {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val savedSerial = prefs.getString("printer_$tipo", null)

        val device = usbManager.deviceList.values.firstOrNull {
            it.vendorId == VENDOR_ID && it.productId == PRODUCT_ID &&
                    (savedSerial == null || it.serialNumber == savedSerial)
        }

        if (device == null) {
            Log.e("USB_PRINTER", "❌ No se encontró la impresora '$tipo'.")
            return false
        }

        val usbInterface = device.getInterface(0)
        val endpoint = (0 until usbInterface.endpointCount)
            .map { usbInterface.getEndpoint(it) }
            .firstOrNull {
                it.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        it.direction == UsbConstants.USB_DIR_OUT
            } ?: usbInterface.getEndpoint(0)

        val connection = usbManager.openDevice(device)
        if (connection == null) {
            Log.e("USB_PRINTER", "❌ No se pudo abrir conexión con la impresora $tipo.")
            return false
        }

        return try {
            if (connection.claimInterface(usbInterface, true)) {
                val bytes = data.toByteArray(Charsets.UTF_8)
                val resultCode = connection.bulkTransfer(endpoint, bytes, bytes.size, 3000)
                connection.releaseInterface(usbInterface)
                connection.close()

                if (resultCode != null && resultCode > 0) {
                    Log.i("USB_PRINTER", "✅ Impresión exitosa en $tipo (${bytes.size} bytes)")
                    true
                } else {
                    Log.e("USB_PRINTER", "⚠️ Falló la impresión en $tipo (Código: $resultCode)")
                    false
                }
            } else {
                Log.e("USB_PRINTER", "❌ No se pudo reclamar la interfaz USB ($tipo).")
                false
            }
        } catch (e: Exception) {
            Log.e("USB_PRINTER", "⚠️ Error en impresión $tipo: ${e.message}")
            false
        } finally {
            try {
                connection.close()
            } catch (_: Exception) {}
        }
    }

    private fun sendOpenDrawerCommand(): Boolean {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val serialCliente = prefs.getString("printer_cliente", null)

        val device = usbManager.deviceList.values.firstOrNull {
            it.vendorId == VENDOR_ID && it.productId == PRODUCT_ID &&
                    (serialCliente == null || it.serialNumber == serialCliente)
        }

        if (device == null) {
            Log.e("USB_DRAWER", "❌ No se encontró la impresora cliente para abrir caja.")
            return false
        }

        val usbInterface = device.getInterface(0)
        val endpoint = (0 until usbInterface.endpointCount)
            .map { usbInterface.getEndpoint(it) }
            .firstOrNull {
                it.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        it.direction == UsbConstants.USB_DIR_OUT
            } ?: usbInterface.getEndpoint(0)

        val connection = usbManager.openDevice(device)
        if (connection == null) {
            Log.e("USB_DRAWER", "❌ No se pudo abrir conexión USB para abrir la caja.")
            return false
        }

        return try {
            if (connection.claimInterface(usbInterface, true)) {
                val openDrawer = byteArrayOf(0x1B, 0x70, 0x00, 0x19, 0xFA.toByte())
                val resultCode = connection.bulkTransfer(endpoint, openDrawer, openDrawer.size, 1000)
                connection.releaseInterface(usbInterface)
                connection.close()

                if (resultCode != null && resultCode > 0) {
                    Log.i("USB_DRAWER", "✅ Cajón abierto correctamente.")
                    true
                } else {
                    Log.e("USB_DRAWER", "⚠️ Falló comando de apertura (Código: $resultCode)")
                    false
                }
            } else {
                Log.e("USB_DRAWER", "❌ No se pudo reclamar la interfaz USB (abrir caja).")
                false
            }
        } catch (e: Exception) {
            Log.e("USB_DRAWER", "⚠️ Error al abrir la caja: ${e.message}")
            false
        } finally {
            try {
                connection.close()
            } catch (_: Exception) {}
        }
    }
}
