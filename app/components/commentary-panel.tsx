"use client"
import { useEffect, useState, useCallback } from "react"

interface Commentary {
  ASSET_ID: string
  NOTE_TIMESTAMP: string
  NOTE_DATE: string
  NOTE_TEXT: string
  NOTE_CATEGORY: string
  MODIFIED_BY: string | null
  CREATE_AUTHOR: string | null
  CREATE_TIMESTAMP: string
  SIGNAL_NAME: string | null
}

const SIGNAL_LABELS: Record<string, string> = {
  GAS_RATE: "Gas Rate", WATER_RATE: "Water Rate", THP: "THP",
  DRAWDOWN: "Drawdown", POSITIVE_CHOKE: "Pos Choke", AUTO_CHOKE: "Auto Choke",
}

const CATEGORIES = ["DRAWDOWN", "OPERATIONS", "MAINTENANCE", "GENERAL"]

export function CommentaryPanel({ wellId, wellName, refreshKey }: { wellId: string; wellName: string; refreshKey?: number }) {
  const [comments, setComments] = useState<Commentary[]>([])
  const [commentError, setCommentError] = useState<string | null>(null)
  const [selected, setSelected] = useState<Commentary | null>(null)
  const [noteText, setNoteText] = useState("")
  const [noteCategory, setNoteCategory] = useState("DRAWDOWN")
  const [isNew, setIsNew] = useState(false)
  const [saving, setSaving] = useState(false)

  const loadComments = useCallback(() => {
    fetch(`/api/commentary?wellId=${encodeURIComponent(wellId)}`)
      .then((r) => r.json())
      .then((data) => {
        if (Array.isArray(data)) { setComments(data); setCommentError(null) }
        else if (data?.error) setCommentError(data.error)
      })
      .catch(err => setCommentError(`Failed to load commentary: ${err.message || "Network error"}`))
  }, [wellId])

  useEffect(() => {
    loadComments()
    setSelected(null)
    setIsNew(false)
    setNoteText("")
    setNoteCategory("DRAWDOWN")
  }, [wellId, loadComments])

  useEffect(() => {
    if (refreshKey !== undefined) loadComments()
  }, [refreshKey, loadComments])

  const handleSelect = (c: Commentary) => {
    setSelected(c)
    setNoteText(c.NOTE_TEXT)
    setNoteCategory(c.NOTE_CATEGORY)
    setIsNew(false)
  }

  const handleNew = () => {
    setSelected(null)
    setIsNew(true)
    setNoteText("")
    setNoteCategory("DRAWDOWN")
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      if (isNew) {
        await fetch("/api/commentary", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ wellId, noteText, noteCategory }),
        })
      } else if (selected) {
        await fetch("/api/commentary", {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ wellId, noteTimestamp: selected.NOTE_TIMESTAMP, noteText, noteCategory }),
        })
      }
      loadComments()
      setIsNew(false)
      setSelected(null)
      setNoteText("")
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (!selected) return
    if (!confirm("Delete this comment?")) return
    setSaving(true)
    try {
      await fetch("/api/commentary", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ wellId, noteTimestamp: selected.NOTE_TIMESTAMP }),
      })
      loadComments()
      setSelected(null)
      setNoteText("")
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="border rounded-lg p-4 space-y-4">
      <h3 className="font-semibold">Commentary — {wellName}</h3>

      {commentError && (
        <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded px-3 py-2 text-sm text-red-700 dark:text-red-300">
          <span className="font-medium">Error:</span> {commentError}
        </div>
      )}

      <div className="border rounded overflow-auto max-h-[200px]">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 sticky top-0">
            <tr>
              <th className="text-left p-2 font-medium">Timestamp</th>
              <th className="text-left p-2 font-medium">Category</th>
              <th className="text-left p-2 font-medium">Signal</th>
              <th className="text-left p-2 font-medium">Note</th>
              <th className="text-left p-2 font-medium">Author</th>
            </tr>
          </thead>
          <tbody>
            {comments.map((c) => (
              <tr
                key={c.NOTE_TIMESTAMP}
                onClick={() => handleSelect(c)}
                className={`cursor-pointer border-t hover:bg-muted/30 ${selected?.NOTE_TIMESTAMP === c.NOTE_TIMESTAMP ? "bg-muted/50" : ""}`}
              >
                <td className="p-2 whitespace-nowrap text-xs">{new Date(c.NOTE_TIMESTAMP).toLocaleString()}</td>
                <td className="p-2">{c.NOTE_CATEGORY}</td>
                <td className="p-2 text-xs text-muted-foreground">{c.SIGNAL_NAME ? (SIGNAL_LABELS[c.SIGNAL_NAME] || c.SIGNAL_NAME) : '—'}</td>
                <td className="p-2 truncate max-w-[350px]">{c.NOTE_TEXT}</td>
                <td
                  className="p-2 text-xs whitespace-nowrap text-muted-foreground"
                  title={c.MODIFIED_BY && c.MODIFIED_BY !== c.CREATE_AUTHOR ? `Last edited by ${c.MODIFIED_BY}` : undefined}
                >
                  {c.CREATE_AUTHOR || "—"}
                  {c.MODIFIED_BY && c.MODIFIED_BY !== c.CREATE_AUTHOR ? " (edited)" : ""}
                </td>
              </tr>
            ))}
            {comments.length === 0 && (
              <tr><td colSpan={5} className="p-4 text-center text-muted-foreground">No commentary for this well</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="flex gap-2">
        <button onClick={handleNew} className="px-3 py-1.5 text-sm bg-primary text-primary-foreground rounded hover:bg-primary/90">New</button>
        <button onClick={handleSave} disabled={saving || (!isNew && !selected)} className="px-3 py-1.5 text-sm bg-primary text-primary-foreground rounded hover:bg-primary/90 disabled:opacity-50">Save</button>
        <button onClick={handleDelete} disabled={saving || !selected} className="px-3 py-1.5 text-sm bg-destructive text-destructive-foreground rounded hover:bg-destructive/90 disabled:opacity-50">Delete</button>
      </div>

      {(isNew || selected) && (
        <div className="space-y-3 border-t pt-3">
          <div>
            <label className="text-sm font-medium block mb-1">Category</label>
            <select
              value={noteCategory}
              onChange={(e) => setNoteCategory(e.target.value)}
              className="w-full border rounded px-3 py-2 text-sm bg-background"
            >
              {CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium block mb-1">Note</label>
            <textarea
              value={noteText}
              onChange={(e) => setNoteText(e.target.value)}
              rows={4}
              className="w-full border rounded px-3 py-2 text-sm bg-background resize-y"
              placeholder="Enter commentary..."
            />
          </div>
        </div>
      )}
    </div>
  )
}
