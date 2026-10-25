const path = require('path');
const fs = require('fs').promises;

let PNG = null;
try {
    PNG = require('pngjs').PNG;
} catch (e) {
    const msg = e && e.message ? e.message : String(e);
    console.error(`[uz_mugshot] FATAL: pngjs module failed to load. Run 'npm install' in the resource directory. Original error: ${msg}`);
}

const RESOURCE_ROOT = path.resolve(GetResourcePath(GetCurrentResourceName()));

function resolveWithinResource(relativePath) {
    const full = path.resolve(RESOURCE_ROOT, relativePath);
    if (full !== RESOURCE_ROOT && !full.startsWith(RESOURCE_ROOT + path.sep)) {
        return null;
    }
    return full;
}

async function exists(full) {
    try {
        await fs.access(full);
        return true;
    } catch (_) {
        return false;
    }
}

// temp file + rename so readers never see a half-written file
let tmpSeq = 0;
async function writeFileAtomic(full, data, encoding) {
    await fs.mkdir(path.dirname(full), { recursive: true });
    const tmp = `${full}.${process.pid}.${++tmpSeq}.tmp`;
    try {
        await fs.writeFile(tmp, data, encoding);
        await fs.rename(tmp, full);
    } catch (e) {
        fs.unlink(tmp).catch(() => {});
        throw e;
    }
}

// old layout: shots/<cid>_<variant>.<ext>
const LAYOUT_RE = /^shots\/([^/]+)\/([^/]+)\.(png|fp)$/;

function legacyPathFor(relativePath) {
    const m = LAYOUT_RE.exec(relativePath);
    return m ? `shots/${m[1]}_${m[2]}.${m[3]}` : null;
}

// Move an old-layout photo + .fp into the cid folder on first read (.fp first).
async function migrateLegacy(pngRelativePath) {
    const fpRelativePath = pngRelativePath.replace(/\.png$/, '.fp');
    for (const rel of [fpRelativePath, pngRelativePath]) {
        const legacyRel = legacyPathFor(rel);
        const full = resolveWithinResource(rel);
        const legacyFull = legacyRel && resolveWithinResource(legacyRel);
        if (!full || !legacyFull) continue;
        if (await exists(full) || !(await exists(legacyFull))) continue;
        try {
            await fs.mkdir(path.dirname(full), { recursive: true });
            await fs.rename(legacyFull, full);
        } catch (_) {}
    }
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

// size from IHDR so huge images are rejected before pngjs allocates them
function readPngSize(buffer) {
    if (buffer.length < 24 || !buffer.subarray(0, 8).equals(PNG_SIGNATURE)) return null;
    if (buffer.toString('latin1', 12, 16) !== 'IHDR') return null;
    return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function decodePng(buffer) {
    return new Promise((resolve, reject) => {
        try {
            resolve(PNG.sync.read(buffer));
        } catch (e) {
            reject(e);
        }
    });
}

function encodePng(png) {
    return PNG.sync.write(png, { deflateLevel: 3 });
}

function cropResize(png, targetW, targetH) {
    const srcW = png.width;
    const srcH = png.height;
    if (!targetW || !targetH) return png;
    if (srcW === targetW && srcH === targetH) return png;

    const targetAspect = targetW / targetH;
    const srcAspect = srcW / srcH;

    let cropW, cropH, cropX, cropY;
    if (srcAspect > targetAspect) {
        cropH = srcH;
        cropW = Math.round(srcH * targetAspect);
        cropX = Math.round((srcW - cropW) / 2);
        cropY = 0;
    } else {
        cropW = srcW;
        cropH = Math.round(srcW / targetAspect);
        cropX = 0;
        cropY = Math.round((srcH - cropH) / 2);
    }

    const dst = new PNG({ width: targetW, height: targetH });
    const src = png.data;
    const dstData = dst.data;

    for (let y = 0; y < targetH; y++) {
        const srcY = cropY + (y * cropH) / targetH;
        const y0 = Math.floor(srcY);
        const y1 = Math.min(y0 + 1, cropY + cropH - 1);
        const fy = srcY - y0;
        for (let x = 0; x < targetW; x++) {
            const srcX = cropX + (x * cropW) / targetW;
            const x0 = Math.floor(srcX);
            const x1 = Math.min(x0 + 1, cropX + cropW - 1);
            const fx = srcX - x0;

            const i00 = (y0 * srcW + x0) * 4;
            const i01 = (y0 * srcW + x1) * 4;
            const i10 = (y1 * srcW + x0) * 4;
            const i11 = (y1 * srcW + x1) * 4;
            const dIdx = (y * targetW + x) * 4;

            for (let c = 0; c < 4; c++) {
                const top = src[i00 + c] * (1 - fx) + src[i01 + c] * fx;
                const bot = src[i10 + c] * (1 - fx) + src[i11 + c] * fx;
                dstData[dIdx + c] = Math.round(top * (1 - fy) + bot * fy);
            }
        }
    }
    return dst;
}

// Distance-to-magenta key. Despill and soften only touch the feather band, so
// purple/pink clothing stays opaque.
function processChroma(png, options) {
    const opts = options || {};
    const threshold = opts.threshold != null ? opts.threshold : 60;
    const featherRange = Math.max(1, (opts.feather != null ? opts.feather : 2) * 20);
    const matteRadius = Math.max(0, Math.floor(opts.matteSoftenRadius != null ? opts.matteSoftenRadius : 1));

    const d = png.data;
    const w = png.width;
    const h = png.height;
    const band = [];

    for (let p = 0, i = 0; p < w * h; p++, i += 4) {
        const r = d[i], g = d[i + 1], b = d[i + 2];
        const dr = 255 - r;
        const db = 255 - b;
        const dist = Math.sqrt(dr * dr + g * g + db * db);

        if (dist >= threshold + featherRange) continue;
        if (dist < threshold) {
            d[i + 3] = 0;
            continue;
        }

        const a = (d[i + 3] * (dist - threshold) / featherRange + 0.5) | 0;
        d[i + 3] = a;
        if (a === 0 || a === 255) continue;

        band.push(p);
        // Despill scaled by transparency: pull R and B toward G.
        const k = 1 - a / 255;
        if (r > g) d[i] = (r - (r - g) * k + 0.5) | 0;
        if (b > g) d[i + 2] = (b - (b - g) * k + 0.5) | 0;
    }

    if (matteRadius >= 1 && band.length > 0) {
        const kernelArea = (matteRadius * 2 + 1) * (matteRadius * 2 + 1);
        const src = new Uint8Array(w * h);

        for (let pass = 0; pass < 2; pass++) {
            for (let p = 0; p < w * h; p++) src[p] = d[(p << 2) + 3];

            for (const p of band) {
                const x = p % w;
                const y = (p - x) / w;
                let sum = 0;
                for (let ky = -matteRadius; ky <= matteRadius; ky++) {
                    const yy = Math.min(h - 1, Math.max(0, y + ky)) * w;
                    for (let kx = -matteRadius; kx <= matteRadius; kx++) {
                        sum += src[yy + Math.min(w - 1, Math.max(0, x + kx))];
                    }
                }
                d[(p << 2) + 3] = (sum / kernelArea + 0.5) | 0;
            }
        }
    }

    return png;
}

// How far a colour leans toward magenta: R and B both above G.
const magentaExcess = (r, g, b) => Math.min(r, b) - g;

// The resize leaves a magenta tint on the outermost opaque pixels. Fit each one
// as fg*t + magenta*(1-t) against its interior neighbours; if nothing fits,
// just remove the extra magenta.
function unmixEdges(png, maxResidual) {
    const d = png.data;
    const w = png.width;
    const h = png.height;
    const maxRes2 = maxResidual * maxResidual;

    // 0 = not opaque, 1 = opaque next to a non-opaque pixel, 2 = interior.
    const depth = new Uint8Array(w * h);
    for (let p = 0; p < w * h; p++) depth[p] = d[(p << 2) + 3] === 255 ? 2 : 0;
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const p = y * w + x;
            if (depth[p] !== 2) continue;
            const y0 = Math.max(0, y - 1), y1 = Math.min(h - 1, y + 1);
            const x0 = Math.max(0, x - 1), x1 = Math.min(w - 1, x + 1);
            for (let yy = y0; yy <= y1 && depth[p] === 2; yy++) {
                for (let xx = x0; xx <= x1; xx++) {
                    if (d[((yy * w + xx) << 2) + 3] !== 255) { depth[p] = 1; break; }
                }
            }
        }
    }

    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const p = y * w + x;
            if (depth[p] !== 1) continue;
            const i = p << 2;
            const cr = d[i] - 255, cg = d[i + 1], cb = d[i + 2] - 255;

            let bestRes = Infinity, bestT = 1, bestJ = -1, clean = false;
            let maxExcess = -Infinity;
            const y0 = Math.max(0, y - 2), y1 = Math.min(h - 1, y + 2);
            const x0 = Math.max(0, x - 2), x1 = Math.min(w - 1, x + 2);
            for (let yy = y0; yy <= y1 && !clean; yy++) {
                for (let xx = x0; xx <= x1; xx++) {
                    const q = yy * w + xx;
                    if (depth[q] !== 2) continue;
                    const j = q << 2;
                    const ex = magentaExcess(d[j], d[j + 1], d[j + 2]);
                    if (ex > maxExcess) maxExcess = ex;
                    const vr = d[j] - 255, vg = d[j + 1], vb = d[j + 2] - 255;
                    const vv = vr * vr + vg * vg + vb * vb;
                    // skip neighbours that are near magenta themselves
                    if (vv < 3600) continue;
                    let t = (cr * vr + cg * vg + cb * vb) / vv;
                    if (t > 1) t = 1; else if (t < 0) t = 0;
                    const er = cr - t * vr, eg = cg - t * vg, eb = cb - t * vb;
                    const res = er * er + eg * eg + eb * eb;
                    if (res > maxRes2) continue;
                    if (t >= 0.95) { clean = true; break; }
                    if (res < bestRes) { bestRes = res; bestT = t; bestJ = j; }
                }
            }
            if (clean || maxExcess === -Infinity) continue;

            if (bestJ < 0) {
                const spill = magentaExcess(d[i], d[i + 1], d[i + 2]) - maxExcess;
                if (spill > 0) {
                    d[i] = Math.max(0, d[i] - spill);
                    d[i + 2] = Math.max(0, d[i + 2] - spill);
                }
                continue;
            }

            d[i] = d[bestJ];
            d[i + 1] = d[bestJ + 1];
            d[i + 2] = d[bestJ + 2];
            d[i + 3] = (bestT * 255 + 0.5) | 0;
        }
    }
    return png;
}

function stripDataUri(b64) {
    if (typeof b64 !== 'string') return b64;
    const comma = b64.indexOf(',');
    if (b64.startsWith('data:') && comma !== -1) {
        return b64.slice(comma + 1);
    }
    return b64;
}

exports('ProcessImage', (base64PngIn, options, savePath, callback) => {
    if (typeof savePath === 'function' && callback === undefined) {
        callback = savePath;
        savePath = null;
    }
    if (!PNG) {
        callback('pngjs_unavailable', null);
        return;
    }
    (async () => {
        try {
            const opts = options || {};
            const clean = stripDataUri(base64PngIn);
            if (typeof clean !== 'string' || (opts.maxBase64Length && clean.length > opts.maxBase64Length)) {
                callback('input_too_large', null);
                return;
            }
            const input = Buffer.from(clean, 'base64');
            if (!input || input.length === 0) {
                callback('empty_input', null);
                return;
            }
            const size = readPngSize(input);
            if (!size) {
                callback('not_png', null);
                return;
            }
            if (size.width < 1 || size.height < 1
                || (opts.maxWidth && size.width > opts.maxWidth)
                || (opts.maxHeight && size.height > opts.maxHeight)
                || (opts.maxPixels && size.width * size.height > opts.maxPixels)) {
                callback(`dimensions_rejected_${size.width}x${size.height}`, null);
                return;
            }
            const png = await decodePng(input);
            // Crop/resize first: keying 512x512 instead of the full screenshot.
            const resized = cropResize(png, opts.outputWidth, opts.outputHeight);
            processChroma(resized, opts);
            if (opts.edgeResidual > 0) unmixEdges(resized, opts.edgeResidual);
            const outBuf = encodePng(resized);

            if (savePath) {
                const full = resolveWithinResource(savePath);
                if (!full) {
                    callback('path_traversal', null);
                    return;
                }
                await writeFileAtomic(full, outBuf);
                if (opts.saveRaw) await writeFileAtomic(full.replace(/\.png$/, '.raw.png'), input);
            }

            callback(null, outBuf.toString('base64'));
        } catch (e) {
            callback(String(e && e.message ? e.message : e), null);
        }
    })();
});

exports('EncodePhoto', (relativePath, callback) => {
    (async () => {
        try {
            const full = resolveWithinResource(relativePath);
            if (!full) {
                callback('path_traversal', null);
                return;
            }
            if (!(await exists(full))) await migrateLegacy(relativePath);
            const buf = await fs.readFile(full);
            if (!buf || buf.length === 0) {
                callback('empty_file', null);
                return;
            }
            callback(null, buf.toString('base64'));
        } catch (e) {
            callback(String(e && e.message ? e.message : e), null);
        }
    })();
});

exports('FileExists', (relativePath, callback) => {
    (async () => {
        try {
            const full = resolveWithinResource(relativePath);
            if (!full) { callback(false); return; }
            if (!(await exists(full))) await migrateLegacy(relativePath);
            callback(await exists(full));
        } catch (_) {
            callback(false);
        }
    })();
});

exports('WriteFingerprint', (relativePath, fingerprint, callback) => {
    (async () => {
        try {
            if (typeof fingerprint !== 'string' || fingerprint.length === 0 || fingerprint.length > 4096) {
                callback('invalid_fingerprint');
                return;
            }
            const full = resolveWithinResource(relativePath);
            if (!full) { callback('path_traversal'); return; }
            await writeFileAtomic(full, fingerprint, 'utf8');
            callback(null);
        } catch (e) {
            callback(String(e && e.message ? e.message : e));
        }
    })();
});

// Returns null if PNG is missing so orphan .fp self-heals into a recapture.
exports('ReadFingerprint', (fpRelativePath, pngRelativePath, callback) => {
    (async () => {
        try {
            const pngFull = resolveWithinResource(pngRelativePath);
            const fpFull = resolveWithinResource(fpRelativePath);
            if (!pngFull || !fpFull) { callback(null); return; }

            if (!(await exists(pngFull))) await migrateLegacy(pngRelativePath);
            if (!(await exists(pngFull))) {
                callback(null);
                return;
            }

            try {
                const buf = await fs.readFile(fpFull, 'utf8');
                callback(typeof buf === 'string' && buf.length > 0 ? buf : null);
            } catch (_) {
                callback(null);
            }
        } catch (_) {
            callback(null);
        }
    })();
});
