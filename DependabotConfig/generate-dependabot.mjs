#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import ejs from "ejs";
import yaml from "js-yaml";

const scriptDir = path.dirname(new URL(import.meta.url).pathname);

function usage() {
  console.error(`Usage:
  generate-dependabot.mjs [--inventory PATH] [--template PATH] [--list-repos]
  generate-dependabot.mjs [--inventory PATH] [--template PATH] [--describe] REPO
  generate-dependabot.mjs [--inventory PATH] [--template PATH] REPO`);
}

function parseArgs(args) {
  const options = {
    inventory: "DependabotConfig/repo-inventory.yml",
    template: path.join(scriptDir, "dependabot.yml.ejs"),
    listRepos: false,
    describe: false,
    repo: null,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--inventory") {
      index += 1;
      if (index >= args.length) throw new Error("--inventory requires a path");
      options.inventory = args[index];
    } else if (arg === "--template") {
      index += 1;
      if (index >= args.length) throw new Error("--template requires a path");
      options.template = args[index];
    } else if (arg === "--list-repos") {
      options.listRepos = true;
    } else if (arg === "--describe") {
      options.describe = true;
    } else if (arg.startsWith("--")) {
      throw new Error(`unknown option: ${arg}`);
    } else if (options.repo === null) {
      options.repo = arg;
    } else {
      throw new Error(`unexpected argument: ${arg}`);
    }
  }

  return options;
}

function normalizeRepoName(repo) {
  return repo.includes("/") ? repo.split("/", 2)[1] : repo;
}

function loadInventory(inventoryPath) {
  const data = yaml.load(fs.readFileSync(inventoryPath, "utf8")) ?? {};
  if (typeof data !== "object" || Array.isArray(data)) {
    throw new Error(`Inventory must be a YAML mapping: ${inventoryPath}`);
  }
  return data;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function deepMerge(base, override) {
  const result = structuredClone(base ?? {});
  for (const [key, value] of Object.entries(override ?? {})) {
    if (isPlainObject(value) && isPlainObject(result[key])) {
      result[key] = deepMerge(result[key], value);
    } else {
      result[key] = structuredClone(value);
    }
  }
  return result;
}

function findRepoConfig(inventory, repoName) {
  const shortName = normalizeRepoName(repoName);
  const defaults = inventory.defaults ?? {};
  const repositories = inventory.repositories ?? [];
  const repoConfig = repositories.find((entry) => {
    return normalizeRepoName(String(entry.name ?? "")) === shortName;
  }) ?? {};

  const merged = deepMerge(defaults, repoConfig);
  merged.name ??= shortName;
  merged.julia_directories ??= ["/"];
  merged.npm_directories ??= [];
  merged.cargo_directories ??= [];
  return merged;
}

function scheduleFrom(config, keys) {
  return Object.fromEntries(
    keys
      .filter((key) => config?.[key] !== undefined && config?.[key] !== null)
      .map((key) => [key, String(config[key])]),
  );
}

function updateEntry({ ecosystem, config, directories, groupName }) {
  if (config?.enabled !== true || directories.length === 0) return null;
  return {
    ecosystem,
    directories,
    schedule: scheduleFrom(config, ["interval", "day", "time", "timezone"]),
    groupAll: config.group_all === true,
    groupName,
  };
}

function buildUpdates(repoConfig) {
  const dependabot = repoConfig.dependabot ?? {};
  return [
    updateEntry({
      ecosystem: "github-actions",
      config: dependabot.github_actions,
      directories: ["/"],
      groupName: "github-actions",
    }),
    updateEntry({
      ecosystem: "julia",
      config: dependabot.julia,
      directories: repoConfig.julia_directories,
      groupName: "julia",
    }),
    updateEntry({
      ecosystem: "npm",
      config: dependabot.npm,
      directories: repoConfig.npm_directories,
      groupName: "npm",
    }),
    updateEntry({
      ecosystem: "cargo",
      config: dependabot.cargo,
      directories: repoConfig.cargo_directories,
      groupName: "cargo",
    }),
  ].filter(Boolean);
}

function listRepositories(inventory) {
  for (const entry of inventory.repositories ?? []) {
    if (entry.name) console.log(normalizeRepoName(String(entry.name)));
  }
}

function describeRepo(inventory, repoName) {
  const repoConfig = findRepoConfig(inventory, repoName);
  const dependabot = repoConfig.dependabot ?? {};
  const githubActions = dependabot.github_actions ?? {};
  const julia = dependabot.julia ?? {};
  const npm = dependabot.npm ?? {};
  const cargo = dependabot.cargo ?? {};

  console.log(`repo=${normalizeRepoName(repoName)}`);
  console.log(`julia_directories=${repoConfig.julia_directories.join(",")}`);
  console.log(`npm_directories=${repoConfig.npm_directories.join(",")}`);
  console.log(`cargo_directories=${repoConfig.cargo_directories.join(",")}`);
  console.log(`github_actions_enabled=${githubActions.enabled === true}`);
  console.log(`julia_enabled=${julia.enabled === true}`);
  console.log(`julia_group_all=${julia.group_all === true}`);
  console.log(`npm_enabled=${npm.enabled === true}`);
  console.log(`npm_group_all=${npm.group_all === true}`);
  console.log(`cargo_enabled=${cargo.enabled === true}`);
  console.log(`cargo_group_all=${cargo.group_all === true}`);
}

function renderDependabot(options, repoConfig) {
  const template = fs.readFileSync(options.template, "utf8");
  return ejs.render(template, { updates: buildUpdates(repoConfig) }).trimEnd() + "\n";
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const inventory = loadInventory(options.inventory);

  if (options.listRepos) {
    listRepositories(inventory);
    return;
  }

  if (options.repo === null) {
    usage();
    process.exitCode = 2;
    return;
  }

  if (options.describe) {
    describeRepo(inventory, options.repo);
    return;
  }

  const repoConfig = findRepoConfig(inventory, options.repo);
  process.stdout.write(renderDependabot(options, repoConfig));
}

try {
  main();
} catch (error) {
  console.error(`error: ${error.message}`);
  process.exit(1);
}
