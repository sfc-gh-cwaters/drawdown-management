import { headers } from "next/headers"

/**
 * Snowflake login name of the user who opened the app.
 *
 * Snowflake ingress adds `Sf-Context-Current-User` to every request it routes to the app.
 * Queries run with the app's owner role, so CURRENT_USER() would return the service user;
 * use this value when recording who wrote something. Returns null outside SPCS (local dev).
 */
export async function getAppUser(): Promise<string | null> {
  const user = (await headers()).get("sf-context-current-user")
  return user && user.trim() ? user.trim() : null
}

/** SQL expression for the app user: a quoted literal, or CURRENT_USER() when unknown. */
export async function appUserSql(): Promise<string> {
  const user = await getAppUser()
  return user ? `'${user.replace(/'/g, "''")}'` : "CURRENT_USER()"
}
