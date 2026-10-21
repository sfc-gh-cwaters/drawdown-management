import { BUILD_INFO } from "@/lib/build-info"

export async function GET() {
  return Response.json(BUILD_INFO)
}
