"use client"
import { useEffect, useState, useCallback, useRef } from "react"
import ReactECharts from "echarts-for-react"
import * as echarts from "echarts"
import type { EChartsOption } from "echarts"

interface RawPoint {
  WELL_ASSET_ID: string
  ATTR_ID: string
  TIMESTAMP_CENTRAL: string
  VALUE_NUMBER: number
}

interface Annotation {
  NOTE_TIMESTAMP: string
  NOTE_TEXT: string
  NOTE_CATEGORY: string
  SIGNAL_NAME: string
  CREATE_AUTHOR: string
}

interface Props {
  wellId: string
  wellName: string
  onAnnotationSaved?: () => void
}

const dataCache = new Map<string, RawPoint[]>()

const CATEGORY_COLORS: Record<string, string> = {
  DRAWDOWN: "#f44336",
  OPERATIONS: "#ff9800",
  MAINTENANCE: "#2196f3",
  GENERAL: "#9e9e9e",
}

// Signal display config: label, color, chart group index, y-axis label
const SIGNAL_CONFIG: Record<string, { label: string; color: string; chart: number; unit: string }> = {
  GAS_FLOW_RATE:       { label: "Gas Flow Rate",   color: "#d62728", chart: 0, unit: "MSCF/d" },
  GAS_FLOW_YESTERDAY:  { label: "Gas Yesterday",   color: "#ff6659", chart: 0, unit: "MSCF/d" },
  TUBING_PRESSURE:     { label: "Tubing Pressure", color: "#673ab7", chart: 1, unit: "psi" },
  CASING_PRESSURE:     { label: "Casing Pressure", color: "#9c27b0", chart: 1, unit: "psi" },
  DAILY_EST_DRAWDOWN:  { label: "Drawdown",        color: "#f44336", chart: 2, unit: "psi/d" },
  CHOKE_OUTPUT:        { label: "Choke Output",    color: "#ff9800", chart: 3, unit: "%" },
  POSITIVE_CHOKE:      { label: "Positive Choke",  color: "#2196f3", chart: 3, unit: "64ths" },
  WATER_FLOW_RATE:     { label: "Water Flow Rate", color: "#1f77b4", chart: 4, unit: "BBL/d" },
  WATER_FLOW_YESTERDAY:{ label: "Water Yesterday", color: "#6baed6", chart: 4, unit: "BBL/d" },
}

// Map signal names used in annotations to chart indices
const SIGNAL_CHART_MAP: Record<string, number> = Object.fromEntries(
  Object.entries(SIGNAL_CONFIG).map(([k, v]) => [k, v.chart])
)

const CHART_TITLES = ["Gas Flow Rates", "Pressures", "Drawdown", "Choke Positions", "Water Flow Rates"]

export function WellCharts({ wellId, wellName, onAnnotationSaved }: Props) {
  const [rawData, setRawData] = useState<RawPoint[]>([])
  const [annotations, setAnnotations] = useState<Annotation[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const chartRefs = useRef<(ReactECharts | null)[]>(CHART_TITLES.map(() => null))
  const groupConnected = useRef(false)

  const [showAnnotationForm, setShowAnnotationForm] = useState(false)
  const [annotationPos, setAnnotationPos] = useState({ x: 0, y: 0 })
  const [newAnnotation, setNewAnnotation] = useState({ timestamp: "", signal: "", text: "", category: "OPERATIONS" })
  const [showValueTracing, setShowValueTracing] = useState(false)

  const zoomRange = useRef<{ start: number; end: number }>({ start: 0, end: 100 })

  const fetchAnnotations = useCallback(async () => {
    try {
      const res = await fetch(`/api/chart-annotations?wellId=${encodeURIComponent(wellId)}`)
      const rows = await res.json()
      if (Array.isArray(rows)) setAnnotations(rows)
    } catch { /* annotations are non-critical */ }
  }, [wellId])

  const fetchData = useCallback(async () => {
    setLoading(true)
    setRawData([])
    setError(null)
    try {
      let rows: RawPoint[]
      if (dataCache.has(wellId)) {
        rows = dataCache.get(wellId)!
      } else {
        const res = await fetch(`/api/timeseries?wellId=${encodeURIComponent(wellId)}&startDate=2020-01-01&endDate=2030-01-01&maxPoints=1000`)
        const data = await res.json()
        if (data?.error) { setError(data.error); setLoading(false); return }
        rows = Array.isArray(data) ? data : []
        dataCache.set(wellId, rows)
      }
      setRawData(rows)
    } catch (err: any) {
      setError(`Failed to load timeseries: ${err.message || "Network error"}`)
    } finally { setLoading(false) }
  }, [wellId])

  useEffect(() => { fetchData(); fetchAnnotations() }, [wellId, fetchData, fetchAnnotations])

  // Pivot raw data into per-signal time series
  const signalData = useCallback(() => {
    const map = new Map<string, [string, number][]>()
    for (const pt of rawData) {
      if (!map.has(pt.ATTR_ID)) map.set(pt.ATTR_ID, [])
      map.get(pt.ATTR_ID)!.push([pt.TIMESTAMP_CENTRAL, pt.VALUE_NUMBER])
    }
    return map
  }, [rawData])

  // Connect charts for synchronized zoom/pan
  useEffect(() => {
    if (!rawData.length || groupConnected.current) return
    const timer = setTimeout(() => {
      const instances = chartRefs.current.map(r => r?.getEchartsInstance()).filter(Boolean)
      if (instances.length === CHART_TITLES.length) {
        instances.forEach(inst => { inst!.group = "wellCharts" })
        echarts.connect("wellCharts")
        groupConnected.current = true
        instances[0]!.on("dataZoom", () => {
          const opt = instances[0]!.getOption() as any
          if (opt.dataZoom?.[0]) {
            zoomRange.current = { start: opt.dataZoom[0].start ?? 0, end: opt.dataZoom[0].end ?? 100 }
          }
        })
      }
    }, 100)
    return () => clearTimeout(timer)
  }, [rawData])

  useEffect(() => { groupConnected.current = false; zoomRange.current = { start: 0, end: 100 } }, [wellId])

  // Restore zoom after annotation updates
  useEffect(() => {
    if (!rawData.length) return
    const { start, end } = zoomRange.current
    if (start === 0 && end === 100) return
    const timer = setTimeout(() => {
      for (const ref of chartRefs.current) {
        const inst = ref?.getEchartsInstance()
        if (inst) inst.dispatchAction({ type: "dataZoom", start, end })
      }
    }, 50)
    return () => clearTimeout(timer)
  }, [annotations, rawData])

  // Right-click annotation handler
  const registerContextMenu = useCallback((chartIdx: number, signals: string[]) => {
    const instance = chartRefs.current[chartIdx]?.getEchartsInstance()
    if (!instance) return

    instance.on("contextmenu", (params: any) => {
      params.event?.event?.preventDefault()
      const ts = params.value?.[0] || params.data?.[0]
      const signal = params.seriesName ? Object.entries(SIGNAL_CONFIG).find(([, v]) => v.label === params.seriesName)?.[0] || signals[0] : signals[0]
      setNewAnnotation({ timestamp: ts, signal, text: "", category: "OPERATIONS" })
      setAnnotationPos({ x: params.event?.event?.clientX || 300, y: params.event?.event?.clientY || 300 })
      setShowAnnotationForm(true)
    })

    instance.getZr().on("contextmenu", (params: any) => {
      params.event?.preventDefault()
      const pointInPixel = [params.offsetX, params.offsetY]
      if (instance.containPixel("grid", pointInPixel)) {
        const dataCoord = instance.convertFromPixel("grid", pointInPixel)
        const ts = new Date(dataCoord[0]).toISOString()
        setNewAnnotation({ timestamp: ts, signal: signals[0], text: "", category: "OPERATIONS" })
        setAnnotationPos({ x: params.event?.clientX || 300, y: params.event?.clientY || 300 })
        setShowAnnotationForm(true)
      }
    })
  }, [])

  useEffect(() => {
    if (!rawData.length) return
    const timer = setTimeout(() => {
      CHART_TITLES.forEach((_, idx) => {
        const signals = Object.entries(SIGNAL_CONFIG).filter(([, v]) => v.chart === idx).map(([k]) => k)
        registerContextMenu(idx, signals)
      })
    }, 200)
    return () => clearTimeout(timer)
  }, [rawData, registerContextMenu])

  const getMarkPointsWithY = (chartNum: number, signalKey: string, seriesData: [string, number | null][]) => {
    const pts = annotations.filter(a => SIGNAL_CHART_MAP[a.SIGNAL_NAME] === chartNum && a.SIGNAL_NAME === signalKey)
    if (pts.length === 0) return undefined
    return {
      symbol: "pin",
      symbolSize: 30,
      label: { show: true, fontSize: 9, color: "#fff", formatter: "{b}" },
      data: pts.map(a => {
        const noteTs = new Date(a.NOTE_TIMESTAMP).getTime()
        let closestY = 0
        let minDist = Infinity
        for (const pt of seriesData) {
          if (pt[1] == null) continue
          const dist = Math.abs(new Date(pt[0]).getTime() - noteTs)
          if (dist < minDist) { minDist = dist; closestY = pt[1] }
        }
        return {
          name: a.NOTE_CATEGORY?.charAt(0) || "N",
          noteText: `[${a.NOTE_CATEGORY}] ${a.NOTE_TEXT}\n— ${a.CREATE_AUTHOR || ""}`,
          coord: [noteTs, closestY],
          itemStyle: { color: CATEGORY_COLORS[a.NOTE_CATEGORY] || "#9e9e9e" },
        }
      })
    }
  }

  const saveAnnotation = async () => {
    if (!newAnnotation.text.trim()) return
    const c0 = chartRefs.current[0]?.getEchartsInstance()
    if (c0) {
      const opt = c0.getOption() as any
      if (opt.dataZoom?.[0]) {
        zoomRange.current = { start: opt.dataZoom[0].start ?? 0, end: opt.dataZoom[0].end ?? 100 }
      }
    }
    await fetch("/api/chart-annotations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        wellId,
        timestamp: newAnnotation.timestamp,
        noteText: newAnnotation.text,
        category: newAnnotation.category,
        signal: newAnnotation.signal,
      })
    })
    setShowAnnotationForm(false)
    setNewAnnotation({ timestamp: "", signal: "", text: "", category: "OPERATIONS" })
    fetchAnnotations()
    onAnnotationSaved?.()
  }

  const makeTooltip = () => {
    if (showValueTracing) {
      return {
        show: true,
        trigger: "axis" as const,
        // Vertical line only, not snapped to points, so every connected chart shows it at the same timestamp
        axisPointer: { type: "line" as const, snap: false },
        formatter: (params: any) => {
          if (!Array.isArray(params) && params.componentType === "markPoint") {
            return `<div style="max-width:280px;white-space:pre-wrap;font-size:12px">${params.data?.noteText || ""}</div>`
          }
          if (!Array.isArray(params) || params.length === 0) return ""
          const ts = params[0].value?.[0]
          const d = ts ? new Date(ts) : null
          let html = d ? `<div style="font-size:10px;margin-bottom:4px">${d.toLocaleDateString()} ${d.toLocaleTimeString()}</div>` : ""
          for (const p of params) {
            if (p.value?.[1] != null) {
              html += `<div style="font-size:11px">${p.marker} ${p.seriesName}: <b>${Number(p.value[1]).toFixed(1)}</b></div>`
            }
          }
          return html
        }
      }
    }
    return {
      show: true,
      trigger: "item" as const,
      formatter: (params: any) => {
        if (params.componentType === "markPoint") {
          return `<div style="max-width:280px;white-space:pre-wrap;font-size:12px">${params.data?.noteText || ""}</div>`
        }
        return ""
      }
    }
  }

  const sharedDataZoom = [
    { type: "inside" as const, xAxisIndex: 0, filterMode: "none" as const,
      start: zoomRange.current.start, end: zoomRange.current.end },
    { type: "slider" as const, xAxisIndex: 0, bottom: 5, height: 18, filterMode: "none" as const,
      start: zoomRange.current.start, end: zoomRange.current.end }
  ]
  const sharedGrid = { left: 65, right: 125, top: 30, bottom: 50 }

  // One common time extent for every chart, rounded out to whole days, so all x-axes start and
  // end at the same midnight and ticks fall on regular calendar boundaries
  const xExtent = (() => {
    let min = Infinity, max = -Infinity
    for (const pt of rawData) {
      const t = new Date(pt.TIMESTAMP_CENTRAL).getTime()
      if (!isNaN(t)) { if (t < min) min = t; if (t > max) max = t }
    }
    if (!isFinite(min)) return {}
    const start = new Date(min); start.setHours(0, 0, 0, 0)
    const end = new Date(max); end.setHours(0, 0, 0, 0); end.setDate(end.getDate() + 1)
    return { min: start.getTime(), max: end.getTime() }
  })()
  const sharedXAxis = {
    type: "time" as const,
    ...xExtent,
    splitNumber: 8,
    axisLabel: {
      fontSize: 10,
      hideOverlap: true,
      // only regular ticks are labelled; the raw extent endpoints are not forced onto the axis
      showMinLabel: false,
      showMaxLabel: false,
      // label format follows the tick interval ECharts picks for the visible (zoomed) range
      formatter: {
        year: "{yyyy}",
        month: "{MMM} {yyyy}",
        day: "{MMM} {d}",
        hour: "{MMM} {d} {HH}:{mm}",
        minute: "{HH}:{mm}",
        second: "{HH}:{mm}:{ss}",
      },
    },
    splitLine: { show: true, lineStyle: { opacity: 0.15 } },
    axisPointer: { snap: false },
  }

  const signals = signalData()
  const tooltip = makeTooltip()

  // Build chart options dynamically per chart group
  const buildChartOption = (chartIdx: number): EChartsOption => {
    const chartSignals = Object.entries(SIGNAL_CONFIG).filter(([, v]) => v.chart === chartIdx)
    const yAxes: any[] = []
    const series: any[] = []
    const unitAxis = new Map<string, number>()

    chartSignals.forEach(([key, cfg]) => {
      const data = signals.get(key) || []
      // Signals sharing a unit share one y-axis
      if (!unitAxis.has(cfg.unit)) {
        const i = yAxes.length
        unitAxis.set(cfg.unit, i)
        yAxes.push({
          type: "value",
          name: cfg.unit,
          nameTextStyle: { fontSize: 10 },
          axisLabel: { fontSize: 10 },
          position: i === 0 ? "left" : "right",
          offset: i > 1 ? (i - 1) * 60 : 0,
          // Default to -10..100 psi/d but widen to fit out-of-range values instead of clipping them
          ...(key === "DAILY_EST_DRAWDOWN"
            ? { min: (v: { min: number }) => Math.min(-10, Math.floor(v.min)), max: (v: { max: number }) => Math.max(100, Math.ceil(v.max)) }
            : {}),
        })
      }
      series.push({
        name: cfg.label,
        type: "line",
        yAxisIndex: unitAxis.get(cfg.unit),
        // Daily drawdown is one point per day and often sparse; without symbols isolated days are invisible
        showSymbol: key === "DAILY_EST_DRAWDOWN",
        symbolSize: 4,
        lineStyle: { width: 1.5 },
        color: cfg.color,
        data,
        markPoint: getMarkPointsWithY(chartIdx, key, data),
      })
    })

    return {
      tooltip,
      legend: { data: chartSignals.map(([, v]) => v.label), top: 0, textStyle: { fontSize: 10 } },
      grid: sharedGrid,
      dataZoom: sharedDataZoom,
      xAxis: sharedXAxis,
      yAxis: yAxes.length > 0 ? yAxes : [{ type: "value" }],
      series,
    }
  }

  const chartOptions = CHART_TITLES.map((_, idx) => buildChartOption(idx))
  const chartHeights = ["200px", "200px", "180px", "180px", "180px"]

  const signalLabel = (s: string) => SIGNAL_CONFIG[s]?.label || s

  return (
    <div className="border rounded-lg p-4 space-y-1 relative">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold">Production History — {wellName}</h3>
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-1.5 text-xs text-muted-foreground cursor-pointer select-none">
            <input type="checkbox" checked={showValueTracing} onChange={e => setShowValueTracing(e.target.checked)} className="rounded" />
            Show value tracing
          </label>
          {annotations.length > 0 && <span className="text-xs text-muted-foreground">{annotations.length} annotations</span>}
          {loading && <span className="text-xs text-muted-foreground animate-pulse">Loading...</span>}
        </div>
      </div>
      <p className="text-xs text-muted-foreground">{rawData.length} pts (LTTB) | Scroll to zoom | Drag slider to pan | Right-click to annotate</p>

      {error && (
        <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded px-3 py-2 text-sm text-red-700 dark:text-red-300">
          <span className="font-medium">Timeseries Error:</span> {error}
        </div>
      )}

      {!error && (loading || rawData.length === 0) && !(!loading && dataCache.has(wellId)) && (
        <div className="flex items-center justify-center h-[500px] bg-muted/10 rounded border border-dashed">
          <div className="flex items-center gap-2 text-muted-foreground">
            <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" strokeDasharray="32" strokeLinecap="round" />
            </svg>
            <span className="text-sm">Loading time series for {wellName}...</span>
          </div>
        </div>
      )}

      {!loading && rawData.length > 0 && (
        <div className="space-y-0">
          {CHART_TITLES.map((_, idx) => (
            <ReactECharts
              key={idx}
              ref={(el) => { chartRefs.current[idx] = el }}
              option={chartOptions[idx]}
              style={{ height: chartHeights[idx] }}
              notMerge={true}
            />
          ))}
        </div>
      )}

      {!loading && rawData.length === 0 && dataCache.has(wellId) && (
        <div className="flex items-center justify-center h-[200px] text-muted-foreground text-sm">No data available</div>
      )}

      {showAnnotationForm && (
        <div className="fixed inset-0 z-50" onClick={() => setShowAnnotationForm(false)}>
          <div
            className="absolute bg-background border rounded-lg shadow-lg p-4 w-80 space-y-3"
            style={{ left: Math.min(annotationPos.x, window.innerWidth - 340), top: Math.min(annotationPos.y, window.innerHeight - 300) }}
            onClick={e => e.stopPropagation()}
          >
            <div className="font-medium text-sm">Add Annotation</div>
            <div className="text-xs text-muted-foreground">
              {signalLabel(newAnnotation.signal)} at {new Date(newAnnotation.timestamp).toLocaleString()}
            </div>
            <select
              value={newAnnotation.category}
              onChange={e => setNewAnnotation(a => ({ ...a, category: e.target.value }))}
              className="w-full text-sm border rounded px-2 py-1 bg-background"
            >
              <option value="OPERATIONS">Operations</option>
              <option value="DRAWDOWN">Drawdown</option>
              <option value="MAINTENANCE">Maintenance</option>
              <option value="GENERAL">General</option>
            </select>
            <textarea
              value={newAnnotation.text}
              onChange={e => setNewAnnotation(a => ({ ...a, text: e.target.value }))}
              placeholder="Enter note..."
              className="w-full text-sm border rounded px-2 py-1 bg-background h-20 resize-none"
              autoFocus
            />
            <div className="flex justify-end gap-2">
              <button onClick={() => setShowAnnotationForm(false)} className="text-xs px-3 py-1 border rounded hover:bg-muted">Cancel</button>
              <button onClick={saveAnnotation} className="text-xs px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700">Save</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
