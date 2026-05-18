import fs from "node:fs";
import path from "node:path";
import { EQUIPMENT_CATALOG, ROLE_PROFILES, } from "../../../shared/world-model.js";
import { repoRoot } from "../lib/paths.js";
const configDir = path.join(process.env.HOME || "", ".openclaw");
const defaultInstalledSkillsDir = path.join(configDir, "skills");
const defaultReserveSkillsDir = path.join(repoRoot, "skills", "default");
function firstNonEmptyLine(text) {
    return (text
        .split(/\r?\n/)
        .map((line) => line.trim())
        .find((line) => line && !line.startsWith("#") && !line.startsWith("---")) || "");
}
function extractDescriptionFromSkillDir(skillDir) {
    const files = [path.join(skillDir, "SKILL.md"), path.join(skillDir, "GUIDE.md")];
    for (const file of files) {
        if (!fs.existsSync(file))
            continue;
        const content = fs.readFileSync(file, "utf8");
        const frontmatterMatch = content.match(/description:\s*"?(.*?)"?$/m);
        if (frontmatterMatch?.[1])
            return frontmatterMatch[1].trim();
        const line = firstNonEmptyLine(content);
        if (line)
            return line;
    }
    return "本地技能，可按需装配到角色构筑中。";
}
function friendlyName(skillId) {
    return skillId
        .split(/[-_]/g)
        .filter(Boolean)
        .map((part) => part[0]?.toUpperCase() + part.slice(1))
        .join(" ");
}
function listSkillDirs(rootDir) {
    try {
        return fs
            .readdirSync(rootDir, { withFileTypes: true })
            .filter((entry) => entry.isDirectory())
            .map((entry) => entry.name)
            .sort();
    }
    catch {
        return [];
    }
}
export function collectSkillCatalog(build, options = {}) {
    const installedSkillsDir = options.installedSkillsDir || defaultInstalledSkillsDir;
    const reserveSkillsDir = options.reserveSkillsDir || defaultReserveSkillsDir;
    const installedIds = listSkillDirs(installedSkillsDir);
    const reserveIds = listSkillDirs(reserveSkillsDir);
    const effectiveInstalled = new Set([...installedIds, ...build.skills.installed]);
    const effectiveReserve = reserveIds.filter((id) => !effectiveInstalled.has(id));
    const installed = [...effectiveInstalled].sort().map((id) => ({
        id,
        name: friendlyName(id),
        description: extractDescriptionFromSkillDir(path.join(installedIds.includes(id) ? installedSkillsDir : reserveSkillsDir, id)),
        branch: "本地技能",
        source: "installed",
    }));
    const reserve = effectiveReserve.map((id) => ({
        id,
        name: friendlyName(id),
        description: extractDescriptionFromSkillDir(path.join(reserveSkillsDir, id)),
        branch: "本地技能仓",
        source: "reserve",
    }));
    return { installed, reserve };
}
export function equipmentItemsForBuild(build) {
    const equipped = new Set(Object.values(build.equipment.slots).filter(Boolean));
    return {
        equipped: EQUIPMENT_CATALOG.filter((item) => equipped.has(item.id)),
        inventory: EQUIPMENT_CATALOG.filter((item) => !equipped.has(item.id)),
    };
}
export function roleCards() {
    return Object.values(ROLE_PROFILES);
}
