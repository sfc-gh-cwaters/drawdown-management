import { querySnowflake } from "@/lib/snowflake"
export const dynamic = "force-dynamic"

export async function GET() {
  try {
    const rows = await querySnowflake(`
      SELECT WELL_ASSET_ID, WELL_NAME, DAILY_EST_DRAWDOWN,
             TUBING_PRESSURE, CASING_PRESSURE, CHOKE_OUTPUT,
             ESD_STATUS, POSITIVE_CHOKE, TARGET_DRAWDOWN_RATE,
             GAS_BUDGET, GAS_ADJ_BUDGET, GAS_FLOW_RATE, GAS_FLOW_YESTERDAY,
             WATER_FLOW_RATE, WATER_FLOW_YESTERDAY,
             COUNTY, STATE, WELL_TYPE, PROCOUNT_AREA, COMP_RESERVOIR
      FROM CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_HEADER
      ORDER BY DAILY_EST_DRAWDOWN DESC NULLS LAST
    `)
    return Response.json(rows)
  } catch (e) {
    console.error(new Date().toISOString(), "[drawdown-status]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to fetch drawdown status" }, { status: 500 })
  }
}
