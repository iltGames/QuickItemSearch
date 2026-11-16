const fs = require("node:fs");
const path = require("node:path");

const [spellNamePath, skillLinePath, abilityPath, cachePath] = process.argv.slice(2);
if (!cachePath) {
    throw new Error("Usage: node scripts/Generate-SpellIndex.cjs <SpellName.db2> <SkillLine.db2> <SkillLineAbility.db2> <DBCache.bin>");
}

// Forever 1.60.1.70938 layouts from WoWDBDefs. These tables use fixed-size
// WDC5 records. Strings use offsets into the file's logical record/string blocks.
function readTable(file, layout, readRow) {
    const data = fs.readFileSync(file);
    const u32 = offset => data.readUInt32LE(offset);
    if (data.toString("ascii", 0, 4) !== "WDC5" || u32(156) !== layout || (data.readUInt16LE(172) & 1)) {
        throw new Error(`Unsupported DB2 layout for ${file}.`);
    }
    const recordCount = u32(136);
    const recordSize = u32(144);
    const sections = u32(200);
    const storage = 204 + sections * 40 + u32(140) * 4;
    let palette = storage + u32(188);
    const fields = [];
    for (let offset = storage; offset < storage + u32(188); offset += 24) {
        const type = u32(offset + 8);
        fields.push({ start: data.readUInt16LE(offset), width: data.readUInt16LE(offset + 2), type, palette });
        if (type === 3 || type === 4) palette += u32(offset + 4);
    }

    const rows = new Map();
    const copies = [];
    let precedingRecords = 0;
    let precedingStrings = 0;
    for (let section = 0; section < sections; section++) {
        const header = 204 + section * 40;
        const start = u32(header + 8);
        const count = u32(header + 12);
        const strings = u32(header + 16);
        const stringStart = start + count * recordSize;
        const idStart = stringStart + strings;
        const idBytes = u32(header + 24);
        const copyStart = idStart + idBytes;
        for (let index = 0; index < count; index++) {
            const record = start + index * recordSize;
            function value(fieldIndex) {
                const field = fields[fieldIndex];
                if (field.type !== 0 && field.type !== 3 && field.type !== 5) {
                    throw new Error(`Unsupported field encoding ${field.type} in ${file}.`);
                }
                let bits = 0;
                for (let i = 0; i < field.width; i++) {
                    const bit = field.start + i;
                    bits += ((data[record + Math.floor(bit / 8)] >> (bit % 8)) & 1) * 2 ** i;
                }
                return field.type === 3 ? u32(field.palette + bits * 4) : bits;
            }
            function name() {
                const offset = value(0);
                if (!offset) return "";
                const pos = stringStart + (precedingRecords + index - recordCount) * recordSize + offset - precedingStrings;
                if (pos < stringStart || pos >= idStart) throw new Error(`Invalid string offset in ${file}.`);
                return readString(data, pos, idStart).text;
            }
            const [id, entry] = readRow(idBytes ? u32(idStart + index * 4) : undefined, value, name);
            rows.set(id, entry);
        }
        for (let i = 0; i < u32(header + 36); i++) {
            const offset = copyStart + i * 8;
            copies.push([u32(offset), u32(offset + 4)]);
        }
        precedingRecords += count;
        precedingStrings += strings;
    }
    for (const [id, original] of copies) {
        if (!rows.has(original)) throw new Error(`Missing DB2 copy source ${original}.`);
        rows.set(id, rows.get(original));
    }
    return { rows, hash: u32(152) };
}

function readString(data, offset, end) {
    const terminator = data.indexOf(0, offset);
    if (terminator === -1 || terminator >= end) throw new Error("Invalid DB2 string.");
    return { text: data.toString("utf8", offset, terminator), next: terminator + 1 };
}

const names = readTable(spellNamePath, 0x782ee721, (id, _, name) => [id, name()]);
const skills = readTable(skillLinePath, 0x6763217c, (_, value, name) => [value(5), { name: name(), category: value(6) }]);
const abilities = readTable(abilityPath, 0x224f7ea0, (_, value) => [value(2), { skill: value(3), spell: value(4) }]);
console.log(`Read ${names.rows.size} spell names and ${abilities.rows.size} skill-line abilities.`);

const tables = new Map([[names.hash, names], [skills.hash, skills], [abilities.hash, abilities]]);
const cache = fs.readFileSync(cachePath);
if (cache.toString("ascii", 0, 4) !== "XFTH" || cache.readUInt32LE(4) !== 9 || cache.readUInt32LE(8) !== 70938) {
    throw new Error("Expected the Forever 70938 hotfix cache.");
}
for (let offset = 44; offset < cache.length;) {
    const start = offset + 32;
    const end = start + cache.readUInt32LE(offset + 24);
    if (end > cache.length || cache.toString("ascii", offset, offset + 4) !== "XFTH") {
        throw new Error("Invalid hotfix record.");
    }
    const table = tables.get(cache.readUInt32LE(offset + 16));
    const id = cache.readUInt32LE(offset + 20);
    const state = cache.readUInt32LE(offset + 28);
    if (table && state === 2) table.rows.delete(id);
    if (table && state === 1) {
        const first = readString(cache, start, end);
        if (table === names) names.rows.set(id, first.text);
        if (table === skills) {
            let pos = first.next;
            for (let i = 1; i < 5; i++) pos = readString(cache, pos, end).next;
            if (pos + 5 > end) throw new Error("Truncated SkillLine hotfix.");
            skills.rows.set(id, { name: first.text, category: cache[pos + 4] });
        }
        if (table === abilities) {
            const pos = readString(cache, first.next, end).next;
            if (pos + 10 > end) throw new Error("Truncated SkillLineAbility hotfix.");
            abilities.rows.set(id, { skill: cache.readUInt16LE(pos + 4), spell: cache.readUInt32LE(pos + 6) });
        }
    }
    offset = end;
}

const playerSkills = new Set();
for (const [id, skill] of skills.rows) {
    const classSkill = skill.category === 7 && !/^(Pet\b|Beast Training$|Mounts$|Companions$|Explorer Imp$)/i.test(skill.name);
    const racial = skill.category === 9 && /\bRacial\b/.test(skill.name);
    if (classSkill || racial) playerSkills.add(id);
}
const spells = new Map();
for (const { skill, spell } of abilities.rows.values()) {
    const name = names.rows.get(spell);
    if (playerSkills.has(skill) && name && !/[\u0000-\u001f\ufffd]/u.test(name)) spells.set(spell, name);
}
if (spells.size < 1500 || spells.get(467) !== "Thorns" || spells.get(116) !== "Frostbolt" || spells.has(15438)) {
    throw new Error("Unexpected contents for the Forever player spell catalog.");
}

const output = path.join(__dirname, "..", "SpellIndex.lua");
const lines = [...spells].sort(([left], [right]) => left - right)
    .map(([id, name]) => `    [${id}] = ${JSON.stringify(name)},`);
fs.writeFileSync(output, [
    "-- Generated by scripts/Generate-SpellIndex.cjs from Forever 70938 class and racial spells.",
    "local _, addon = ...",
    "addon.playerSpells = {",
    ...lines,
    "}",
    "",
].join("\n"));
console.log(`Wrote ${spells.size} player spell IDs to ${output}.`);
