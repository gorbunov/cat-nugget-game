// Static assets handle all ordinary files. Only the oversized Godot engine uses
// this handler: pass through its precompressed bytes without double compression.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== "/index.wasm" || !["GET", "HEAD"].includes(request.method)) {
      return env.ASSETS.fetch(request);
    }
    url.pathname = "/index.wasm.gz";
    const asset = await env.ASSETS.fetch(new Request(url, {
      method: request.method,
      headers: { "Accept-Encoding": "identity" },
    }));
    if (!asset.ok) return asset;
    const headers = new Headers(asset.headers);
    headers.set("Content-Type", "application/wasm");
    headers.set("Content-Encoding", "gzip");
    headers.set("Cache-Control", "public, max-age=0, must-revalidate");
    return new Response(asset.body, {
      status: asset.status,
      headers,
      encodeBody: "manual",
    });
  },
};
