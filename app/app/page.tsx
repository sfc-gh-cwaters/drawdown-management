import { DrawdownDashboard } from "@/components/drawdown-dashboard"

// Render per request so browsers/proxies never serve a stale prerendered shell after a redeploy
export const dynamic = "force-dynamic"

export default function Page() {
  return (
    <main className="p-6">
      <DrawdownDashboard />
    </main>
  )
}
