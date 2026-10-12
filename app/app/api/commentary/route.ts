import { querySnowflake } from "@/lib/snowflake"
import { appUserSql } from "@/lib/app-user"
import { NextRequest } from "next/server"
export const dynamic = "force-dynamic"

export async function GET(request: NextRequest) {
  const wellId = request.nextUrl.searchParams.get("wellId")
  if (!wellId) return Response.json({ error: "wellId required" }, { status: 400 })

  try {
    const rows = await querySnowflake(`
      SELECT ASSET_ID, NOTE_TIMESTAMP, NOTE_DATE, NOTE_TEXT, NOTE_CATEGORY, MODIFIED_BY, CREATE_AUTHOR, CREATE_TIMESTAMP,
             NOTE_JSON:signal::VARCHAR AS SIGNAL_NAME
      FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY
      WHERE ASSET_ID = '${wellId.replace(/'/g, "''")}'
      ORDER BY NOTE_TIMESTAMP DESC
    `)
    return Response.json(rows)
  } catch (e) {
    console.error(new Date().toISOString(), "[commentary-get]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to fetch commentary" }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { wellId, noteText, noteCategory } = body
    if (!wellId || !noteText || !noteCategory) {
      return Response.json({ error: "wellId, noteText, noteCategory required" }, { status: 400 })
    }
    const author = await appUserSql()
    await querySnowflake(`
      INSERT INTO CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY (BUSINESS_UNIT, ASSET_ID, NOTE_TIMESTAMP, NOTE_DATE, NOTE_TEXT, NOTE_CATEGORY, RECORD_SOURCE, CREATE_AUTHOR, MODIFIED_BY, CREATE_TIMESTAMP)
      SELECT a.BUSINESS_UNIT, '${wellId.replace(/'/g, "''")}', CURRENT_TIMESTAMP(), CURRENT_DATE(),
             '${noteText.replace(/'/g, "''")}', '${noteCategory.replace(/'/g, "''")}', 'DRAWDOWN_APP', ${author}, ${author}, CURRENT_TIMESTAMP()
      FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET a WHERE a.ASSET_ID = '${wellId.replace(/'/g, "''")}'
    `)
    return Response.json({ success: true })
  } catch (e) {
    console.error(new Date().toISOString(), "[commentary-post]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to create commentary" }, { status: 500 })
  }
}

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json()
    const { wellId, noteTimestamp, noteText, noteCategory } = body
    if (!wellId || !noteTimestamp || !noteText || !noteCategory) {
      return Response.json({ error: "wellId, noteTimestamp, noteText, noteCategory required" }, { status: 400 })
    }
    const editor = await appUserSql()
    await querySnowflake(`
      UPDATE CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY
      SET NOTE_TEXT = '${noteText.replace(/'/g, "''")}',
          NOTE_CATEGORY = '${noteCategory.replace(/'/g, "''")}',
          MODIFIED_BY = ${editor},
          UPDATE_TIMESTAMP = CURRENT_TIMESTAMP()
      WHERE ASSET_ID = '${wellId.replace(/'/g, "''")}'
        AND NOTE_TIMESTAMP = '${String(noteTimestamp).replace(/'/g, "''")}'::TIMESTAMP_LTZ
    `)
    return Response.json({ success: true })
  } catch (e) {
    console.error(new Date().toISOString(), "[commentary-put]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to update commentary" }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const body = await request.json()
    const { wellId, noteTimestamp } = body
    if (!wellId || !noteTimestamp) {
      return Response.json({ error: "wellId, noteTimestamp required" }, { status: 400 })
    }
    await querySnowflake(`
      DELETE FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY
      WHERE ASSET_ID = '${wellId.replace(/'/g, "''")}'
        AND NOTE_TIMESTAMP = '${String(noteTimestamp).replace(/'/g, "''")}'::TIMESTAMP_LTZ
    `)
    return Response.json({ success: true })
  } catch (e) {
    console.error(new Date().toISOString(), "[commentary-delete]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to delete commentary" }, { status: 500 })
  }
}
