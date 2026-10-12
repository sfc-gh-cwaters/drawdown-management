import { querySnowflake } from "@/lib/snowflake"
import { NextRequest } from "next/server"
export const dynamic = "force-dynamic"

export async function GET(request: NextRequest) {
  const wellId = request.nextUrl.searchParams.get("wellId")
  if (!wellId) return Response.json({ error: "wellId required" }, { status: 400 })

  try {
    const rows = await querySnowflake(`
      SELECT WELL_ASSET_ID, COUNTY, LEGAL_WELL_NAME, PROCOUNT_AREA, STATE,
             TOWNSHIP, RANGE, WELL_NAME, WELL_TYPE, STATUS,
             COMP_BOTTOM_PERF_MD, COMP_BOTTOM_PERF_TVD, COMP_RESERVOIR,
             COMP_PRIMARY_FUND_WI, COMP_ACTENUM_AREA, COMP_ACTENUM_SUB_AREA,
             COMP_FRAC_END_DATE, COMP_FRAC_START_DATE, SPUD_DATE, RIG_RELEASE_DATE
      FROM CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_MASTER
      WHERE WELL_ASSET_ID = '${wellId.replace(/'/g, "''")}'
    `)
    return Response.json(rows)
  } catch (e) {
    console.error(new Date().toISOString(), "[well-attributes]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to fetch attributes" }, { status: 500 })
  }
}
