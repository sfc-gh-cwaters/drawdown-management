// Writes build-info.json with the git commit this build comes from.
//
// `snow app deploy` builds inside Snowflake, where there is no .git, so the
// file must be generated locally before upload (`npm run deploy` does this).
// When git is unavailable (the server-side build), an existing file is kept
// as-is so the uploaded commit info survives the remote `npm run build`.

import { execFileSync } from "node:child_process"
import { existsSync, writeFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const appDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const outFile = path.join(appDir, "build-info.json")

function git(...args) {
  return execFileSync("git", args, { cwd: appDir, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim()
}

let info
try {
  const commit = git("rev-parse", "HEAD")
  info = {
    commit,
    shortCommit: commit.slice(0, 7),
    branch: git("rev-parse", "--abbrev-ref", "HEAD"),
    // Uncommitted changes under app/ mean the build is not exactly `commit`.
    dirty: git("status", "--porcelain", "--", ".").length > 0,
    commitDate: git("log", "-1", "--format=%cI"),
    builtAt: new Date().toISOString(),
  }
} catch {
  if (existsSync(outFile)) {
    console.log("build-info: git unavailable, keeping existing build-info.json")
    process.exit(0)
  }
  info = { commit: "unknown", shortCommit: "unknown", branch: "unknown", dirty: false, commitDate: null, builtAt: new Date().toISOString() }
}

writeFileSync(outFile, JSON.stringify(info, null, 2) + "\n")
console.log(`build-info: ${info.shortCommit}${info.dirty ? " (dirty)" : ""}`)
