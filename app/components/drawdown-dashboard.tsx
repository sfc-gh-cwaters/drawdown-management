"use client"
import { useEffect, useState, useMemo } from "react"
import { CommentaryPanel } from "./commentary-panel"
import { WellCharts } from "./well-charts"
import { WellAttributes } from "./well-attributes"

interface WellStatus {
  WELL_ASSET_ID: string
  WELL_NAME: string
  DAILY_EST_DRAWDOWN: number | null
  TUBING_PRESSURE: number | null
  CASING_PRESSURE: number | null
  CHOKE_OUTPUT: number | null
  ESD_STATUS: number | null
  POSITIVE_CHOKE: number | null
  TARGET_DRAWDOWN_RATE: number | null
  GAS_BUDGET: number | null
  GAS_ADJ_BUDGET: number | null
  GAS_FLOW_RATE: number | null
  GAS_FLOW_YESTERDAY: number | null
  WATER_FLOW_RATE: number | null
  WATER_FLOW_YESTERDAY: number | null
  COUNTY: string | null
  STATE: string | null
  WELL_TYPE: string | null
  PROCOUNT_AREA: string | null
  COMP_RESERVOIR: string | null
}

export function DrawdownDashboard() {
  const [wells, setWells] = useState<WellStatus[]>([])
  const [selectedWell, setSelectedWell] = useState<WellStatus | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [commentaryKey, setCommentaryKey] = useState(0)

  // Filters
  const [filterCounty, setFilterCounty] = useState<string>("")
  const [filterState, setFilterState] = useState<string>("")
  const [filterWellType, setFilterWellType] = useState<string>("")
  const [filterArea, setFilterArea] = useState<string>("")
  const [filterReservoir, setFilterReservoir] = useState<string>("")
  const [search, setSearch] = useState<string>("")
  const [sortKey, setSortKey] = useState<keyof WellStatus | null>(null)
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc")

  const toggleSort = (key: keyof WellStatus) => {
    if (sortKey === key) setSortDir(d => (d === "asc" ? "desc" : "asc"))
    else { setSortKey(key); setSortDir("asc") }
  }

  useEffect(() => {
    fetch("/api/drawdown-status")
      .then((r) => r.json())
      .then((data) => {
        if (Array.isArray(data)) {
          setWells(data)
        } else if (data?.error) {
          setError(data.error)
        } else {
          setError("Unexpected response from drawdown-status API")
        }
        setLoading(false)
      })
      .catch((err) => {
        setError(`Failed to connect to data source: ${err.message || "Network error"}`)
        setLoading(false)
      })
  }, [])

  // Unique filter values
  const counties = useMemo(() => [...new Set(wells.map(w => w.COUNTY).filter(Boolean))].sort() as string[], [wells])
  const states = useMemo(() => [...new Set(wells.map(w => w.STATE).filter(Boolean))].sort() as string[], [wells])
  const wellTypes = useMemo(() => [...new Set(wells.map(w => w.WELL_TYPE).filter(Boolean))].sort() as string[], [wells])
  const areas = useMemo(() => [...new Set(wells.map(w => w.PROCOUNT_AREA).filter(Boolean))].sort() as string[], [wells])
  const reservoirs = useMemo(() => [...new Set(wells.map(w => w.COMP_RESERVOIR).filter(Boolean))].sort() as string[], [wells])

  // Apply filters
  const filteredWells = useMemo(() => {
    const term = search.trim().toLowerCase()
    const rows = wells.filter(w => {
      if (term && !(w.WELL_NAME || "").toLowerCase().includes(term)) return false
      if (filterCounty && w.COUNTY !== filterCounty) return false
      if (filterState && w.STATE !== filterState) return false
      if (filterWellType && w.WELL_TYPE !== filterWellType) return false
      if (filterArea && w.PROCOUNT_AREA !== filterArea) return false
      if (filterReservoir && w.COMP_RESERVOIR !== filterReservoir) return false
      return true
    })
    if (!sortKey) return rows
    const dir = sortDir === "asc" ? 1 : -1
    return [...rows].sort((a, b) => {
      const av = a[sortKey], bv = b[sortKey]
      if (av == null && bv == null) return 0
      if (av == null) return 1  // nulls always last
      if (bv == null) return -1
      const an = Number(av), bn = Number(bv)
      if (!isNaN(an) && !isNaN(bn) && String(av).trim() !== "" && String(bv).trim() !== "") return (an - bn) * dir
      return String(av).localeCompare(String(bv), undefined, { numeric: true, sensitivity: "base" }) * dir
    })
  }, [wells, search, filterCounty, filterState, filterWellType, filterArea, filterReservoir, sortKey, sortDir])

  const resetFilters = () => { setSearch(""); setFilterCounty(""); setFilterState(""); setFilterWellType(""); setFilterArea(""); setFilterReservoir("") }
  const hasFilters = search || filterCounty || filterState || filterWellType || filterArea || filterReservoir

  const COLUMNS: { k: keyof WellStatus; label: string; right?: boolean }[] = [
    { k: "WELL_NAME", label: "Well" },
    { k: "COUNTY", label: "County" },
    { k: "STATE", label: "State" },
    { k: "WELL_TYPE", label: "Type" },
    { k: "PROCOUNT_AREA", label: "Area" },
    { k: "COMP_RESERVOIR", label: "Reservoir" },
    { k: "TUBING_PRESSURE", label: "THP", right: true },
    { k: "CASING_PRESSURE", label: "CP", right: true },
    { k: "GAS_FLOW_RATE", label: "Gas Rate", right: true },
    { k: "GAS_FLOW_YESTERDAY", label: "Gas Yest", right: true },
    { k: "DAILY_EST_DRAWDOWN", label: "Drawdown", right: true },
    { k: "CHOKE_OUTPUT", label: "Choke", right: true },
  ]

  const fmt = (v: number | null, decimals = 1) => v != null ? v.toFixed(decimals) : "—"
  const fmtInt = (v: number | null) => v != null ? v.toFixed(0) : "—"

  if (loading) return <div className="text-center py-12 text-muted-foreground">Loading well data...</div>

  return (
    <div className="space-y-4">
      {error && (
        <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm">
          <div className="flex items-start gap-2">
            <span className="text-red-600 dark:text-red-400 font-medium shrink-0">Data Access Error</span>
            <span className="text-red-700 dark:text-red-300">{error}</span>
          </div>
          <p className="text-red-600/70 dark:text-red-400/70 text-xs mt-1">Check that required views and functions exist in CYGNET_TRANSFORMATION.APP and that the app service role has SELECT access.</p>
        </div>
      )}
      {!error && wells.length === 0 && (
        <div className="bg-amber-50 dark:bg-amber-950 border border-amber-200 dark:border-amber-800 rounded-lg px-4 py-3 text-sm">
          <span className="text-amber-700 dark:text-amber-300">No wells returned. The drawdown views may be empty or the app may lack access to the required objects in CYGNET_TRANSFORMATION.APP.</span>
        </div>
      )}
      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <input
          type="search"
          value={search}
          onChange={e => setSearch(e.target.value)}
          onInput={e => setSearch((e.target as HTMLInputElement).value)}
          placeholder="Search well name..."
          className="text-sm border rounded px-2 py-1 bg-background w-56"
        />
        <span className="text-sm font-medium">Filters:</span>
        <select value={filterCounty} onChange={e => setFilterCounty(e.target.value)} className="text-sm border rounded px-2 py-1 bg-background">
          <option value="">All Counties</option>
          {counties.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        <select value={filterState} onChange={e => setFilterState(e.target.value)} className="text-sm border rounded px-2 py-1 bg-background">
          <option value="">All States</option>
          {states.map(s => <option key={s} value={s}>{s}</option>)}
        </select>
        <select value={filterWellType} onChange={e => setFilterWellType(e.target.value)} className="text-sm border rounded px-2 py-1 bg-background">
          <option value="">All Well Types</option>
          {wellTypes.map(t => <option key={t} value={t}>{t}</option>)}
        </select>
        <select value={filterArea} onChange={e => setFilterArea(e.target.value)} className="text-sm border rounded px-2 py-1 bg-background">
          <option value="">All Areas</option>
          {areas.map(a => <option key={a} value={a}>{a}</option>)}
        </select>
        <select value={filterReservoir} onChange={e => setFilterReservoir(e.target.value)} className="text-sm border rounded px-2 py-1 bg-background">
          <option value="">All Reservoirs</option>
          {reservoirs.map(r => <option key={r} value={r}>{r}</option>)}
        </select>
        {hasFilters && (
          <button onClick={resetFilters} className="text-xs px-2 py-1 bg-muted rounded hover:bg-muted/80">Reset All</button>
        )}
        <div className="ml-auto text-xs text-muted-foreground">
          {filteredWells.length} of {wells.length} wells
        </div>
      </div>

      {/* Well Status Table */}
      <div className="border rounded-lg overflow-auto max-h-[350px]">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 sticky top-0">
            <tr>
              <th className="w-6 p-2"></th>
              {COLUMNS.map(c => (
                <th
                  key={c.k}
                  onClick={() => toggleSort(c.k)}
                  className={`${c.right ? "text-right" : "text-left"} p-2 font-medium cursor-pointer select-none hover:bg-muted whitespace-nowrap`}
                >
                  {c.label}{sortKey === c.k ? (sortDir === "asc" ? " ▲" : " ▼") : ""}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filteredWells.map((w, i) => (
              <tr
                // WELL_ASSET_ID is not unique: multi-completion wells return one row per reservoir
                key={`${w.WELL_ASSET_ID}|${w.COMP_RESERVOIR ?? ""}|${i}`}
                onClick={() => setSelectedWell(w)}
                className={`cursor-pointer border-t hover:bg-muted/30 transition-colors ${selectedWell?.WELL_ASSET_ID === w.WELL_ASSET_ID ? "bg-blue-50 dark:bg-blue-950" : ""}`}
              >
                <td className="p-2 text-center text-blue-600">{selectedWell?.WELL_ASSET_ID === w.WELL_ASSET_ID ? "▶" : ""}</td>
                <td className="p-2 font-medium whitespace-nowrap">{w.WELL_NAME}</td>
                <td className="p-2 text-xs whitespace-nowrap">{w.COUNTY}</td>
                <td className="p-2 text-xs whitespace-nowrap">{w.STATE}</td>
                <td className="p-2 text-xs whitespace-nowrap">{w.WELL_TYPE}</td>
                <td className="p-2 text-xs whitespace-nowrap">{w.PROCOUNT_AREA}</td>
                <td className="p-2 text-xs whitespace-nowrap">{w.COMP_RESERVOIR}</td>
                <td className="p-2 text-right tabular-nums">{fmtInt(w.TUBING_PRESSURE)}</td>
                <td className="p-2 text-right tabular-nums">{fmtInt(w.CASING_PRESSURE)}</td>
                <td className="p-2 text-right tabular-nums">{fmt(w.GAS_FLOW_RATE)}</td>
                <td className="p-2 text-right tabular-nums">{fmt(w.GAS_FLOW_YESTERDAY)}</td>
                <td className="p-2 text-right tabular-nums">{fmt(w.DAILY_EST_DRAWDOWN)}</td>
                <td className="p-2 text-right tabular-nums">{fmt(w.CHOKE_OUTPUT)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Charts */}
      {selectedWell && (
        <WellCharts wellId={selectedWell.WELL_ASSET_ID} wellName={selectedWell.WELL_NAME} onAnnotationSaved={() => setCommentaryKey(k => k + 1)} />
      )}

      {/* Commentary */}
      {selectedWell && (
        <CommentaryPanel wellId={selectedWell.WELL_ASSET_ID} wellName={selectedWell.WELL_NAME} refreshKey={commentaryKey} />
      )}

      {/* Well Attributes */}
      {selectedWell && (
        <WellAttributes wellId={selectedWell.WELL_ASSET_ID} wellName={selectedWell.WELL_NAME} />
      )}
    </div>
  )
}
