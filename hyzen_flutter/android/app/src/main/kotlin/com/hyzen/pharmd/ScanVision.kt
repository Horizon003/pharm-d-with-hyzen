package com.hyzen.pharmd

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * On-device document boundary detection and scan enhancement.
 *
 * Pure Kotlin (no Android types) so the same code runs in the live camera
 * analyser, on captured stills, on gallery imports and in JVM accuracy tests.
 *
 * Detection: downscale + blur -> Canny-style edges -> gradient-oriented Hough
 * lines -> quadrilateral hypotheses (line pairs + brightness-region hull) ->
 * scoring by sign-consistent edge support along each side -> sub-pixel side
 * refinement with robust weighted total-least-squares on a larger image.
 */
object ScanVision {

    class Gray(val w: Int, val h: Int, val px: FloatArray) {
        fun sample(x: Double, y: Double): Double {
            val cx = x.coerceIn(0.0, w - 1.001)
            val cy = y.coerceIn(0.0, h - 1.001)
            val x0 = cx.toInt(); val y0 = cy.toInt()
            val fx = cx - x0; val fy = cy - y0
            val i = y0 * w + x0
            val a = px[i]; val b = px[i + 1]; val c = px[i + w]; val d = px[i + w + 1]
            return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
        }
    }

    /** Corners normalised to [0..1], ordered TL, TR, BR, BL. */
    class Quad(val pts: DoubleArray, val score: Double) {
        fun toList(): List<Double> = pts.toList()
    }

    // ------------------------------------------------------------------ input

    fun grayFromArgb(argb: IntArray, w: Int, h: Int, maxSide: Int): Gray {
        val f = max(1, ceil(max(w, h) / maxSide.toDouble()).toInt())
        val ow = max(1, w / f); val oh = max(1, h / f)
        val out = FloatArray(ow * oh)
        val inv = 1f / (f * f)
        for (oy in 0 until oh) for (ox in 0 until ow) {
            var s = 0f
            for (dy in 0 until f) {
                val row = (oy * f + dy) * w + ox * f
                for (dx in 0 until f) {
                    val c = argb[row + dx]
                    s += 0.299f * ((c shr 16) and 255) + 0.587f * ((c shr 8) and 255) + 0.114f * (c and 255)
                }
            }
            out[oy * ow + ox] = s * inv
        }
        return Gray(ow, oh, out)
    }

    /** Camera Y plane; [rotation] (0/90/180/270) makes it upright. */
    fun grayFromLuma(y: ByteArray, w: Int, h: Int, rowStride: Int, pixelStride: Int, rotation: Int, maxSide: Int): Gray {
        val f = max(1, ceil(max(w, h) / maxSide.toDouble()).toInt())
        val sw = max(1, w / f); val sh = max(1, h / f)
        val small = FloatArray(sw * sh)
        val inv = 1f / (f * f)
        for (oy in 0 until sh) for (ox in 0 until sw) {
            var s = 0f
            for (dy in 0 until f) {
                val row = (oy * f + dy) * rowStride
                for (dx in 0 until f) s += (y[row + (ox * f + dx) * pixelStride].toInt() and 255)
            }
            small[oy * sw + ox] = s * inv
        }
        return rotate(Gray(sw, sh, small), rotation)
    }

    fun rotate(g: Gray, rotation: Int): Gray {
        val r = ((rotation % 360) + 360) % 360
        if (r == 0) return g
        val nw = if (r == 180) g.w else g.h
        val nh = if (r == 180) g.h else g.w
        val out = FloatArray(nw * nh)
        for (y in 0 until g.h) for (x in 0 until g.w) {
            val v = g.px[y * g.w + x]
            when (r) {
                90 -> out[x * nw + (g.h - 1 - y)] = v
                180 -> out[(g.h - 1 - y) * nw + (g.w - 1 - x)] = v
                else -> out[(g.w - 1 - x) * nw + y] = v
            }
        }
        return Gray(nw, nh, out)
    }

    fun downscale(g: Gray, maxSide: Int): Gray {
        if (max(g.w, g.h) <= maxSide) return g
        // Exact resampling: ceil-based integer decimation used to turn a
        // 320px live frame into 160px when the detector requested 280px.
        val scale = maxSide.toDouble() / max(g.w, g.h)
        val ow = max(2, (g.w * scale).roundToInt())
        val oh = max(2, (g.h * scale).roundToInt())
        return Gray(ow, oh, FloatArray(ow * oh) { i ->
            g.sample((i % ow + .5) * g.w / ow - .5, (i / ow + .5) * g.h / oh - .5).toFloat()
        })
    }

    fun blur(g: Gray): Gray {
        val k = floatArrayOf(1f, 4f, 6f, 4f, 1f)
        val tmp = FloatArray(g.w * g.h)
        val out = FloatArray(g.w * g.h)
        for (y in 0 until g.h) for (x in 0 until g.w) {
            var s = 0f
            for (i in -2..2) s += k[i + 2] * g.px[y * g.w + (x + i).coerceIn(0, g.w - 1)]
            tmp[y * g.w + x] = s / 16f
        }
        for (y in 0 until g.h) for (x in 0 until g.w) {
            var s = 0f
            for (i in -2..2) s += k[i + 2] * tmp[(y + i).coerceIn(0, g.h - 1) * g.w + x]
            out[y * g.w + x] = s / 16f
        }
        return Gray(g.w, g.h, out)
    }

    // ------------------------------------------------------------- detection

    private class Edges(val w: Int, val h: Int, val gx: FloatArray, val gy: FloatArray, val mag: FloatArray, val edge: BooleanArray)

    private fun edges(g: Gray, maxHigh: Float = 140f): Edges {
        val w = g.w; val h = g.h; val p = g.px
        val gx = FloatArray(w * h); val gy = FloatArray(w * h); val mag = FloatArray(w * h)
        for (y in 1 until h - 1) for (x in 1 until w - 1) {
            val i = y * w + x
            val a = p[i - w - 1]; val b = p[i - w]; val c = p[i - w + 1]
            val d = p[i - 1]; val f = p[i + 1]
            val gg = p[i + w - 1]; val hh = p[i + w]; val ii = p[i + w + 1]
            val sx = (c + 2 * f + ii) - (a + 2 * d + gg)
            val sy = (gg + 2 * hh + ii) - (a + 2 * b + c)
            gx[i] = sx; gy[i] = sy; mag[i] = sqrt(sx * sx + sy * sy)
        }
        val hist = IntArray(1024)
        var count = 0
        for (v in mag) if (v > 1f) { hist[min(1023, v.toInt())]++; count++ }
        var acc = 0; var high = 40f
        val target = (count * 0.86).toInt()
        for (i in hist.indices) { acc += hist[i]; if (acc >= target) { high = i.toFloat(); break } }
        high = high.coerceIn(12f, maxHigh)
        val low = high * 0.42f
        val nms = FloatArray(w * h)
        for (y in 1 until h - 1) for (x in 1 until w - 1) {
            val i = y * w + x
            val m = mag[i]; if (m < low) continue
            var a = atan2(gy[i], gx[i]) * 180f / PI.toFloat()
            if (a < 0) a += 180f
            val n1: Float; val n2: Float
            when {
                a < 22.5f || a >= 157.5f -> { n1 = mag[i - 1]; n2 = mag[i + 1] }
                a < 67.5f -> { n1 = mag[i - w - 1]; n2 = mag[i + w + 1] }
                a < 112.5f -> { n1 = mag[i - w]; n2 = mag[i + w] }
                else -> { n1 = mag[i - w + 1]; n2 = mag[i + w - 1] }
            }
            if (m >= n1 && m >= n2) nms[i] = m
        }
        val edge = BooleanArray(w * h)
        val stack = IntArray(w * h); var sp = 0
        for (i in nms.indices) if (nms[i] >= high && !edge[i]) {
            edge[i] = true; stack[sp++] = i
            while (sp > 0) {
                val j = stack[--sp]; val jx = j % w; val jy = j / w
                for (dy in -1..1) for (dx in -1..1) {
                    val nx = jx + dx; val ny = jy + dy
                    if (nx < 1 || ny < 1 || nx >= w - 1 || ny >= h - 1) continue
                    val k = ny * w + nx
                    if (!edge[k] && nms[k] >= low) { edge[k] = true; stack[sp++] = k }
                }
            }
        }
        return Edges(w, h, gx, gy, mag, edge)
    }

    /** x cos t + y sin t = r, t in [0, PI). */
    private class Line(val t: Double, val r: Double) {
        val c = cos(t); val s = sin(t)
    }

    private fun hough(e: Edges, maxLines: Int): List<Line> {
        val w = e.w; val h = e.h
        val diag = ceil(hypot(w.toDouble(), h.toDouble())).toInt()
        val nT = 180; val nR = 2 * diag + 1
        val acc = IntArray(nT * nR)
        val cosT = DoubleArray(nT) { cos(it * PI / nT) }
        val sinT = DoubleArray(nT) { sin(it * PI / nT) }
        for (y in 1 until h - 1) for (x in 1 until w - 1) {
            val i = y * w + x
            if (!e.edge[i]) continue
            var a = atan2(e.gy[i].toDouble(), e.gx[i].toDouble()) * 180.0 / PI
            if (a < 0) a += 180.0
            val center = a.roundToInt()
            for (dt in -6..6) {
                val t = ((center + dt) % 180 + 180) % 180
                val r = (x * cosT[t] + y * sinT[t]).roundToInt()
                acc[t * nR + (r + diag).coerceIn(0, nR - 1)]++
            }
        }
        val minVotes = max(12, (0.12 * min(w, h)).toInt())
        val cand = ArrayList<IntArray>()
        for (t in 0 until nT) for (r in 0 until nR) {
            val v = acc[t * nR + r]
            if (v < minVotes) continue
            var isMax = true
            loop@ for (dt in -2..2) for (dr in -2..2) {
                if (dt == 0 && dr == 0) continue
                var tt = t + dt; var rr = r + dr
                if (tt < 0) { tt += nT; rr = nR - 1 - rr } else if (tt >= nT) { tt -= nT; rr = nR - 1 - rr }
                if (rr < 0 || rr >= nR) continue
                val o = acc[tt * nR + rr]
                if (o > v || (o == v && (dt < 0 || (dt == 0 && dr < 0)))) { isMax = false; break@loop }
            }
            if (isMax) cand.add(intArrayOf(t, r - diag, v))
        }
        cand.sortByDescending { it[2] }
        val peaks = ArrayList<Line>()
        for (c in cand) {
            val l = Line(c[0] * PI / nT, c[1].toDouble())
            val dup = peaks.any { p -> sameLine(p, l, w, h) }
            if (!dup) peaks.add(l)
            if (peaks.size >= maxLines) break
        }
        return peaks
    }

    /** Two lines are duplicates if they nearly coincide inside the image. */
    private fun sameLine(a: Line, b: Line, w: Int, h: Int): Boolean {
        if (angleDiff(a.t, b.t) > 4 * PI / 180) return false
        // distance of b's points (sampled across the image) to line a
        val cx = w / 2.0; val cy = h / 2.0
        val d = abs(a.c * cx + a.s * cy - a.r) - abs(b.c * cx + b.s * cy - b.r)
        val sameSide = (a.c * cx + a.s * cy - a.r) * (b.c * cx + b.s * cy - b.r) >= 0
        return sameSide && abs(d) < 6
    }

    private fun angleDiff(a: Double, b: Double): Double {
        var d = abs(a - b) % PI
        if (d > PI / 2) d = PI - d
        return d
    }

    private fun intersect(a: Line, b: Line): DoubleArray? {
        val det = a.c * b.s - a.s * b.c
        if (abs(det) < 1e-6) return null
        return doubleArrayOf((a.r * b.s - a.s * b.r) / det, (a.c * b.r - a.r * b.c) / det)
    }

    /** Order TL, TR, BR, BL. */
    fun order(p: DoubleArray): DoubleArray {
        val cx = (p[0] + p[2] + p[4] + p[6]) / 4
        val cy = (p[1] + p[3] + p[5] + p[7]) / 4
        val idx = (0..3).sortedBy { atan2(p[it * 2 + 1] - cy, p[it * 2] - cx) }
        var start = 0
        var best = Double.MAX_VALUE
        for (k in 0..3) { val s = p[idx[k] * 2] + p[idx[k] * 2 + 1]; if (s < best) { best = s; start = k } }
        val out = DoubleArray(8)
        for (k in 0..3) { val i = idx[(start + k) % 4]; out[k * 2] = p[i * 2]; out[k * 2 + 1] = p[i * 2 + 1] }
        return out
    }

    private fun area(p: DoubleArray): Double {
        var s = 0.0
        for (i in 0..3) { val j = (i + 1) % 4; s += p[i * 2] * p[j * 2 + 1] - p[j * 2] * p[i * 2 + 1] }
        return abs(s) / 2
    }

    private fun plausible(p: DoubleArray, w: Int, h: Int): Boolean {
        val mx = w * 0.06; val my = h * 0.06
        for (i in 0..3) {
            if (p[i * 2] < -mx || p[i * 2] > w + mx || p[i * 2 + 1] < -my || p[i * 2 + 1] > h + my) return false
        }
        if (area(p) < w * h * 0.08) return false
        var sign = 0
        for (i in 0..3) {
            val a = (i + 3) % 4; val b = (i + 1) % 4
            val v1x = p[a * 2] - p[i * 2]; val v1y = p[a * 2 + 1] - p[i * 2 + 1]
            val v2x = p[b * 2] - p[i * 2]; val v2y = p[b * 2 + 1] - p[i * 2 + 1]
            val l1 = hypot(v1x, v1y); val l2 = hypot(v2x, v2y)
            if (l1 < min(w, h) * 0.15 || l2 < min(w, h) * 0.15) return false
            val ang = Math.toDegrees(acos(((v1x * v2x + v1y * v2y) / (l1 * l2)).coerceIn(-1.0, 1.0)))
            if (ang < 45 || ang > 135) return false
            val cr = v2x * v1y - v2y * v1x
            val s = if (cr > 0) 1 else -1
            if (sign == 0) sign = s else if (s != sign) return false
        }
        return true
    }

    /** Fraction of a side covered by edges with consistent gradient sign. */
    private fun sideSupport(e: Edges, ax: Double, ay: Double, bx: Double, by: Double): Double {
        val len = hypot(bx - ax, by - ay)
        if (len < 4) return 0.0
        val nx = -(by - ay) / len; val ny = (bx - ax) / len
        val n = max(16, min(90, (len / 2).toInt()))
        var pos = 0; var neg = 0; var total = 0
        for (k in 0 until n) {
            val t = 0.05 + 0.90 * k / (n - 1)
            val px = ax + (bx - ax) * t; val py = ay + (by - ay) * t
            if (px < 1 || py < 1 || px >= e.w - 1 || py >= e.h - 1) continue
            total++
            var bestDot = 0.0
            for (d in -2..2) {
                val qx = (px + nx * d).roundToInt(); val qy = (py + ny * d).roundToInt()
                if (qx < 1 || qy < 1 || qx >= e.w - 1 || qy >= e.h - 1) continue
                val i = qy * e.w + qx
                if (!e.edge[i]) continue
                val m = e.mag[i]; if (m <= 0f) continue
                val dot = (e.gx[i] * nx + e.gy[i] * ny) / m
                if (abs(dot) > 0.80 && abs(dot) > abs(bestDot)) bestDot = dot
            }
            if (bestDot > 0) pos++ else if (bestDot < 0) neg++
        }
        if (total < n * 0.35) return 0.40
        return max(pos, neg).toDouble() / total
    }

    /** Interior must contrast with the outside band (paper vs background). */
    private fun contrast(g: Gray, p: DoubleArray): Double {
        val cx = (p[0] + p[2] + p[4] + p[6]) / 4; val cy = (p[1] + p[3] + p[5] + p[7]) / 4
        var inS = 0.0; var outS = 0.0; var nIn = 0; var nOut = 0
        for (i in 0..3) {
            val j = (i + 1) % 4
            for (k in 1..9) {
                val t = k / 10.0
                val x = p[i * 2] + (p[j * 2] - p[i * 2]) * t
                val y = p[i * 2 + 1] + (p[j * 2 + 1] - p[i * 2 + 1]) * t
                val dx = cx - x; val dy = cy - y; val l = max(1.0, hypot(dx, dy))
                val off = min(g.w, g.h) * 0.035
                val ix = x + dx / l * off; val iy = y + dy / l * off
                val ox = x - dx / l * off; val oy = y - dy / l * off
                inS += g.sample(ix, iy); nIn++
                if (ox >= 0 && oy >= 0 && ox < g.w && oy < g.h) { outS += g.sample(ox, oy); nOut++ }
            }
        }
        if (nOut < 6) return 0.5
        return (abs(inS / nIn - outS / nOut) / 60.0).coerceIn(0.0, 1.0)
    }

    private fun score(e: Edges, g: Gray, p: DoubleArray): Double {
        var sum = 0.0; var minS = 1.0
        for (i in 0..3) {
            val j = (i + 1) % 4
            val s = sideSupport(e, p[i * 2], p[i * 2 + 1], p[j * 2], p[j * 2 + 1])
            sum += s; minS = min(minS, s)
        }
        if (minS < 0.25) return 0.0
        val areaFrac = (area(p) / (e.w.toDouble() * e.h)).coerceIn(0.0, 1.0)
        val support = 0.7 * (sum / 4) + 0.3 * minS
        return support * (0.78 + 0.22 * sqrt(areaFrac)) * (0.85 + 0.15 * contrast(g, p))
    }

    /** Otsu-thresholded bright/dark region hulls as extra hypotheses. */
    private fun segmentationQuads(g: Gray): List<DoubleArray> {
        val w = g.w; val h = g.h; val total = w * h
        val hist = IntArray(256)
        for (v in g.px) hist[v.toInt().coerceIn(0, 255)]++
        var sum = 0.0; for (i in 0..255) sum += i * hist[i].toDouble()
        var sumB = 0.0; var wB = 0; var best = 0.0; var thr = 128
        for (t in 0..255) {
            wB += hist[t]; if (wB == 0) continue
            val wF = total - wB; if (wF == 0) break
            sumB += t * hist[t].toDouble()
            val mB = sumB / wB; val mF = (sum - sumB) / wF
            val between = wB.toDouble() * wF * (mB - mF) * (mB - mF)
            if (between > best) { best = between; thr = t }
        }
        val out = ArrayList<DoubleArray>()
        for (bright in listOf(true, false)) {
            val label = IntArray(total)
            val queue = IntArray(total)
            var next = 0
            for (s in 0 until total) {
                val inMask = if (bright) g.px[s] > thr else g.px[s] <= thr
                if (!inMask || label[s] != 0) continue
                next++
                var qh = 0; var qt = 0; queue[qt++] = s; label[s] = next
                var cnt = 0; var border = 0
                val minX = IntArray(h) { Int.MAX_VALUE }; val maxX = IntArray(h) { -1 }
                while (qh < qt) {
                    val j = queue[qh++]; cnt++
                    val x = j % w; val y = j / w
                    if (x == 0 || y == 0 || x == w - 1 || y == h - 1) border++
                    if (x < minX[y]) minX[y] = x
                    if (x > maxX[y]) maxX[y] = x
                    for (k in 0..3) {
                        val nb = when (k) { 0 -> if (x > 0) j - 1 else -1; 1 -> if (x < w - 1) j + 1 else -1; 2 -> if (y > 0) j - w else -1; else -> if (y < h - 1) j + w else -1 }
                        if (nb < 0 || label[nb] != 0) continue
                        val m = if (bright) g.px[nb] > thr else g.px[nb] <= thr
                        if (m) { label[nb] = next; queue[qt++] = nb }
                    }
                }
                val frac = cnt.toDouble() / total
                if (frac < 0.10 || frac > 0.95) continue
                if (border > (w + h)) continue
                val pts = ArrayList<DoubleArray>()
                for (y in 0 until h) if (maxX[y] >= 0) {
                    pts.add(doubleArrayOf(minX[y].toDouble(), y.toDouble()))
                    pts.add(doubleArrayOf(maxX[y].toDouble(), y.toDouble()))
                }
                val hull = convexHull(pts)
                if (hull.size >= 4) out.add(maxQuad(hull))
            }
        }
        return out
    }

    private fun convexHull(pts: List<DoubleArray>): List<DoubleArray> {
        val p = pts.sortedWith(compareBy({ it[0] }, { it[1] }))
        if (p.size < 3) return p
        fun cross(o: DoubleArray, a: DoubleArray, b: DoubleArray) = (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
        val lower = ArrayList<DoubleArray>()
        for (q in p) { while (lower.size >= 2 && cross(lower[lower.size - 2], lower[lower.size - 1], q) <= 0) lower.removeAt(lower.size - 1); lower.add(q) }
        val upper = ArrayList<DoubleArray>()
        for (q in p.reversed()) { while (upper.size >= 2 && cross(upper[upper.size - 2], upper[upper.size - 1], q) <= 0) upper.removeAt(upper.size - 1); upper.add(q) }
        lower.removeAt(lower.size - 1); upper.removeAt(upper.size - 1)
        return lower + upper
    }

    private fun maxQuad(hull: List<DoubleArray>): DoubleArray {
        val n = hull.size
        val idx = intArrayOf(
            (0 until n).minBy { hull[it][0] + hull[it][1] },
            (0 until n).maxBy { hull[it][0] - hull[it][1] },
            (0 until n).maxBy { hull[it][0] + hull[it][1] },
            (0 until n).minBy { hull[it][0] - hull[it][1] },
        )
        fun quadArea(ix: IntArray): Double {
            val p = DoubleArray(8); for (k in 0..3) { p[k * 2] = hull[ix[k]][0]; p[k * 2 + 1] = hull[ix[k]][1] }
            return area(p)
        }
        var improved = true; var guard = 0
        while (improved && guard++ < 40) {
            improved = false
            for (k in 0..3) {
                var bestA = quadArea(idx); var bestI = idx[k]
                for (c in 0 until n) {
                    val save = idx[k]; idx[k] = c
                    val a = quadArea(idx)
                    if (a > bestA + 1e-9 && idx.distinct().size == 4) { bestA = a; bestI = c }
                    idx[k] = save
                }
                if (bestI != idx[k]) { idx[k] = bestI; improved = true }
            }
        }
        val p = DoubleArray(8); for (k in 0..3) { p[k * 2] = hull[idx[k]][0]; p[k * 2 + 1] = hull[idx[k]][1] }
        return order(p)
    }

    /**
     * Detect the document boundary.
     * @param fast live-preview mode (smaller image, fewer hypotheses, no refine)
     */
    fun detect(source: Gray, refine: Boolean = true, fast: Boolean = false): Quad? {
        if (source.w < 8 || source.h < 8) return null
        return detectPass(source, refine, fast, 140f)
            ?: detectPass(source, refine, fast, 36f)
    }

    // A second, lower edge threshold recovers pale paper on a light table.
    // Four supported sides and the same geometric validation remain mandatory.
    private fun detectPass(source: Gray, refine: Boolean, fast: Boolean, maxHigh: Float): Quad? {
        val small = blur(downscale(source, if (fast) 420 else 520))
        val e = edges(small, maxHigh)
        val lines = hough(e, if (fast) 20 else 28)
        val hyps = ArrayList<DoubleArray>()
        val minSep = min(small.w, small.h) * 0.20
        val pairs = ArrayList<IntArray>()
        for (i in lines.indices) for (j in i + 1 until lines.size) {
            val a = lines[i]; val b = lines[j]
            if (angleDiff(a.t, b.t) > 30 * PI / 180) continue
            val sameDir = cos(a.t - b.t) > 0
            val separation = abs(a.r - if (sameDir) b.r else -b.r)
            if (separation < minSep) continue
            pairs.add(intArrayOf(i, j))
        }
        for (p in pairs.indices) for (q in p + 1 until pairs.size) {
            val A = pairs[p]; val B = pairs[q]
            if (A[0] in B || A[1] in B) continue
            if (angleDiff(lines[A[0]].t, lines[B[0]].t) < 50 * PI / 180) continue
            val c1 = intersect(lines[A[0]], lines[B[0]]) ?: continue
            val c2 = intersect(lines[A[0]], lines[B[1]]) ?: continue
            val c3 = intersect(lines[A[1]], lines[B[1]]) ?: continue
            val c4 = intersect(lines[A[1]], lines[B[0]]) ?: continue
            val pts = order(doubleArrayOf(c1[0], c1[1], c2[0], c2[1], c3[0], c3[1], c4[0], c4[1]))
            if (plausible(pts, small.w, small.h)) hyps.add(pts)
        }
        hyps.addAll(segmentationQuads(small).filter { plausible(it, small.w, small.h) })
        var best: DoubleArray? = null; var bestScore = 0.0
        for (hq in hyps) {
            val s = score(e, small, hq)
            if (s > bestScore) { bestScore = s; best = hq }
        }
        val chosen = best ?: return null
        if (bestScore < 0.52) return null
        if (refine && !fast) {
            val big = blur(downscale(source, 1100))
            val sx = big.w.toDouble() / small.w; val sy = big.h.toDouble() / small.h
            val scaled = DoubleArray(8) { if (it % 2 == 0) (chosen[it] + 0.5) * sx - 0.5 else (chosen[it] + 0.5) * sy - 0.5 }
            val refined = refineQuad(big, scaled)
            return Quad(clampNorm(DoubleArray(8) { if (it % 2 == 0) (refined[it] + 0.5) / big.w else (refined[it] + 0.5) / big.h }), bestScore)
        }
        return Quad(clampNorm(DoubleArray(8) { if (it % 2 == 0) (chosen[it] + 0.5) / small.w else (chosen[it] + 0.5) / small.h }), bestScore)
    }

    private fun clampNorm(p: DoubleArray) = DoubleArray(8) { p[it].coerceIn(0.0, 1.0) }

    private fun refineQuad(g: Gray, p: DoubleArray): DoubleArray {
        val diag = hypot(g.w.toDouble(), g.h.toDouble())
        val radius = max(4.0, diag * 0.012)
        val lines = arrayOfNulls<DoubleArray>(4)
        for (i in 0..3) {
            val j = (i + 1) % 4
            val ax = p[i * 2]; val ay = p[i * 2 + 1]; val bx = p[j * 2]; val by = p[j * 2 + 1]
            val len = hypot(bx - ax, by - ay)
            if (len < 8) continue
            val nx = -(by - ay) / len; val ny = (bx - ax) / len
            val samples = max(24, min(80, (len / 6).toInt()))
            val xs = ArrayList<Double>(); val ys = ArrayList<Double>(); val ws = ArrayList<Double>(); val signs = ArrayList<Int>()
            val steps = (radius * 2).toInt()
            for (k in 0 until samples) {
                val t = 0.08 + 0.84 * k / (samples - 1)
                val px = ax + (bx - ax) * t; val py = ay + (by - ay) * t
                val vals = DoubleArray(2 * steps + 1)
                var bi = steps; var bestV = 0.0
                for (s in -steps..steps) {
                    val d = s * 0.5
                    val f = g.sample(px + nx * (d + 0.75), py + ny * (d + 0.75)) - g.sample(px + nx * (d - 0.75), py + ny * (d - 0.75))
                    vals[s + steps] = f
                    if (abs(f) > abs(bestV)) { bestV = f; bi = s + steps }
                }
                if (abs(bestV) < 6) continue
                var bestD = (bi - steps) * 0.5
                if (bi in 1 until vals.size - 1) {
                    val l = abs(vals[bi - 1]); val c = abs(vals[bi]); val r = abs(vals[bi + 1])
                    val den = l - 2 * c + r
                    if (abs(den) > 1e-6) bestD += 0.5 * (0.5 * (l - r) / den).coerceIn(-0.5, 0.5)
                }
                xs.add(px + nx * bestD); ys.add(py + ny * bestD); ws.add(abs(bestV)); signs.add(if (bestV > 0) 1 else -1)
            }
            if (xs.size < 8) continue
            val major = if (signs.count { it > 0 } * 2 >= signs.size) 1 else -1
            val keep = signs.indices.filter { signs[it] == major }
            if (keep.size < 6) continue
            var X = keep.map { xs[it] }; var Y = keep.map { ys[it] }; var W = keep.map { ws[it] }
            var fit: DoubleArray? = null
            for (iter in 0 until 3) {
                val f = fitLine(X, Y, W) ?: break
                fit = f
                val res = X.indices.map { abs(f[0] * X[it] + f[1] * Y[it] - f[2]) }
                val lim = max(1.0, 2.5 * res.sorted()[res.size / 2])
                val ok = res.indices.filter { res[it] <= lim }
                if (ok.size < 6 || ok.size == X.size) break
                X = ok.map { X[it] }; Y = ok.map { Y[it] }; W = ok.map { W[it] }
            }
            val f = fit ?: continue
            val mx = (ax + bx) / 2; val my = (ay + by) / 2
            if (abs(f[0] * mx + f[1] * my - f[2]) < radius * 1.5 && abs(f[0] * nx + f[1] * ny) > 0.94) lines[i] = f
        }
        val out = p.copyOf()
        for (k in 0..3) {
            val a = lines[(k + 3) % 4] ?: continue; val b = lines[k] ?: continue
            val det = a[0] * b[1] - a[1] * b[0]
            if (abs(det) < 1e-6) continue
            val x = (a[2] * b[1] - a[1] * b[2]) / det
            val y = (a[0] * b[2] - a[2] * b[0]) / det
            if (hypot(x - p[k * 2], y - p[k * 2 + 1]) < diag * 0.04) { out[k * 2] = x; out[k * 2 + 1] = y }
        }
        return out
    }

    private fun fitLine(xs: List<Double>, ys: List<Double>, ws: List<Double>): DoubleArray? {
        var sw = 0.0; var mx = 0.0; var my = 0.0
        for (i in xs.indices) { sw += ws[i]; mx += ws[i] * xs[i]; my += ws[i] * ys[i] }
        if (sw <= 0) return null
        mx /= sw; my /= sw
        var sxx = 0.0; var syy = 0.0; var sxy = 0.0
        for (i in xs.indices) {
            val dx = xs[i] - mx; val dy = ys[i] - my
            sxx += ws[i] * dx * dx; syy += ws[i] * dy * dy; sxy += ws[i] * dx * dy
        }
        val theta = 0.5 * atan2(2 * sxy, sxx - syy)
        val nx = -sin(theta); val ny = cos(theta)
        return doubleArrayOf(nx, ny, nx * mx + ny * my)
    }

    // ----------------------------------------------------------- enhancement

    /** Smooth paper-white illumination estimate. */
    private fun background(lum: FloatArray, w: Int, h: Int): FloatArray {
        val f = max(4, max(w, h) / 160)
        val sw = (w + f - 1) / f; val sh = (h + f - 1) / f
        var cur = FloatArray(sw * sh)
        for (by in 0 until sh) for (bx in 0 until sw) {
            var m = 0f
            var yy = by * f
            while (yy < min(h, by * f + f)) {
                var xx = bx * f
                while (xx < min(w, bx * f + f)) { val v = lum[yy * w + xx]; if (v > m) m = v; xx += 2 }
                yy += 2
            }
            cur[by * sw + bx] = m
        }
        val dil = FloatArray(sw * sh)
        for (y in 0 until sh) for (x in 0 until sw) {
            var m = 0f
            for (dy in -1..1) for (dx in -1..1) m = max(m, cur[(y + dy).coerceIn(0, sh - 1) * sw + (x + dx).coerceIn(0, sw - 1)])
            dil[y * sw + x] = m
        }
        cur = dil
        repeat(2) {
            val o = FloatArray(sw * sh)
            for (y in 0 until sh) for (x in 0 until sw) {
                var s = 0f; var c = 0
                for (dy in -2..2) for (dx in -2..2) {
                    val xx = x + dx; val yy = y + dy
                    if (xx < 0 || yy < 0 || xx >= sw || yy >= sh) continue
                    s += cur[yy * sw + xx]; c++
                }
                o[y * sw + x] = s / c
            }
            cur = o
        }
        val out = FloatArray(w * h)
        for (y in 0 until h) {
            val fy = ((y + 0.5) / f - 0.5).coerceIn(0.0, sh - 1.0)
            val y0 = fy.toInt(); val y1 = min(sh - 1, y0 + 1); val ty = (fy - y0).toFloat()
            for (x in 0 until w) {
                val fx = ((x + 0.5) / f - 0.5).coerceIn(0.0, sw - 1.0)
                val x0 = fx.toInt(); val x1 = min(sw - 1, x0 + 1); val tx = (fx - x0).toFloat()
                val a = cur[y0 * sw + x0] * (1 - tx) + cur[y0 * sw + x1] * tx
                val b = cur[y1 * sw + x0] * (1 - tx) + cur[y1 * sw + x1] * tx
                out[y * w + x] = max(24f, a * (1 - ty) + b * ty)
            }
        }
        return out
    }

    /**
     * Readable-document filters, in place.
     * filter: original | magic | gray | bw  ("contrast" = legacy alias of magic)
     * brightness / contrast: -100..100
     */
    fun enhance(argb: IntArray, w: Int, h: Int, filter: String, strength: Int = 100, brightness: Int = 0, contrast: Int = 0) {
        val n = w * h
        val mode = if (filter == "contrast") "magic" else filter
        val original = if (strength.coerceIn(0, 100) < 100 && mode != "original") argb.copyOf() else null
        if (mode == "magic" || mode == "gray" || mode == "bw") {
            val lum = FloatArray(n)
            for (i in 0 until n) {
                val c = argb[i]
                lum[i] = 0.299f * ((c shr 16) and 255) + 0.587f * ((c shr 8) and 255) + 0.114f * (c and 255)
            }
            val bg = background(lum, w, h)
            when (mode) {
                "magic" -> for (i in 0 until n) {
                    val c = argb[i]; val k = 250f / bg[i]
                    var r = ((c shr 16) and 255) * k; var g = ((c shr 8) and 255) * k; var b = (c and 255) * k
                    val l = 0.299f * r + 0.587f * g + 0.114f * b
                    r = l + (r - l) * 1.2f; g = l + (g - l) * 1.2f; b = l + (b - l) * 1.2f
                    r = (r - 24f) * 1.16f; g = (g - 24f) * 1.16f; b = (b - 24f) * 1.16f
                    argb[i] = (c and -0x1000000) or (clamp(r) shl 16) or (clamp(g) shl 8) or clamp(b)
                }
                "gray" -> for (i in 0 until n) {
                    val q = clamp((lum[i] * 248f / bg[i] - 22f) * 1.1f)
                    argb[i] = (argb[i] and -0x1000000) or (q shl 16) or (q shl 8) or q
                }
                else -> {
                    val norm = FloatArray(n) { (lum[it] * 255f / bg[it]).coerceAtMost(255f) }
                    val iw = w + 1
                    val integ = DoubleArray(iw * (h + 1))
                    for (y in 0 until h) {
                        var row = 0.0
                        for (x in 0 until w) { row += norm[y * w + x]; integ[(y + 1) * iw + x + 1] = integ[y * iw + x + 1] + row }
                    }
                    val r = max(6, max(w, h) / 50)
                    for (y in 0 until h) for (x in 0 until w) {
                        val x0 = max(0, x - r); val y0 = max(0, y - r); val x1 = min(w - 1, x + r); val y1 = min(h - 1, y + r)
                        val cnt = (x1 - x0 + 1) * (y1 - y0 + 1)
                        val s = integ[(y1 + 1) * iw + x1 + 1] - integ[y0 * iw + x1 + 1] - integ[(y1 + 1) * iw + x0] + integ[y0 * iw + x0]
                        val v = norm[y * w + x]
                        val q = if (v > 215f) 255 else clamp(((v - (s / cnt * 0.86 - 4)) * 9 + 128).toFloat())
                        argb[y * w + x] = (argb[y * w + x] and -0x1000000) or (q shl 16) or (q shl 8) or q
                    }
                }
            }
        }
        if (original != null) {
            val amount = strength.coerceIn(0, 100) / 100f
            val inverse = 1f - amount
            for (i in 0 until n) {
                val filtered = argb[i]
                val source = original[i]
                val r = (((source shr 16) and 255) * inverse + ((filtered shr 16) and 255) * amount).toInt().coerceIn(0, 255)
                val g = (((source shr 8) and 255) * inverse + ((filtered shr 8) and 255) * amount).toInt().coerceIn(0, 255)
                val b = ((source and 255) * inverse + (filtered and 255) * amount).toInt().coerceIn(0, 255)
                argb[i] = (filtered and -0x1000000) or (r shl 16) or (g shl 8) or b
            }
        }
        if (brightness != 0 || contrast != 0) {
            val f = ((100 + contrast.coerceIn(-100, 100)) / 100f).let { it * it }
            val b = brightness.coerceIn(-100, 100) * 1.2f
            for (i in 0 until n) {
                val c = argb[i]
                val r = (((c shr 16) and 255) - 128f) * f + 128f + b
                val g = (((c shr 8) and 255) - 128f) * f + 128f + b
                val bl = ((c and 255) - 128f) * f + 128f + b
                argb[i] = (c and -0x1000000) or (clamp(r) shl 16) or (clamp(g) shl 8) or clamp(bl)
            }
        }
    }

    private fun clamp(v: Float): Int = if (v <= 0f) 0 else if (v >= 255f) 255 else v.toInt()

    // ------------------------------------------------------------- geometry

    /** Output size for a corrected page; snaps to A4/Letter ratio when close. */
    fun targetSize(q: DoubleArray, imgW: Int, imgH: Int, maxSide: Int): IntArray {
        fun d(a: Int, b: Int) = hypot((q[a * 2] - q[b * 2]) * imgW, (q[a * 2 + 1] - q[b * 2 + 1]) * imgH)
        var w = max(d(0, 1), d(3, 2)); var h = max(d(0, 3), d(1, 2))
        val ratio = max(w, h) / max(1.0, min(w, h))
        for (s in doubleArrayOf(sqrt(2.0), 11.0 / 8.5)) if (abs(ratio - s) / s < 0.06) {
            if (h >= w) h = w * s else w = h * s
            break
        }
        val k = min(1.0, maxSide / max(w, h))
        return intArrayOf(max(16, (w * k).roundToInt()), max(16, (h * k).roundToInt()))
    }

    /** Homography mapping destination (u,v) -> source (x,y); 3x3 row-major. */
    fun homography(dstW: Double, dstH: Double, src: DoubleArray): DoubleArray {
        val d = doubleArrayOf(0.0, 0.0, dstW, 0.0, dstW, dstH, 0.0, dstH)
        val a = Array(8) { DoubleArray(9) }
        for (i in 0..3) {
            val u = d[i * 2]; val v = d[i * 2 + 1]; val x = src[i * 2]; val y = src[i * 2 + 1]
            a[i * 2] = doubleArrayOf(u, v, 1.0, 0.0, 0.0, 0.0, -u * x, -v * x, x)
            a[i * 2 + 1] = doubleArrayOf(0.0, 0.0, 0.0, u, v, 1.0, -u * y, -v * y, y)
        }
        for (c in 0 until 8) {
            var piv = c
            for (r in c + 1 until 8) if (abs(a[r][c]) > abs(a[piv][c])) piv = r
            val tmp = a[c]; a[c] = a[piv]; a[piv] = tmp
            require(abs(a[c][c]) > 1e-12) { "Invalid crop corners" }
            for (r in 0 until 8) if (r != c) {
                val f = a[r][c] / a[c][c]
                for (k in c until 9) a[r][k] -= f * a[c][k]
            }
        }
        return DoubleArray(9) { if (it == 8) 1.0 else a[it][8] / a[it][it] }
    }

    /** Bilinear perspective warp of ARGB pixels. [quad] in source pixel coords. */
    fun warp(src: IntArray, sw: Int, sh: Int, quad: DoubleArray, dw: Int, dh: Int): IntArray {
        val m = homography(dw.toDouble(), dh.toDouble(), quad)
        val out = IntArray(dw * dh)
        for (v in 0 until dh) {
            val vv = v + 0.5
            for (u in 0 until dw) {
                val uu = u + 0.5
                val z = m[6] * uu + m[7] * vv + m[8]
                val x = ((m[0] * uu + m[1] * vv + m[2]) / z - 0.5).coerceIn(0.0, sw - 1.001)
                val y = ((m[3] * uu + m[4] * vv + m[5]) / z - 0.5).coerceIn(0.0, sh - 1.001)
                val x0 = x.toInt(); val y0 = y.toInt()
                val fx = x - x0; val fy = y - y0
                val i = y0 * sw + x0
                val c00 = src[i]; val c10 = src[min(i + 1, src.size - 1)]
                val c01 = src[min(i + sw, src.size - 1)]; val c11 = src[min(i + sw + 1, src.size - 1)]
                var px = 0xFF shl 24
                for (sh2 in intArrayOf(16, 8, 0)) {
                    val a = (c00 shr sh2) and 255; val b = (c10 shr sh2) and 255
                    val c = (c01 shr sh2) and 255; val d = (c11 shr sh2) and 255
                    val vtop = a + (b - a) * fx; val vbot = c + (d - c) * fx
                    px = px or (((vtop + (vbot - vtop) * fy) + 0.5).toInt().coerceIn(0, 255) shl sh2)
                }
                out[v * dw + u] = px
            }
        }
        return out
    }

    fun validQuad(q: List<Double>?): Boolean {
        if (q == null || q.size != 8 || q.any { !it.isFinite() || it < -0.01 || it > 1.01 }) return false
        val p = q.toDoubleArray()
        var sign = 0
        for (i in 0..3) {
            val a = i; val b = (i + 1) % 4; val c = (i + 2) % 4
            val cr = (p[b * 2] - p[a * 2]) * (p[c * 2 + 1] - p[b * 2 + 1]) - (p[b * 2 + 1] - p[a * 2 + 1]) * (p[c * 2] - p[b * 2])
            if (abs(cr) < 1e-5) return false
            val s = if (cr > 0) 1 else -1
            if (sign == 0) sign = s else if (s != sign) return false
        }
        return area(p) > 0.01
    }

    fun isFullFrame(q: List<Double>): Boolean {
        val full = doubleArrayOf(0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0)
        return (0..7).all { abs(q[it] - full[it]) < 0.004 }
    }

    /** Max corner distance between two normalised quads. */
    fun cornerDistance(a: DoubleArray, b: DoubleArray): Double {
        var m = 0.0
        for (i in 0..3) m = max(m, hypot(a[i * 2] - b[i * 2], a[i * 2 + 1] - b[i * 2 + 1]))
        return m
    }
}
