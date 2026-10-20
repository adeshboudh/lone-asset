// SPDX-License-Identifier: MIT
// Cloudflare Pages advanced-mode worker.
//
// The engine (index.wasm) is larger than Cloudflare Pages' 25 MiB per-file limit, so only its
// Brotli-precompressed copy (index.wasm.br) is deployed. This worker serves that copy at the
// original path with Content-Encoding: br; the browser decompresses it transparently.
// Every other request is a normal static asset.

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		if (!url.pathname.endsWith(".wasm")) {
			return env.ASSETS.fetch(request);
		}

		// Plain request (no Accept-Encoding) so the asset server returns the raw .br bytes.
		const asset = await env.ASSETS.fetch(new URL(`${url.pathname}.br`, url));
		if (!asset.ok) {
			return asset;
		}

		const headers = new Headers(asset.headers);
		headers.set("Content-Type", "application/wasm");
		headers.set("Content-Encoding", "br");
		headers.set("Cache-Control", "public, max-age=300, must-revalidate");
		headers.delete("Content-Length");
		return new Response(asset.body, { status: 200, headers, encodeBody: "manual" });
	},
};
