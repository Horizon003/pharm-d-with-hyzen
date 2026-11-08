package com.hyzen.pharmd

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File
import java.util.concurrent.Executors

/** Durable, bounded page draft. Never depends on a live Dart MethodChannel.Result
 * while Android's camera owns the foreground (the OS may kill our process). */
class ScanDraftStore(private val context: Context) {
    companion object { val FULL = listOf(0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0) }
    private val prefs = context.getSharedPreferences("hyzen_scan_draft", Context.MODE_PRIVATE)
    val folder = File(context.filesDir, "scan_draft").apply { mkdirs() }
    fun pages(): List<String> {
        val raw = JSONArray(prefs.getString("pages", "[]"))
        return (0 until raw.length()).map { raw.getString(it) }.filter { valid(it) }
    }
    private fun valid(path: String): Boolean = File(path).let { it.canonicalFile.parentFile == folder.canonicalFile && it.isFile && it.length() > 0 }
    fun newCapture(): File {
        require(pages().size < 30) { "Save these 30 pages before scanning more." }
        val output = File.createTempFile("camera_", ".jpg", folder)
        check(prefs.edit().putString("cameraPath", output.path).putBoolean("recover", true).commit())
        return output
    }
    fun finishCapture(ok: Boolean): List<String> {
        val source = prefs.getString("cameraPath", null)?.let { File(it) }
        if (ok && source != null && valid(source.path)) {
            try { add(listOf(source.path)) } finally { source.delete() }
        } else source?.takeIf { it.canonicalFile.parentFile == folder.canonicalFile }?.delete()
        prefs.edit().remove("cameraPath").commit()
        return pages()
    }
    fun add(paths: List<String>): List<String> {
        val before = pages()
        require(before.size + paths.size <= 30) { "Choose up to 30 pages per PDF." }
        try {
            for (path in paths) {
                val file = File(path).canonicalFile
                require(file.path.startsWith(context.filesDir.canonicalPath + "/") || file.path.startsWith(context.cacheDir.canonicalPath + "/")) { "Choose a local image." }
                require(file.length() in 1..(40L * 1024 * 1024)) { "Choose an image under 40 MB." }
                addCaptured(file.path, null)
            }
            return pages()
        } catch (e: Throwable) { replace(before); throw e }
    }
    fun replace(paths: List<String>): List<String> {
        val current = pages()
        require(paths.size <= 30 && paths.distinct().size == paths.size && paths.all { it in current })
        save(paths)
        current.filter { it !in paths }.forEach { gone ->
            original(gone)?.delete(); prefs.edit().remove(metaKey(gone)).commit(); File(gone).delete()
        }
        return paths
    }
    fun rotate(path: String): List<String> {
        val current = pages(); require(path in current)
        if (original(path) != null) {
            val m = meta(path); m.put("rotation", (m.optInt("rotation", 0) + 90) % 360)
            m.optJSONArray("marks")?.let { marks ->
                for (i in 0 until marks.length()) {
                    val points = marks.getJSONObject(i).getJSONArray("points")
                    for (j in 0 until points.length()) {
                        val xy = points.getJSONArray(j)
                        points.put(j, JSONArray(listOf(1.0 - xy.getDouble(1), xy.getDouble(0))))
                    }
                }
            }
            val out = File.createTempFile("page_", ".jpg", folder)
            try { render(original(path)!!, m, out) } catch (e: Throwable) { out.delete(); throw e }
            check(prefs.edit().putString(metaKey(out.path), m.toString()).remove(metaKey(path))
                .putString("pages", JSONArray(current.map { if (it == path) out.path else it }).toString()).commit())
            File(path).delete()
            return pages()
        }
        val source = StudioImages.load(path, 1800)
        val turned = Bitmap.createBitmap(source, 0, 0, source.width, source.height, Matrix().apply { postRotate(90f) }, true)
        val output = File.createTempFile("page_", ".jpg", folder)
        try {
            output.outputStream().use { check(turned.compress(Bitmap.CompressFormat.JPEG, 88, it)) }
            save(current.map { if (it == path) output.path else it }); File(path).delete()
        } catch (e: Exception) { output.delete(); throw e }
        finally { if (turned !== source) turned.recycle(); source.recycle() }
        return pages()
    }
    private fun save(paths: List<String>) { check(prefs.edit().putString("pages", JSONArray(paths).toString()).commit()) }
    fun beginScan() { check(prefs.edit().putBoolean("recover", true).commit()) }
    /** Transactional edits touch only app-owned draft copies. Processing is
     * bounded to one page at a time and commits the new order only on success. */
    fun edit(paths: List<String>, filter: String, crop: List<Double>?): List<String> {
        val current = pages()
        require(paths.isNotEmpty() && paths.distinct().size == paths.size && paths.all { it in current })
        require(filter in setOf("original", "gray", "contrast", "bw"))
        val replacements = mutableMapOf<String, String>()
        val created = mutableListOf<File>()
        try {
            for (path in paths) {
                val source = StudioImages.load(path, 1800)
                var region = source
                var outputBitmap: Bitmap? = null
                try {
                    if (crop != null) {
                        require(crop.size == 4 && crop.all { it.isFinite() && it in 0.0..1.0 })
                        val left = (crop[0] * source.width).toInt().coerceIn(0, source.width - 1)
                        val top = (crop[1] * source.height).toInt().coerceIn(0, source.height - 1)
                        val right = (crop[2] * source.width).toInt().coerceIn(left + 1, source.width)
                        val bottom = (crop[3] * source.height).toInt().coerceIn(top + 1, source.height)
                        region = Bitmap.createBitmap(source, left, top, right-left, bottom-top)
                    }
                    val output = Bitmap.createBitmap(region.width, region.height, Bitmap.Config.ARGB_8888)
                    outputBitmap = output
                    val color = ColorMatrix()
                    if (filter == "gray" || filter == "bw") color.setSaturation(0f)
                    if (filter == "contrast" || filter == "bw") {
                        val factor = if (filter == "bw") 3.5f else 1.35f
                        val offset = 128f * (1f - factor)
                        color.postConcat(ColorMatrix(floatArrayOf(factor,0f,0f,0f,offset,0f,factor,0f,0f,offset,0f,0f,factor,0f,offset,0f,0f,0f,1f,0f)))
                    }
                    Canvas(output).drawBitmap(region, 0f, 0f, Paint(Paint.ANTI_ALIAS_FLAG).apply { colorFilter = ColorMatrixColorFilter(color) })
                    val file = File.createTempFile("edited_", ".jpg", folder); created.add(file)
                    file.outputStream().use { check(output.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
                    replacements[path] = file.path
                } finally { outputBitmap?.recycle(); if (region !== source) region.recycle(); source.recycle() }
            }
            val next = current.map { replacements[it] ?: it }
            save(next)
            paths.forEach { File(it).delete() }
            return next
        } catch (e: Throwable) { created.forEach { it.delete() }; throw e }
    }
    // ---- 1.5 precision scanner: originals + reversible crop/filter -------
    // Each page may have an untouched original in scan_draft/orig/ and a JSON
    // sidecar {quad, filter, brightness, contrast, rotation}. The page JPEG is
    // always re-rendered from the original, so edits never degrade quality and
    // can be reset at any time.
    private val origFolder = File(folder, "orig").apply { mkdirs() }
    private fun metaKey(page: String) = "meta_" + File(page).name
    fun meta(page: String): org.json.JSONObject =
        try { org.json.JSONObject(prefs.getString(metaKey(page), "{}")!!) } catch (_: Exception) { org.json.JSONObject() }
    private fun original(page: String): File? =
        meta(page).optString("orig").takeIf { it.isNotEmpty() }?.let { File(origFolder, it) }?.takeIf { it.isFile }

    /** Camera capture: keep the original, append a perspective-corrected page. */
    fun addCaptured(rawPath: String, @Suppress("UNUSED_PARAMETER") quad: List<Double>?): List<String> {
        val current = pages().toMutableList()
        require(current.size < 30) { "Save these 30 pages before scanning more." }
        val orig = File.createTempFile("orig_", ".jpg", origFolder)
        try {
            val upright = StudioImages.load(rawPath, 2600)
            try { orig.outputStream().use { check(upright.compress(Bitmap.CompressFormat.JPEG, 92, it)) } } finally { upright.recycle() }
            // Refine the live-preview quad on the full photo for accuracy.
            val refined = try { ScanBitmaps.detect(orig.path) } catch (_: Throwable) { null }
            // Still-photo coordinates are authoritative. Preview buffers may
            // have a different sensor crop; never apply their quad to the JPEG.
            val q = refined?.takeIf { ScanVision.validQuad(it) } ?: FULL
            val page = File.createTempFile("page_", ".jpg", folder)
            val m = org.json.JSONObject().put("orig", orig.name).put("quad", org.json.JSONArray(q))
                .put("filter", "magic").put("brightness", 0).put("contrast", 0).put("rotation", 0)
            render(orig, m, page)
            prefs.edit().putString(metaKey(page.path), m.toString()).commit()
            current.add(page.path); save(current)
            return current
        } catch (e: Throwable) { orig.delete(); throw e }
    }

    fun preview(path: String, filter: String, brightness: Int = 0, contrast: Int = 0): ByteArray {
        require(path in pages()) { "Choose a draft page." }
        require(filter in listOf("original", "magic", "gray", "bw"))
        val metadata = meta(path)
            .put("filter", filter)
            .put("brightness", brightness.coerceIn(-100, 100))
            .put("contrast", contrast.coerceIn(-100, 100))
        val out = File.createTempFile("preview_", ".jpg", context.cacheDir)
        try {
            render(original(path) ?: File(path), metadata, out, 900)
            return out.readBytes()
        } finally { out.delete() }
    }

    private fun render(orig: File, m: org.json.JSONObject, out: File, maxSize: Int = 2600) {
        var b = StudioImages.load(orig.path, maxSize)
        try {
            val qa = m.optJSONArray("quad")
            val q = if (qa != null && qa.length() == 8) (0 until 8).map { qa.getDouble(it) } else FULL
            require(ScanVision.validQuad(q)) { "Invalid crop corners" }
            val warped = ScanBitmaps.warp(b, q, minOf(2000, maxSize)); b.recycle(); b = warped
            val rot = m.optInt("rotation", 0)
            if (rot % 360 != 0) {
                val r = Bitmap.createBitmap(b, 0, 0, b.width, b.height, Matrix().apply { postRotate(rot.toFloat()) }, true)
                if (r !== b) { b.recycle(); b = r }
            }
            val f = ScanBitmaps.enhance(b, m.optString("filter", "original"), m.optInt("brightness", 0), m.optInt("contrast", 0))
            b.recycle(); b = f
            val marks = m.optJSONArray("marks")
            if (marks != null) {
                val mutable = b.copy(Bitmap.Config.ARGB_8888, true)
                b.recycle(); b = mutable
                val canvas = Canvas(b)
                for (i in 0 until marks.length()) {
                    val mark = marks.getJSONObject(i)
                    val points = mark.getJSONArray("points")
                    val path = android.graphics.Path()
                    for (j in 0 until points.length()) {
                        val point = points.getJSONArray(j)
                        val x = point.getDouble(0).toFloat() * b.width
                        val y = point.getDouble(1).toFloat() * b.height
                        if (j == 0) path.moveTo(x, y) else path.lineTo(x, y)
                    }
                    val high = mark.optBoolean("highlight")
                    canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = if (high) 0x66FFC107 else 0xFF182A61.toInt()
                        strokeWidth = b.width * if (high) .035f else .005f
                        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
                    })
                }
            }
            out.outputStream().use { check(b.compress(Bitmap.CompressFormat.JPEG, 90, it)) }
        } finally { b.recycle() }
    }

    /** Re-render pages from originals with new crop / filter. Returns new list. */
    fun adjust(paths: List<String>, quad: List<Double>?, filter: String?, brightness: Int?, contrast: Int?, marks: List<Map<String, Any?>>? = null): List<String> {
        val current = pages()
        require(paths.isNotEmpty() && paths.all { it in current })
        require(filter == null || filter in setOf("original", "magic", "gray", "bw", "contrast"))
        require(quad == null || ScanVision.validQuad(quad)) { "Invalid crop corners" }
        val replacements = mutableMapOf<String, String>(); val metas = mutableMapOf<String, String>()
        val created = mutableListOf<File>()
        try {
            for (path in paths) {
                var orig = original(path)
                val m = meta(path)
                if (orig == null) {
                    // Legacy/gallery page without original: adopt current image as original.
                    orig = File.createTempFile("orig_", ".jpg", origFolder); created.add(orig)
                    File(path).copyTo(orig, overwrite = true)
                    m.put("orig", orig.name).put("quad", org.json.JSONArray(FULL)).put("rotation", 0)
                }
                if (marks != null) {
                    val existing = m.optJSONArray("marks") ?: JSONArray()
                    require(existing.length() + marks.size <= 500)
                    for (mark in marks) {
                        val points = mark["points"] as? List<*> ?: error("Missing points")
                        require(points.size in 1..20000)
                        for (point in points) {
                            val xy = point as? List<*> ?: error("Invalid point")
                            require(xy.size == 2 && xy.all { it is Number && it.toDouble().isFinite() && it.toDouble() in 0.0..1.0 })
                        }
                        existing.put(org.json.JSONObject(mark))
                    }
                    m.put("marks", existing)
                }
                if (quad != null) m.put("quad", org.json.JSONArray(quad))
                if (filter != null) m.put("filter", if (filter == "contrast") "magic" else filter)
                if (brightness != null) m.put("brightness", brightness.coerceIn(-100, 100))
                if (contrast != null) m.put("contrast", contrast.coerceIn(-100, 100))
                val out = File.createTempFile("page_", ".jpg", folder); created.add(out)
                render(orig, m, out)
                replacements[path] = out.path; metas[out.path] = m.toString()
            }
            val next = current.map { replacements[it] ?: it }
            val e = prefs.edit()
            metas.forEach { (k, v) -> e.putString(metaKey(k), v) }
            replacements.keys.forEach { e.remove(metaKey(it)) }
            e.putString("pages", JSONArray(next).toString())
            check(e.commit())
            replacements.keys.forEach { File(it).delete() }
            return next
        } catch (t: Throwable) {
            created.forEach { it.delete() }
            throw t
        }
    }

    /** Info for the crop editor: original image path + current quad/filter. */
    fun pageInfo(path: String): Map<String, Any?> {
        require(path in pages())
        val m = meta(path)
        val qa = m.optJSONArray("quad")
        return mapOf(
            "original" to (original(path)?.path ?: path),
            "quad" to (if (qa != null && qa.length() == 8) (0 until 8).map { qa.getDouble(it) } else FULL),
            "filter" to m.optString("filter", "original"),
            "brightness" to m.optInt("brightness", 0),
            "contrast" to m.optInt("contrast", 0),
            "hasOriginal" to (original(path) != null),
        )
    }

    fun detectIn(path: String): List<Double>? = ScanBitmaps.detect(path)

    fun needsRecovery(): Boolean = prefs.getBoolean("recover", false)
    fun acknowledge() { prefs.edit().putBoolean("recover", false).commit() }
    fun recover(): List<String> {
        if (prefs.contains("cameraPath")) finishCapture(true)
        return pages()
    }
    fun clear() {
        pages().forEach { File(it).delete() }
        origFolder.listFiles()?.forEach { it.delete() }
        prefs.getString("cameraPath", null)?.let { File(it).takeIf { f -> f.parentFile == folder }?.delete() }
        prefs.edit().clear().commit()
    }
}

/** Uses the installed camera app, without an app camera permission or a heavy
 * Play-services scanning Activity. Each confirmed capture appends one page. */
class HyzenCameraCapture(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val store = ScanDraftStore(activity)
    private val worker = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, "com.hyzen.pharmd/camera_pages")
    private var pending: MethodChannel.Result? = null
    private var busy = false
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "capture") {
                if (pending != null || busy) { result.error("busy", "Finish this page first.", null); return@setMethodCallHandler }
                try {
                    val file = store.newCapture()
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                        putExtra(MediaStore.EXTRA_OUTPUT, uri)
                        clipData = ClipData.newRawUri("Scan page", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    }
                    pending = result
                    activity.startActivityForResult(intent, REQUEST)
                } catch (_: Exception) {
                    store.finishCapture(false); store.acknowledge(); pending = null
                    result.error("camera", "Camera unavailable. Choose gallery images instead.", null)
                }
                return@setMethodCallHandler
            }
            if (busy) { result.error("busy", "Preparing your page…", null); return@setMethodCallHandler }
            busy = true
            worker.execute {
                try {
                    val answer: Any? = when (call.method) {
                        "needsRecovery" -> store.needsRecovery() && pending == null
                        "recover" -> store.recover().also { store.acknowledge() }
                        "addImages" -> store.add(call.argument<List<String>>("paths") ?: emptyList())
                        "replace" -> store.replace(call.argument<List<String>>("paths") ?: emptyList())
                        "rotate" -> store.rotate(call.argument<String>("path") ?: "")
                        "adjust" -> store.adjust(
                            call.argument<List<String>>("paths") ?: emptyList(),
                            call.argument<List<Double>>("quad"),
                            call.argument<String>("filter"),
                            call.argument<Int>("brightness"),
                            call.argument<Int>("contrast"),
                        )
                        "annotate" -> store.adjust(listOf(call.argument<String>("path") ?: ""), null, null, null, null, call.argument<List<Map<String, Any?>>>("marks") ?: emptyList())
                        "preview" -> store.preview(
                            call.argument<String>("path") ?: "",
                            call.argument<String>("filter") ?: "original",
                            call.argument<Int>("brightness") ?: 0,
                            call.argument<Int>("contrast") ?: 0,
                        )
                        "pageInfo" -> store.pageInfo(call.argument<String>("path") ?: "")
                        "detect" -> store.detectIn(call.argument<String>("path") ?: "")
                        "edit" -> store.edit(call.argument<List<String>>("paths") ?: emptyList(), call.argument<String>("filter") ?: "original", call.argument<List<Double>>("crop"))
                        "clear" -> { store.clear(); true }
                        else -> { activity.runOnUiThread { busy = false; result.notImplemented() }; return@execute }
                    }
                    activity.runOnUiThread { busy = false; result.success(answer) }
                } catch (e: Throwable) {
                    activity.runOnUiThread { busy = false; result.error("scan_page", "Could not prepare this page. Try a smaller image.", null) }
                }
            }
        }
    }
    fun receive(code: Int, resultCode: Int): Boolean {
        if (code != REQUEST) return false
        val result = pending; pending = null; busy = true
        worker.execute {
            try {
                val pages = store.finishCapture(resultCode == Activity.RESULT_OK)
                if (result != null) store.acknowledge()
                activity.runOnUiThread { busy = false; result?.success(pages); channel.invokeMethod("draftReady", null) }
            } catch (_: Throwable) {
                activity.runOnUiThread { busy = false; result?.error("capture", "Could not add this page. Your earlier pages are safe.", null) }
            }
        }
        return true
    }
    fun close() { pending = null; worker.shutdown() }
    companion object { const val REQUEST = 8892 }
}
