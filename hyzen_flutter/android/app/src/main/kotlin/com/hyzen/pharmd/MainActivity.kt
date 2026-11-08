package com.hyzen.pharmd

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.ExifInterface
import java.io.File
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var externalFiles: HyzenExternalFiles? = null
    private var studioPdfEngine: StudioPdfEngine? = null
    private var documentScanner: HyzenDocumentScanner? = null
    private var sessionChannel: MethodChannel? = null
    private var cameraCapture: HyzenCameraCapture? = null
    private val pickCode = 8711
    private val saveCode = 8712
    private val imageCode = 8713
    private val studioPickCode = 8714
    private var exportPath: String? = null
    private var dataSelection=false
    private var pending: MethodChannel.Result? = null
    private var templateText: String? = null
    private val fileWorker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sessionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hyzen.pharmd/session")
        HyzenUpdater(this, flutterEngine.dartExecutor.binaryMessenger)
        externalFiles = HyzenExternalFiles(this, flutterEngine.dartExecutor.binaryMessenger)
        studioPdfEngine = StudioPdfEngine(this, flutterEngine)
        documentScanner = HyzenDocumentScanner(this, flutterEngine.dartExecutor.binaryMessenger)
        cameraCapture = HyzenCameraCapture(this, flutterEngine.dartExecutor.binaryMessenger)
        externalFiles?.receive(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hyzen.pharmd/csv_files")
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("busy", "Finish the current file selection first.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "pickCsvFiles", "pickDataFiles" -> {
                        dataSelection=call.method=="pickDataFiles"
                        pending = result
                        try {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/csv", "text/comma-separated-values", "application/csv", "application/vnd.ms-excel", "text/plain", "application/octet-stream", "application/json", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                            }
                            startActivityForResult(intent, pickCode)
                        } catch (e: Exception) { finishError("picker", "Could not open the file picker.") }
                    }
                    "saveCsvTemplate" -> {
                        pending = result
                        templateText = call.argument<String>("text")
                        try {
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "text/csv"
                                putExtra(Intent.EXTRA_TITLE, "hyzen_bulk_import_template.csv")
                            }, saveCode)
                        } catch (e: Exception) { finishError("save", "Could not choose a save location.") }
                    }
                    "pickImage" -> {
                        pending=result
                        try { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE);type="image/*"
                            putExtra(Intent.EXTRA_MIME_TYPES,arrayOf("image/jpeg","image/png","image/webp"))
                        },imageCode) } catch (e:Exception){finishError("picker","Could not open photos.")}
                    }
                    "pickStudioFiles" -> {
                        pending = result
                        try {
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                                    "application/pdf", "image/jpeg", "image/png", "image/webp", "text/plain", "text/markdown", "application/rtf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                                ))
                            }, studioPickCode)
                        } catch (e: Exception) { finishError("picker", "Could not open documents.") }
                    }
                    "saveFile", "exportFile" -> {
                        pending=result
                        templateText=call.argument<String>("text")
                        exportPath=call.argument<String>("path")
                        try {startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type=call.argument<String>("mime") ?: "text/plain"
                            putExtra(Intent.EXTRA_TITLE,call.argument<String>("name") ?: "hyzen_export.txt")
                        },saveCode)}catch(e:Exception){finishError("save","Could not save the file.")}
                    }
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "document"
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        if (path.isNullOrBlank() || !File(path).isFile) {
                            result.error("share", "This document is no longer available.", null)
                        } else {
                            fileWorker.execute {
                                var shared: File? = null
                                try {
                                    val folder = File(cacheDir, "hyzen_shares/${System.currentTimeMillis()}").apply { mkdirs() }
                                    val safeName = name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(120)
                                    val shareCopy = File(folder, safeName)
                                    shared = shareCopy
                                    File(path).inputStream().use { input ->
                                        shareCopy.outputStream().use { output -> input.copyTo(output) }
                                    }
                                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", shareCopy)
                                    val send = Intent(Intent.ACTION_SEND).apply {
                                        type = mime
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        putExtra(Intent.EXTRA_TITLE, name)
                                        clipData = android.content.ClipData.newRawUri(name, uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    runOnUiThread {
                                        try {
                                            startActivity(Intent.createChooser(send, "Share $name"))
                                            result.success(true)
                                        } catch (e: Exception) {
                                            shared?.delete()
                                            result.error("share", "No app can share this file.", null)
                                        }
                                    }
                                } catch (e: Exception) {
                                    shared?.delete()
                                    runOnUiThread { result.error("share", "Could not prepare this file to share.", null) }
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    private fun finishError(code: String, message: String) {
        val result = pending
        pending = null
        templateText = null
        exportPath = null
        result?.error(code, message, null)
    }
    private fun fileName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0) ?: "import.csv"
        }
        return uri.lastPathSegment ?: "import.csv"
    }
    @Deprecated("Activity result bridge retained for Flutter file picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (cameraCapture?.receive(requestCode, resultCode) == true) return
        if (documentScanner?.receive(requestCode, resultCode, data) == true) return
        if (requestCode != pickCode && requestCode != saveCode && requestCode != imageCode && requestCode != studioPickCode) return
        val result = pending ?: return
        if (resultCode != Activity.RESULT_OK) {
            pending = null
            templateText = null
        exportPath = null
            result.success(if (requestCode == pickCode || requestCode == studioPickCode) emptyList<Map<String, Any>>() else if(requestCode==imageCode)null else false)
            return
        }
        val text = templateText ?: ""
        val sourcePath=exportPath
        fileWorker.execute {
            try {
                val response: Any
                if (requestCode == saveCode) {
                    val uri = data?.data ?: throw IllegalStateException("No destination selected.")
                    val stream = contentResolver.openOutputStream(uri, "wt") ?: throw IllegalStateException("Could not open destination.")
                    stream.use { target ->
                        if(sourcePath!=null)File(sourcePath).inputStream().use{it.copyTo(target)}
                        else target.write(text.toByteArray(Charsets.UTF_8))
                    }
                    response = true
                } else if (requestCode == studioPickCode) {
                    val uris = mutableListOf<Uri>()
                    val clips = data?.clipData
                    if (clips != null) {
                        if (clips.itemCount > 20) throw IllegalStateException("Choose at most 20 files.")
                        for (i in 0 until clips.itemCount) uris.add(clips.getItemAt(i).uri)
                    } else data?.data?.let { uris.add(it) }
                    response = uris.map { uri ->
                        val name = fileName(uri)
                        val extension = name.substringAfterLast('.', "").lowercase()
                        if (extension !in setOf("pdf", "jpg", "jpeg", "png", "webp", "txt", "md", "rtf", "docx"))
                            throw IllegalStateException("Choose PDF, image or text files.")
                        val copy = File.createTempFile("studio_pick_", ".$extension", cacheDir)
                        try {
                            var size = 0L
                            (contentResolver.openInputStream(uri) ?: error("Could not read $name")).use { input ->
                                copy.outputStream().use { target ->
                                    val buffer = ByteArray(65536)
                                    var count = input.read(buffer)
                                    while (count != -1) {
                                        size += count
                                        if (size > 150L * 1024 * 1024) error("Files must be smaller than 150 MB.")
                                        target.write(buffer, 0, count)
                                        count = input.read(buffer)
                                    }
                                }
                            }
                            mapOf("name" to name, "path" to copy.absolutePath)
                        } catch (e: Exception) { copy.delete(); throw e }
                    }
                } else if(requestCode==imageCode){
                    val uri=data?.data ?: throw IllegalStateException("No image selected.")
                    val input=contentResolver.openInputStream(uri) ?: throw IllegalStateException("Could not read photo.")
                    val dataBytes=ByteArrayOutputStream()
                    input.use { val buffer=ByteArray(8192);var count=it.read(buffer)
                        while(count!=-1){if(dataBytes.size()+count>12*1024*1024)throw IllegalStateException("Choose a photo smaller than 12 MB.");dataBytes.write(buffer,0,count);count=it.read(buffer)}
                    }
                    val bytes=dataBytes.toByteArray()
                    if(bytes.size>12*1024*1024)throw IllegalStateException("Choose a photo smaller than 12 MB.")
                    val options=BitmapFactory.Options().apply{inJustDecodeBounds=true}
                    BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
                    if(options.outWidth<=0||options.outHeight<=0)throw IllegalStateException("Choose a JPEG, PNG or WebP photo.")
                    options.inSampleSize=1
                    while(maxOf(options.outWidth,options.outHeight)/options.inSampleSize>1600)options.inSampleSize*=2
                    options.inJustDecodeBounds=false
                    var bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.size,options) ?: throw IllegalStateException("Photo could not be decoded.")
                    val rotation=try { val exif=ExifInterface(bytes.inputStream()); when(exif.getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL)) {
                        ExifInterface.ORIENTATION_ROTATE_90->90f;ExifInterface.ORIENTATION_ROTATE_180->180f;ExifInterface.ORIENTATION_ROTATE_270->270f;else->0f
                    }}catch(e:Exception){0f}
                    if(rotation!=0f){val rotated=Bitmap.createBitmap(bitmap,0,0,bitmap.width,bitmap.height,Matrix().apply{postRotate(rotation)},true);if(rotated!==bitmap)bitmap.recycle();bitmap=rotated}
                    val output=ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.JPEG,88,output);bitmap.recycle()
                    response=mapOf("name" to "hyzen_photo.jpg","bytes" to output.toByteArray())
                } else {
                    val uris = mutableListOf<Uri>()
                    val clips = data?.clipData
                    if (clips != null) {
                        if (clips.itemCount > 20) throw IllegalStateException("Choose at most 20 CSV files.")
                        for (i in 0 until clips.itemCount) uris.add(clips.getItemAt(i).uri)
                    } else data?.data?.let { uris.add(it) }
                    response = uris.map { uri ->
                        val name = fileName(uri)
                        if (!dataSelection && !name.endsWith(".csv", ignoreCase = true)) throw IllegalStateException("Choose CSV files only.")
                        val stream = contentResolver.openInputStream(uri) ?: throw IllegalStateException("Could not read $name.")
                        val bytes = ByteArrayOutputStream()
                        stream.use {
                            val buffer = ByteArray(8192)
                            var count = it.read(buffer)
                            while (count != -1) {
                                if (bytes.size() + count > 4 * 1024 * 1024) throw IllegalStateException("Each CSV must be 4 MB or smaller.")
                                bytes.write(buffer, 0, count)
                                count = it.read(buffer)
                            }
                        }
                        mapOf("name" to name, "bytes" to bytes.toByteArray())
                    }
                }
                runOnUiThread {
                    if (pending === result) {
                        pending = null
                        templateText = null
        exportPath = null
                        result.success(response)
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    if (pending === result) finishError("file_io", e.message ?: "Could not process the selected file.")
                }
            }
        }
    }
    override fun onDestroy() {
        externalFiles?.close()
        studioPdfEngine?.close()
        documentScanner?.close()
        cameraCapture?.close()
        pending?.error("interrupted", "File selection was interrupted. Please retry.", null)
        pending = null
        fileWorker.shutdown()
        super.onDestroy()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_LAUNCHER)) {
            sessionChannel?.invokeMethod("launcherOpened", null)
        }
        externalFiles?.receive(intent)
    }
}
