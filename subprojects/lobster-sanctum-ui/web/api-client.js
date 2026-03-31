/**
 * api-client.js — 统一 API 请求层（全局脚本版）
 *
 * 功能：
 * - 简单 Map 缓存（TTL 可配，防重复请求）
 * - In-Flight 去重（同一 key 并发只发一个请求）
 * - invalidate() 清除指定前缀缓存（写操作后调用）
 *
 * 参考：clawpanel/src/lib/tauri-api.js 的 _cache / _inflight 设计
 */
(function bootstrapOpenClawApiClient(global) {
  const CACHE_TTL_MS = 15000;
  const _cache = new Map();
  const _inflight = new Map();

  function invalidate(...prefixes) {
    for (const [k] of _cache) {
      if (prefixes.some((p) => k.startsWith(p))) {
        _cache.delete(k);
      }
    }
  }

  async function cachedFetch(url, opts = {}, ttl = CACHE_TTL_MS) {
    const key = `${opts.method || "GET"} ${url}`;
    const cached = _cache.get(key);
    if (cached && Date.now() - cached.ts < ttl) {
      return cached.val;
    }

    if (_inflight.has(key)) {
      return _inflight.get(key);
    }

    const p = fetch(url, opts)
      .then((resp) => {
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        return resp.json();
      })
      .then((val) => {
        _cache.set(key, { val, ts: Date.now() });
        _inflight.delete(key);
        return val;
      })
      .catch((err) => {
        _inflight.delete(key);
        throw err;
      });

    _inflight.set(key, p);
    return p;
  }

  function clearCache() {
    _cache.clear();
  }

  function getCacheStats() {
    return {
      cacheSize: _cache.size,
      inflightSize: _inflight.size,
      keys: [..._cache.keys()],
    };
  }

  global.OpenClawApiClient = {
    cachedFetch,
    invalidate,
    clearCache,
    getCacheStats,
  };
})(window);
