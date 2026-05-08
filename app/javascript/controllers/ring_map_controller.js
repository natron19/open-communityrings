import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values  = { rings: Array, overlaps: Array }

  connect() {
    this.render()
    this.handleRingAdded       = () => this.fetchAndRender()
    this.handleRingUpdated     = () => this.fetchAndRender()
    this.handleRingRemoved     = () => this.fetchAndRender()
    this.handleOverlapReplaced = () => this.fetchAndRender()

    document.addEventListener("ring:added",      this.handleRingAdded)
    document.addEventListener("ring:updated",    this.handleRingUpdated)
    document.addEventListener("ring:removed",    this.handleRingRemoved)
    document.addEventListener("overlap:replaced", this.handleOverlapReplaced)
  }

  disconnect() {
    document.removeEventListener("ring:added",      this.handleRingAdded)
    document.removeEventListener("ring:updated",    this.handleRingUpdated)
    document.removeEventListener("ring:removed",    this.handleRingRemoved)
    document.removeEventListener("overlap:replaced", this.handleOverlapReplaced)
    this._disposeTooltips()
  }

  fetchAndRender() {
    this.render()
  }

  render() {
    const rings    = this.ringsValue
    const overlaps = this.overlapsValue
    if (!rings.length) return

    const W = 800, H = 560
    const positions = this._layout(rings, W, H)
    const svg = this._buildSVG(rings, overlaps, positions, W, H)
    this.canvasTarget.innerHTML = svg
    this._initTooltips()
  }

  // ── Layout: simple force repulsion ──────────────────────────────────
  _layout(rings, W, H) {
    const n = rings.length
    const minR = 55, maxR = 95
    const positions = rings.map((ring, i) => {
      const angle = (2 * Math.PI * i) / n
      const r = this._ringRadius(ring, minR, maxR)
      return {
        id: ring.id,
        x: W / 2 + (W * 0.32) * Math.cos(angle),
        y: H / 2 + (H * 0.32) * Math.sin(angle),
        r
      }
    })

    for (let iter = 0; iter < 60; iter++) {
      for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
          const a = positions[i], b = positions[j]
          const dx = b.x - a.x, dy = b.y - a.y
          const dist = Math.sqrt(dx * dx + dy * dy) || 1
          const minDist = a.r + b.r + 8
          if (dist < minDist) {
            const factor = (minDist - dist) / dist * 0.5
            a.x -= dx * factor; a.y -= dy * factor
            b.x += dx * factor; b.y += dy * factor
          }
        }
        positions[i].x += (W / 2 - positions[i].x) * 0.02
        positions[i].y += (H / 2 - positions[i].y) * 0.02
        const p = positions[i]
        p.x = Math.max(p.r + 10, Math.min(W - p.r - 10, p.x))
        p.y = Math.max(p.r + 10, Math.min(H - p.r - 10, p.y))
      }
    }
    return positions
  }

  _ringRadius(ring, minR, maxR) {
    const seed = this._hashString(ring.id)
    return minR + (seed % (maxR - minR))
  }

  // ── SVG construction ─────────────────────────────────────────────────
  _buildSVG(rings, overlaps, positions, W, H) {
    const posMap = {}
    positions.forEach(p => { posMap[p.id] = p })

    let svgParts = [`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" style="width:100%;height:auto;">`]

    overlaps.forEach(overlap => {
      const a = posMap[overlap.ring_a_id]
      const b = posMap[overlap.ring_b_id]
      if (!a || !b) return
      const lens = this._lensPath(a, b)
      if (lens) svgParts.push(`<path class="overlap-lens" d="${lens}"/>`)
    })

    rings.forEach((ring) => {
      const p = posMap[ring.id]
      if (!p) return
      const path = this._jitteredCirclePath(p.x, p.y, p.r, ring.id)
      const label = this._escapeXml(ring.name.length > 16 ? ring.name.slice(0, 15) + "…" : ring.name)
      const tooltipTitle = this._escapeXml(`${ring.name}\n${ring.description}`)
      svgParts.push(`
        <path class="ring-shape" d="${path}"
              data-bs-toggle="tooltip"
              data-bs-placement="top"
              data-bs-title="${tooltipTitle}"
              data-bs-html="false"/>
        <text class="ring-label" x="${p.x}" y="${p.y}">${label}</text>
      `)
    })

    svgParts.push("</svg>")
    return svgParts.join("")
  }

  _jitteredCirclePath(cx, cy, r, id) {
    const seed = this._hashString(id)
    const points = 18
    let d = ""
    for (let i = 0; i <= points; i++) {
      const angle = (2 * Math.PI * i) / points
      const jitter = 1 + ((this._lcg(seed + i) % 12) - 6) / 100
      const x = cx + r * jitter * Math.cos(angle)
      const y = cy + r * jitter * Math.sin(angle)
      d += i === 0 ? `M ${x.toFixed(1)} ${y.toFixed(1)}` : ` L ${x.toFixed(1)} ${y.toFixed(1)}`
    }
    return d + " Z"
  }

  _lensPath(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y
    const dist = Math.sqrt(dx * dx + dy * dy)
    if (dist >= a.r + b.r) return null
    if (dist <= Math.abs(a.r - b.r)) return null

    const ra = a.r, rb = b.r
    const d2 = dist * dist
    const cosA = (d2 + ra * ra - rb * rb) / (2 * dist * ra)
    const cosB = (d2 + rb * rb - ra * ra) / (2 * dist * rb)
    const angleA = Math.acos(Math.max(-1, Math.min(1, cosA)))

    const p1x = a.x + ra * Math.cos(Math.atan2(dy, dx) + angleA)
    const p1y = a.y + ra * Math.sin(Math.atan2(dy, dx) + angleA)
    const p2x = a.x + ra * Math.cos(Math.atan2(dy, dx) - angleA)
    const p2y = a.y + ra * Math.sin(Math.atan2(dy, dx) - angleA)

    const largeArc = 0
    return `M ${p1x.toFixed(1)} ${p1y.toFixed(1)}
            A ${rb.toFixed(1)} ${rb.toFixed(1)} 0 ${largeArc} 0 ${p2x.toFixed(1)} ${p2y.toFixed(1)}
            A ${ra.toFixed(1)} ${ra.toFixed(1)} 0 ${largeArc} 0 ${p1x.toFixed(1)} ${p1y.toFixed(1)} Z`
  }

  // ── Tooltips ─────────────────────────────────────────────────────────
  _initTooltips() {
    if (!window.bootstrap) return
    this._disposeTooltips()
    this._tooltips = [...this.canvasTarget.querySelectorAll("[data-bs-toggle='tooltip']")]
      .map(el => new window.bootstrap.Tooltip(el, { trigger: "hover focus", container: "body" }))
  }

  _disposeTooltips() {
    (this._tooltips || []).forEach(t => t.dispose())
    this._tooltips = []
  }

  // ── Utilities ────────────────────────────────────────────────────────
  _hashString(str) {
    let h = 0
    for (let i = 0; i < str.length; i++) {
      h = (Math.imul(31, h) + str.charCodeAt(i)) | 0
    }
    return Math.abs(h)
  }

  _lcg(seed) {
    return (1664525 * seed + 1013904223) & 0xffffffff
  }

  _escapeXml(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
