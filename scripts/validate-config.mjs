import fs from "node:fs";

// Минимальная локальная проверка синтаксиса шаблона. Полную проверку схемы
// выполняет OpenClaw на будущем host после загрузки закреплённого image.
const configPath = new URL("../config/openclaw.json", import.meta.url);
let source = fs.readFileSync(configPath, "utf8");

source = source
  .replace(/^\s*\/\/.*$/gm, "")
  .replace(/([,{]\s*)([A-Za-z][A-Za-z0-9]*)(\s*:)/g, (_match, prefix, key, suffix) =>
    `${prefix}"${key}"${suffix}`,
  )
  .replace(/,\s*([}\]])/g, "$1");

const config = JSON.parse(source);

if (config.tools?.profile !== "full") {
  throw new Error('Шаблон должен использовать tools.profile: "full".');
}

for (const conflictingKey of ["alsoAllow", "deny", "fs"]) {
  if (Object.hasOwn(config.tools, conflictingKey)) {
    throw new Error(`В полном профиле не должно быть конфликтующего tools.${conflictingKey}.`);
  }
}

console.log("УСПЕХ: синтаксис и полный профиль шаблона openclaw.json проверены.");
