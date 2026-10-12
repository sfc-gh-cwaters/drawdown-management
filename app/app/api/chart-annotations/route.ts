import { querySnowflake } from "@/lib/snowflake"
import { appUserSql } from "@/lib/app-user"
import { NextRequest } from "next/server"
export const dynamic = "force-dynamic"

export async function GET(request: NextRequest) {
  const wellId = request.nextUrl.searchParams.get("wellId")
  if (!wellId) return Response.json({ error: "wellId required" }, { status: 400 })

  const safeWellId = wellId.replace(/'/g, "''")
  const rows = await querySnowflake(`
    SELECT TO_VARCHAR(CONVERT_TIMEZONE('UTC', NOTE_TIMESTAMP), 'YYYY-MM-DD"T"HH24:MI:SS".000Z"') AS NOTE_TIMESTAMP,
           NOTE_TEXT, NOTE_CATEGORY,
           NOTE_JSON:signal::VARCHAR AS SIGNAL_NAME,
           CREATE_AUTHOR
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY
    WHERE ASSET_ID = '${safeWellId}'
      AND NOTE_JSON:signal IS NOT NULL
    ORDER BY NOTE_TIMESTAMP
  `)
  return Response.json(rows)
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { wellId, timestamp, noteText, category, signal } = body
    if (!wellId || !timestamp || !noteText || !signal) {
      return Response.json({ error: "wellId, timestamp, noteText, signal required" }, { status: 400 })
    }
    const safeWellId = wellId.replace(/'/g, "''")
    const safeText = noteText.replace(/'/g, "''")
    const safeCat = (category || "OPERATIONS").replace(/'/g, "''")
    const safeSignal = signal.replace(/'/g, "''")

    // Timestamp may be epoch ms (number) or ISO string from ECharts
    let tsExpr: string
    if (typeof timestamp === "number" || /^\d+$/.test(String(timestamp))) {
      tsExpr = `TO_TIMESTAMP_LTZ(${Number(timestamp)} / 1000)`
    } else {
      tsExpr = `'${String(timestamp).replace(/'/g, "''")}'::TIMESTAMP_LTZ`
    }

    // Use INSERT...SELECT to allow PARSE_JSON (not allowed in VALUES clause)
    const author = await appUserSql()
    await querySnowflake(`
      INSERT INTO CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY
        (ASSET_ID, BUSINESS_UNIT, NOTE_TIMESTAMP, NOTE_DATE, NOTE_TEXT, NOTE_CATEGORY, NOTE_JSON, CREATE_AUTHOR, MODIFIED_BY, CREATE_TIMESTAMP, RECORD_SOURCE)
      SELECT '${safeWellId}', 'HAYNESVILLE', ${tsExpr}, ${tsExpr}::DATE,
             '${safeText}', '${safeCat}',
             PARSE_JSON('{"signal":"${safeSignal}"}'),
             ${author}, ${author}, CURRENT_TIMESTAMP(), 'APP_ANNOTATION'
    `)
    return Response.json({ ok: true })
  } catch (e) {
    console.error("[chart-annotations POST]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to save" }, { status: 500 })
  }
}
