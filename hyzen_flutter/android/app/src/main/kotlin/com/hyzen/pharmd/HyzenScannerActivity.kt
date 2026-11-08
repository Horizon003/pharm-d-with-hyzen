package com.hyzen.pharmd

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.ExifInterface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.Camera
import androidx.camera.core.AspectRatio
import androidx.camera.core.FocusMeteringAction
import androidx.camera.view.transform.ImageProxyTransformFactory
import androidx.camera.view.transform.CoordinateTransform
import androidx.camera.view.transform.OutputTransform
import android.view.MotionEvent
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

/**
 * Hyzen precision scanner (Q11): live CameraX preview, on-device quadrilateral
 * detection (ScanVision), damped 4-corner overlay, Auto/Manual shutter, flash,
 * page count and a horizontal strip of captured pages. Each capture is
 * perspective-corrected and appended to the durable ScanDraftStore, so pages
 * survive process death. The original photo is kept for later re-cropping.
 */
class HyzenScannerActivity : ComponentActivity() {
    private lateinit var preview: PreviewView
    private lateinit var overlay: QuadOverlay
    private lateinit var status: TextView
    private lateinit var counter: TextView
    private lateinit var autoBtn: TextView
    private lateinit var flashBtn: TextView
    private lateinit var shutter: View
    private lateinit var strip: LinearLayout
    private lateinit var done: TextView
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val saveExecutor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var capture: ImageCapture? = null
    private var camera: Camera? = null
    private var auto = true
    private var flash = false
    @Volatile private var busy = false
    private var awaitingNextPage = false
    private var capturedQuad: DoubleArray? = null
    private var missingFrames = 0
    private var stableSince = 0L
    private var lastQuad: DoubleArray? = null
    private var lastDetectAt = 0L
    private var analysing = false
    private lateinit var store: ScanDraftStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        store = ScanDraftStore(this)
        auto = getSharedPreferences("hyzen_scanner", Context.MODE_PRIVATE).getBoolean("auto", true)
        buildUi()
        refreshStrip()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) startCamera()
        else requestPermissions(arrayOf(Manifest.permission.CAMERA), 41)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 41 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) startCamera()
        else { setResult(RESULT_DENIED); finish() }
    }

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)
    private fun pill(text: String, bg: Int, fg: Int = Color.WHITE) = TextView(this).apply {
        this.text = text; setTextColor(fg); textSize = 13f; typeface = Typeface.DEFAULT_BOLD
        gravity = Gravity.CENTER
        setPadding(dp(14f).toInt(), dp(8f).toInt(), dp(14f).toInt(), dp(8f).toInt())
        background = GradientDrawable().apply { cornerRadius = dp(20f); setColor(bg) }
    }

    @SuppressLint("SetTextI18n")
    private fun buildUi() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        preview = PreviewView(this).apply {
            scaleType = PreviewView.ScaleType.FIT_CENTER
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
        preview.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP) {
                camera?.cameraControl?.startFocusAndMetering(
                    FocusMeteringAction.Builder(preview.meteringPointFactory.createPoint(event.x, event.y)).build()
                )
                preview.performClick()
            }
            true
        }
        root.addView(preview, FrameLayout.LayoutParams(-1, -1))
        overlay = QuadOverlay(this)
        root.addView(overlay, FrameLayout.LayoutParams(-1, -1))

        // Top bar
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14f).toInt(), dp(36f).toInt(), dp(14f).toInt(), dp(10f).toInt())
            setBackgroundColor(0x66000000)
        }
        val close = pill("✕", 0x33FFFFFF).apply { setOnClickListener { finishWithPages() }; contentDescription = "Close scanner" }
        flashBtn = pill("Flash off", 0x33FFFFFF).apply { setOnClickListener { toggleFlash() } }
        autoBtn = pill(if (auto) "Auto" else "Manual", if (auto) TEAL else 0x33FFFFFF).apply { setOnClickListener { toggleAuto() } }
        top.addView(close)
        top.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        top.addView(flashBtn)
        top.addView(View(this), LinearLayout.LayoutParams(dp(8f).toInt(), 1))
        top.addView(autoBtn)
        root.addView(top, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))

        status = pill("Point at a document", 0x99000000.toInt()).apply { textSize = 13f }
        root.addView(status, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER_HORIZONTAL or Gravity.TOP).apply { topMargin = dp(100f).toInt() })

        // Bottom panel
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xCC0B171C.toInt())
            setPadding(0, dp(10f).toInt(), 0, dp(22f).toInt())
        }
        val scroll = HorizontalScrollView(this).apply { isHorizontalScrollBarEnabled = false }
        strip = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(dp(12f).toInt(), 0, dp(12f).toInt(), 0) }
        scroll.addView(strip)
        bottom.addView(scroll, LinearLayout.LayoutParams(-1, dp(64f).toInt()))
        val controls = FrameLayout(this)
        counter = pill("0 pages", 0x33FFFFFF)
        controls.addView(counter, FrameLayout.LayoutParams(-2, -2, Gravity.START or Gravity.CENTER_VERTICAL).apply { leftMargin = dp(18f).toInt() })
        shutter = View(this).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.WHITE); setStroke(dp(5f).toInt(), TEAL) }
            contentDescription = "Capture page"
            setOnClickListener { takePicture(manual = true) }
        }
        controls.addView(shutter, FrameLayout.LayoutParams(dp(74f).toInt(), dp(74f).toInt(), Gravity.CENTER))
        done = pill("Next", TEAL).apply { setOnClickListener { finishWithPages() } }
        controls.addView(done, FrameLayout.LayoutParams(-2, -2, Gravity.END or Gravity.CENTER_VERTICAL).apply { rightMargin = dp(18f).toInt() })
        bottom.addView(controls, LinearLayout.LayoutParams(-1, dp(92f).toInt()).apply { topMargin = dp(6f).toInt() })
        root.addView(bottom, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
        setContentView(root)
    }

    private fun toggleAuto() {
        auto = !auto
        getSharedPreferences("hyzen_scanner", Context.MODE_PRIVATE).edit().putBoolean("auto", auto).apply()
        autoBtn.text = if (auto) "Auto" else "Manual"
        (autoBtn.background as GradientDrawable).setColor(if (auto) TEAL else 0x33FFFFFF)
        stableSince = 0
    }

    private fun toggleFlash() {
        flash = !flash
        camera?.cameraControl?.enableTorch(flash)
        flashBtn.text = if (flash) "Flash on" else "Flash off"
        (flashBtn.background as GradientDrawable).setColor(if (flash) 0xFFE0A526.toInt() else 0x33FFFFFF)
    }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                val provider = future.get()
                val previewUse = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).build().also { it.surfaceProvider = preview.surfaceProvider }
                capture = ImageCapture.Builder()
                    .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .setJpegQuality(92)
                    .build()
                val analysis = ImageAnalysis.Builder()
                    .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                analysis.setAnalyzer(analysisExecutor) { analyse(it) }
                provider.unbindAll()
                camera = provider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, previewUse, capture, analysis)
            } catch (_: Exception) {
                status.text = "Camera unavailable"
                setResult(RESULT_UNAVAILABLE); main.postDelayed({ finish() }, 900)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun analyse(image: ImageProxy) {
        try {
            val now = System.currentTimeMillis()
            if (busy || analysing || now - lastDetectAt < 110) return
            analysing = true; lastDetectAt = now
            val plane = image.planes[0]
            val buf = plane.buffer
            val bytes = ByteArray(buf.remaining()); buf.get(bytes)
            val rot = image.imageInfo.rotationDegrees
            val gray = ScanVision.grayFromLuma(bytes, image.width, image.height, plane.rowStride, plane.pixelStride, rot, 640)
            val q = ScanVision.detect(gray, refine = false, fast = true)
            val uprightW = if (rot % 180 == 0) image.width else image.height
            val uprightH = if (rot % 180 == 0) image.height else image.width
            val transform = ImageProxyTransformFactory().apply {
                isUsingRotationDegrees = true
            }.getOutputTransform(image)
            main.post { onDetection(q?.pts, uprightW, uprightH, transform) }
        } catch (_: Throwable) {
        } finally { analysing = false; image.close() }
    }

    @SuppressLint("SetTextI18n")
    private fun onDetection(q: DoubleArray?, w: Int, h: Int, transform: OutputTransform) {
        if (isFinishing || busy) return
        overlay.setFrame(preview.width, preview.height)
        val now = System.currentTimeMillis()
        if (q == null) {
            missingFrames++
            if (missingFrames < 3) return
            awaitingNextPage = false
            overlay.setQuad(null, false); lastQuad = null; stableSince = 0
            status.text = "Looking for document edges…"
            return
        }
        missingFrames = 0
        if (awaitingNextPage) {
            if (capturedQuad?.let { ScanVision.cornerDistance(it, q) > .07 } == true) {
                awaitingNextPage = false; stableSince = now
            } else {
                status.text = "Page added · turn the page or tap shutter"
                return
            }
        }
        val prev = lastQuad
        val moved = prev == null || ScanVision.cornerDistance(prev, q) > 0.025
        if (moved) stableSince = now
        lastQuad = q
        val stable = now - stableSince
        val ready = auto && stable > 900
        val target = preview.outputTransform
        if (target != null && preview.width > 0 && preview.height > 0) {
            val points = FloatArray(8) { (q[it] * if (it % 2 == 0) w else h).toFloat() }
            CoordinateTransform(transform, target).mapPoints(points)
            val display = DoubleArray(8) { points[it].toDouble() / if (it % 2 == 0) preview.width else preview.height }
            overlay.setQuad(display, !moved && stable > 400)
        }
        status.text = when {
            !auto -> "Document found · tap shutter"
            ready -> "Capturing…"
            stable > 400 -> "Hold still…"
            else -> "Document found"
        }
        if (ready) takePicture(manual = false)
    }

    private fun takePicture(@Suppress("UNUSED_PARAMETER") manual: Boolean) {
        val cap = capture ?: return
        if (busy) return
        if (store.pages().size >= 30) { status.text = "30 page limit · tap Next"; return }
        busy = true
        val quad = lastQuad?.copyOf()
        shutter.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
        overlay.flash()
        status.text = "Saving page…"
        val raw = File.createTempFile("capture_", ".jpg", cacheDir)
        cap.takePicture(ImageCapture.OutputFileOptions.Builder(raw).build(), saveExecutor, object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                try {
                    store.addCaptured(raw.path, quad?.toList())
                    main.post { busy = false; capturedQuad = quad; awaitingNextPage = auto; stableSince = System.currentTimeMillis(); refreshStrip(); status.text = "Page added · next page" }
                } catch (_: Throwable) {
                    main.post { busy = false; status.text = "Could not save page – try again" }
                } finally { raw.delete() }
            }
            override fun onError(exception: ImageCaptureException) {
                raw.delete()
                main.post { busy = false; status.text = "Capture failed – try again" }
            }
        })
    }

    @SuppressLint("SetTextI18n")
    private fun refreshStrip() {
        val pages = store.pages()
        counter.text = "${pages.size} page${if (pages.size == 1) "" else "s"}"
        done.alpha = if (pages.isEmpty()) .6f else 1f
        done.isEnabled = pages.isNotEmpty() && !busy
        strip.removeAllViews()
        saveExecutor.execute {
            val thumbs = pages.takeLast(12).map { path ->
                try {
                    val o = BitmapFactory.Options().apply { inSampleSize = 8 }
                    BitmapFactory.decodeFile(path, o)
                } catch (_: Throwable) { null }
            }
            main.post {
                strip.removeAllViews()
                for (b in thumbs) {
                    val iv = ImageView(this).apply {
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        setImageBitmap(b)
                        background = GradientDrawable().apply { cornerRadius = dp(6f); setStroke(dp(2f).toInt(), Color.WHITE) }
                        clipToOutline = true
                    }
                    strip.addView(iv, LinearLayout.LayoutParams(dp(44f).toInt(), dp(58f).toInt()).apply { rightMargin = dp(8f).toInt() })
                }
            }
        }
    }

    private fun finishWithPages() {
        if (busy) { status.text = "Finishing this page…"; return }
        setResult(Activity.RESULT_OK)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        analysisExecutor.shutdown()
        saveExecutor.shutdown()
    }

    /** Draws the damped document outline over the FIT_CENTER preview. */
    class QuadOverlay(ctx: Context) : View(ctx) {
        private var frameW = 0; private var frameH = 0
        private var target: DoubleArray? = null
        private var shown: DoubleArray? = null
        private var locked = false
        private var flashAlpha = 0
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeJoin = Paint.Join.ROUND }
        private val dot = Paint(Paint.ANTI_ALIAS_FLAG)
        fun setFrame(w: Int, h: Int) { frameW = w; frameH = h }
        fun setQuad(q: DoubleArray?, lock: Boolean) {
            target = q; locked = lock
            if (q == null) shown = null else if (shown == null) shown = q.copyOf()
            postInvalidateOnAnimation()
        }
        fun flash() { flashAlpha = 170; postInvalidateOnAnimation() }
        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (flashAlpha > 0) { canvas.drawColor(Color.argb(flashAlpha, 255, 255, 255)); flashAlpha = max(0, flashAlpha - 28); postInvalidateOnAnimation() }
            val t = target ?: return
            val s = shown ?: return
            var animating = false
            for (i in 0..7) { val d = t[i] - s[i]; if (kotlin.math.abs(d) > 0.0008) animating = true; s[i] += d * 0.45 }
            if (frameW == 0 || frameH == 0) return
            val scale = min(width / frameW.toFloat(), height / frameH.toFloat())
            val ox = (width - frameW * scale) / 2f; val oy = (height - frameH * scale) / 2f
            val p = Path()
            for (i in 0..3) {
                val x = ox + (s[i * 2] * frameW * scale).toFloat(); val y = oy + (s[i * 2 + 1] * frameH * scale).toFloat()
                if (i == 0) p.moveTo(x, y) else p.lineTo(x, y)
            }
            p.close()
            val color = if (locked) TEAL_LIGHT else Color.WHITE
            fill.color = Color.argb(if (locked) 70 else 40, Color.red(TEAL), Color.green(TEAL), Color.blue(TEAL))
            canvas.drawPath(p, fill)
            stroke.color = color; stroke.strokeWidth = resources.displayMetrics.density * 3
            canvas.drawPath(p, stroke)
            dot.color = color
            for (i in 0..3) {
                val x = ox + (s[i * 2] * frameW * scale).toFloat(); val y = oy + (s[i * 2 + 1] * frameH * scale).toFloat()
                canvas.drawCircle(x, y, resources.displayMetrics.density * 7, dot)
            }
            if (animating) postInvalidateOnAnimation()
        }
    }

    companion object {
        const val RESULT_DENIED = 2
        const val RESULT_UNAVAILABLE = 3
        val TEAL = 0xFF087F76.toInt()
        val TEAL_LIGHT = 0xFF5FD1C1.toInt()
    }
}

/** Bitmap helpers for perspective correction and filters (Android side). */
object ScanBitmaps {
    fun loadUpright(path: String, maxSide: Int): Bitmap = StudioImages.load(path, maxSide)

    fun warp(src: Bitmap, quad: List<Double>, maxSide: Int): Bitmap {
        if (ScanVision.isFullFrame(quad)) return src.copy(Bitmap.Config.ARGB_8888, false)
        val w = src.width; val h = src.height
        val px = IntArray(w * h); src.getPixels(px, 0, w, 0, 0, w, h)
        val q = DoubleArray(8) { if (it % 2 == 0) quad[it] * w else quad[it] * h }
        val size = ScanVision.targetSize(quad.toDoubleArray(), w, h, maxSide)
        val out = ScanVision.warp(px, w, h, q, size[0], size[1])
        return Bitmap.createBitmap(out, size[0], size[1], Bitmap.Config.ARGB_8888)
    }

    fun enhance(src: Bitmap, filter: String, strength: Int, brightness: Int, contrast: Int): Bitmap {
        val w = src.width; val h = src.height
        val px = IntArray(w * h); src.getPixels(px, 0, w, 0, 0, w, h)
        ScanVision.enhance(px, w, h, filter, strength, brightness, contrast)
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    fun detect(path: String): List<Double>? {
        val b = StudioImages.load(path, 1400)
        try {
            val px = IntArray(b.width * b.height); b.getPixels(px, 0, b.width, 0, 0, b.width, b.height)
            return ScanVision.detect(ScanVision.grayFromArgb(px, b.width, b.height, 1400))?.toList()
        } finally { b.recycle() }
    }
}
