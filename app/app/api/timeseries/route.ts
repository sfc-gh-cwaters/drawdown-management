import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { NextRequest } from "next/server"
export const dynamic = "force-dynamic"

export async function GET(request: NextRequest) {
  const wellId = request.nextUrl.searchParams.get("wellId")
  const startDate = request.nextUrl.searchParams.get("startDate")
  const endDate = request.nextUrl.searchParams.get("endDate")
  const maxPoints = parseInt(request.nextUrl.searchParams.get("maxPoints") ?? "1000")
  if (!wellId || !startDate || !endDate) {
    return Response.json({ error: "wellId, startDate, endDate required" }, { status: 400 })
  }

  const datePattern = /^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}(:\d{2})?)?$/
  if (!datePattern.test(startDate) || !datePattern.test(endDate) || !Number.isInteger(maxPoints) || maxPoints < 3) {
    return Response.json({ error: "invalid startDate, endDate or maxPoints" }, { status: 400 })
  }

  const safeWellId = wellId.replace(/'/g, "''")

  try {
    const rows = await querySnowflakeLongRunning(`
      SELECT WELL_ASSET_ID, ATTR_ID, TIMESTAMP_CENTRAL, VALUE_NUMBER
      FROM TABLE(CYGNET_TRANSFORMATION.APP.FN_DRAWDOWN_WELL_VALUES_LTTB(
        '${startDate}'::TIMESTAMP_NTZ,
        '${endDate}'::TIMESTAMP_NTZ,
        '${safeWellId}',
        ${maxPoints}
      ))
      -- The function's DAILY_EST_DRAWDOWN branch ignores P_WELL_ASSET_ID, so filter here
      WHERE WELL_ASSET_ID = '${safeWellId}'
      ORDER BY ATTR_ID, TIMESTAMP_CENTRAL
    `)
    return Response.json(rows)
  } catch (e) {
    console.error(new Date().toISOString(), "[timeseries]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to fetch time series" }, { status: 500 })
  }
}
