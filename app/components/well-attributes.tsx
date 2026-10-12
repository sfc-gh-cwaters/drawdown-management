"use client"
import { useEffect, useState, useCallback } from "react"

interface WellMaster {
  WELL_ASSET_ID: string
  COUNTY: string | null
  LEGAL_WELL_NAME: string | null
  PROCOUNT_AREA: string | null
  STATE: string | null
  TOWNSHIP: string | null
  RANGE: string | null
  WELL_NAME: string | null
  WELL_TYPE: string | null
  STATUS: string | null
  COMP_BOTTOM_PERF_MD: number | null
  COMP_BOTTOM_PERF_TVD: number | null
  COMP_RESERVOIR: string | null
  COMP_PRIMARY_FUND_WI: number | null
  COMP_ACTENUM_AREA: string | null
  COMP_ACTENUM_SUB_AREA: string | null
  COMP_FRAC_END_DATE: string | null
  COMP_FRAC_START_DATE: string | null
  SPUD_DATE: string | null
  RIG_RELEASE_DATE: string | null
}

const LOCATION_FIELDS: { key: keyof WellMaster; label: string }[] = [
  { key: "COUNTY", label: "County" },
  { key: "STATE", label: "State" },
  { key: "TOWNSHIP", label: "Township" },
  { key: "RANGE", label: "Range" },
  { key: "PROCOUNT_AREA", label: "Procount Area" },
]

const WELL_FIELDS: { key: keyof WellMaster; label: string }[] = [
  { key: "LEGAL_WELL_NAME", label: "Legal Well Name" },
  { key: "WELL_TYPE", label: "Well Type" },
  { key: "STATUS", label: "Status" },
  { key: "SPUD_DATE", label: "Spud Date" },
  { key: "RIG_RELEASE_DATE", label: "Rig Release Date" },
]

const COMPLETION_FIELDS: { key: keyof WellMaster; label: string }[] = [
  { key: "COMP_RESERVOIR", label: "Reservoir" },
  { key: "COMP_BOTTOM_PERF_MD", label: "Bottom Perf MD" },
  { key: "COMP_BOTTOM_PERF_TVD", label: "Bottom Perf TVD" },
  { key: "COMP_PRIMARY_FUND_WI", label: "Primary Fund WI" },
  { key: "COMP_ACTENUM_AREA", label: "Actenum Area" },
  { key: "COMP_ACTENUM_SUB_AREA", label: "Actenum Sub Area" },
  { key: "COMP_FRAC_START_DATE", label: "Frac Start Date" },
  { key: "COMP_FRAC_END_DATE", label: "Frac End Date" },
]

const attrsCache = new Map<string, WellMaster>()

function formatValue(v: any): string {
  if (v == null || v === "*N/A") return "—"
  if (typeof v === "number") return v.toLocaleString(undefined, { maximumFractionDigits: 2 })
  if (typeof v === "string" && v.match(/^\d{4}-\d{2}-\d{2}T/)) return new Date(v).toLocaleDateString()
  return String(v)
}

export function WellAttributes({ wellId, wellName }: { wellId: string; wellName: string }) {
  const [well, setWell] = useState<WellMaster | null>(null)
  const [error, setError] = useState<string | null>(null)

  const loadAttrs = useCallback(() => {
    setError(null)
    if (attrsCache.has(wellId)) { setWell(attrsCache.get(wellId)!); return }
    fetch(`/api/well-attributes?wellId=${encodeURIComponent(wellId)}`)
      .then(r => r.json())
      .then(data => {
        if (Array.isArray(data) && data.length > 0) {
          attrsCache.set(wellId, data[0])
          setWell(data[0])
        } else if (data?.error) {
          setError(data.error)
        }
      })
      .catch(err => setError(`Failed to load attributes: ${err.message || "Network error"}`))
  }, [wellId])

  useEffect(() => { setWell(null); loadAttrs() }, [wellId, loadAttrs])

  if (error) return (
    <div className="border border-red-200 dark:border-red-800 rounded-lg p-4">
      <h3 className="font-semibold mb-2">Well Attributes — {wellName}</h3>
      <div className="bg-red-50 dark:bg-red-950 rounded px-3 py-2 text-sm text-red-700 dark:text-red-300">
        <span className="font-medium">Error:</span> {error}
      </div>
    </div>
  )
  if (!well) return null

  const renderSection = (title: string, fields: { key: keyof WellMaster; label: string }[]) => (
    <div>
      <div className="text-xs font-medium text-muted-foreground uppercase tracking-wide border-b pb-1 mb-1">{title}</div>
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-x-4 gap-y-0.5 text-sm">
        {fields.map(f => (
          <div key={f.key} className="flex items-baseline gap-1">
            <span className="text-muted-foreground text-xs">{f.label}:</span>
            <span className="font-medium tabular-nums">{formatValue(well[f.key])}</span>
          </div>
        ))}
      </div>
    </div>
  )

  return (
    <div className="border rounded-lg p-4">
      <h3 className="font-semibold mb-3">Well Attributes — {wellName}</h3>
      <div className="space-y-3">
        {renderSection("Location", LOCATION_FIELDS)}
        {renderSection("Well Info", WELL_FIELDS)}
        {renderSection("Completion", COMPLETION_FIELDS)}
      </div>
    </div>
  )
}
