import fs from "node:fs";
import path from "node:path";
export function ensureDir(dirPath) {
    fs.mkdirSync(dirPath, { recursive: true });
}
export function readJsonFile(filePath, fallback) {
    try {
        return JSON.parse(fs.readFileSync(filePath, "utf8"));
    }
    catch {
        return fallback;
    }
}
export function writeJsonFile(filePath, value) {
    ensureDir(path.dirname(filePath));
    fs.writeFileSync(filePath, JSON.stringify(value, null, 2));
}
