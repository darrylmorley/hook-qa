#!/usr/bin/env bun
// hookqa-hook v1.0.0

const startTime = Date.now();

// --- Types ---

interface WeightsConfig {
  correctness?: number;
  completeness?: number;
  specAdherence?: number;
  codeQuality?: number;
}

interface LoggingConfig {
  enabled?: boolean;
  logFile?: string;
}

interface ConnectionConfig {
  ollamaUrl?: string;
  model?: string;
  apiKey?: string;
  timeout?: number;
}

interface BehaviourConfig {
  enabled?: boolean;
  blockOnWarnings?: boolean;
  maxDiffLines?: number;
  minDiffLines?: number;
  maxRetries?: number;
}

interface ReviewConfig {
  model?: string;
  timeout?: number;
  temperature?: number;
  weights?: WeightsConfig;
  customInstructions?: string;
}

interface HookQAConfig {
  connection?: ConnectionConfig;
  behaviour?: BehaviourConfig;
  review?: ReviewConfig;
  logging?: LoggingConfig;
}

interface ResolvedConfig {
  ollamaUrl: string;
  apiKey: string | null;
  model: string;
  timeout: number;
  enabled: boolean;
  blockOnWarnings: boolean;
  maxDiffLines: number;
  minDiffLines: number;
  maxRetries: number;
  temperature: number;
  weights: Required<WeightsConfig>;
  customInstructions: string;
  logging: { enabled: boolean; logFile: string };
}

interface Finding {
  severity: "critical" | "warning";
  category: string;
  description: string;
  suggestion: string;
}

interface QAResponse {
  verdict: "PASS" | "FAIL";
  findings: Finding[];
  summary: string;
}

interface LogEntry {
  timestamp: string;
  project: string;
  model: string;
  verdict: "PASS" | "FAIL" | "ERROR" | "SKIPPED";
  findings: number;
  criticals: number;
  warnings: number;
  summary: string;
  durationMs: number;
}

// --- Helpers ---

function expandTilde(p: string): string {
  const home = process.env.HOME ?? Bun.env.HOME ?? "/tmp";
  return p.startsWith("~/") ? `${home}${p.slice(1)}` : p;
}

async function readJsonFile<T>(path: string): Promise<T | null> {
  try {
    const file = Bun.file(path);
    const exists = await file.exists();
    if (!exists) return null;
    const text = await file.text();
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}

function deepMerge<T extends object>(base: T, override: Partial<T>): T {
  const result = { ...base } as Record<string, unknown>;
  for (const [key, value] of Object.entries(override)) {
    if (value !== undefined && value !== null) {
      if (typeof value === "object" && !Array.isArray(value) && typeof result[key] === "object" && result[key] !== null) {
        result[key] = deepMerge(result[key] as object, value as object);
      } else {
        result[key] = value;
      }
    }
  }
  return result as T;
}

// --- Config Loading ---

async function loadConfig(): Promise<ResolvedConfig> {
  const defaults: ResolvedConfig = {
    ollamaUrl: "http://localhost:11434",
    apiKey: null,
    model: "",
    timeout: 120,
    enabled: true,
    blockOnWarnings: false,
    maxDiffLines: 500,
    minDiffLines: 5,
    maxRetries: 1,
    temperature: 0.1,
    weights: { correctness: 10, completeness: 8, specAdherence: 6, codeQuality: 4 },
    customInstructions: "",
    logging: { enabled: true, logFile: "~/.claude/hooks/hookqa.log" },
  };

  // Tier 1: global config file
  const globalConfigPath = expandTilde("~/.claude/hooks/hookqa.json");
  const globalFile = await readJsonFile<HookQAConfig>(globalConfigPath);

  // Tier 2: env vars as partial override
  const envOverride: Partial<ResolvedConfig> = {};
  if (Bun.env.QA_OLLAMA_MODEL) envOverride.model = Bun.env.QA_OLLAMA_MODEL;
  if (Bun.env.QA_OLLAMA_URL) envOverride.ollamaUrl = Bun.env.QA_OLLAMA_URL;
  if (Bun.env.QA_MAX_DIFF_LINES) envOverride.maxDiffLines = parseInt(Bun.env.QA_MAX_DIFF_LINES, 10);
  if (Bun.env.QA_ENABLED) envOverride.enabled = Bun.env.QA_ENABLED !== "false";
  if (Bun.env.QA_LOG_FILE) envOverride.logging = { ...defaults.logging, logFile: Bun.env.QA_LOG_FILE };

  // Build global config from file + env
  let config = { ...defaults };

  if (globalFile) {
    if (globalFile.connection?.ollamaUrl) config.ollamaUrl = globalFile.connection.ollamaUrl;
    if (globalFile.connection?.model) config.model = globalFile.connection.model;
    if (globalFile.connection?.apiKey != null) config.apiKey = globalFile.connection.apiKey;
    if (globalFile.connection?.timeout != null) config.timeout = globalFile.connection.timeout;
    if (globalFile.behaviour?.enabled != null) config.enabled = globalFile.behaviour.enabled;
    if (globalFile.behaviour?.blockOnWarnings != null) config.blockOnWarnings = globalFile.behaviour.blockOnWarnings;
    if (globalFile.behaviour?.maxDiffLines != null) config.maxDiffLines = globalFile.behaviour.maxDiffLines;
    if (globalFile.behaviour?.minDiffLines != null) config.minDiffLines = globalFile.behaviour.minDiffLines;
    if (globalFile.behaviour?.maxRetries != null) config.maxRetries = globalFile.behaviour.maxRetries;
    if (globalFile.review?.model) config.model = globalFile.review.model;
    if (globalFile.review?.timeout != null) config.timeout = globalFile.review.timeout;
    if (globalFile.review?.temperature != null) config.temperature = globalFile.review.temperature;
    if (globalFile.review?.weights) config.weights = { ...config.weights, ...globalFile.review.weights };
    if (globalFile.review?.customInstructions != null) config.customInstructions = globalFile.review.customInstructions;
    if (globalFile.logging?.enabled != null) config.logging.enabled = globalFile.logging.enabled;
    if (globalFile.logging?.logFile) config.logging.logFile = globalFile.logging.logFile;
  }

  // Apply env overrides
  config = { ...config, ...envOverride };

  // Tier 3: project-level overrides from CWD/.claude/hookqa.json
  const projectConfigPath = `.claude/hookqa.json`;
  const projectFile = await readJsonFile<HookQAConfig>(projectConfigPath);

  if (projectFile) {
    if (projectFile.behaviour) {
      const b = projectFile.behaviour;
      if (b.enabled != null) config.enabled = b.enabled;
      if (b.blockOnWarnings != null) config.blockOnWarnings = b.blockOnWarnings;
      if (b.maxDiffLines != null) config.maxDiffLines = b.maxDiffLines;
      if (b.minDiffLines != null) config.minDiffLines = b.minDiffLines;
      if (b.maxRetries != null) config.maxRetries = b.maxRetries;
    }
    if (projectFile.review) {
      const r = projectFile.review;
      if (r.model) config.model = r.model;
      if (r.timeout != null) config.timeout = r.timeout;
      if (r.temperature != null) config.temperature = r.temperature;
      if (r.weights) config.weights = deepMerge(config.weights, r.weights as Partial<Required<WeightsConfig>>);
      if (r.customInstructions != null) config.customInstructions = r.customInstructions;
    }
  }

  return config;
}

// --- Prompt Building ---

function buildGradingCriteria(weights: Required<WeightsConfig>, customInstructions: string): string {
  const criteria: Array<{ name: string; weight: number; description: string }> = [
    { name: "Correctness", weight: weights.correctness, description: "Bugs, logic errors, unhandled edge cases, broken control flow." },
    { name: "Completeness", weight: weights.completeness, description: "Missing implementation, TODO stubs, incomplete error handling." },
    { name: "Spec Adherence", weight: weights.specAdherence, description: "Does the code match the requirements and intended behaviour?" },
    { name: "Code Quality", weight: weights.codeQuality, description: "Readability, naming, unnecessary complexity, dead code." },
  ];

  const lines: string[] = [];
  let index = 1;

  for (const c of criteria) {
    if (c.weight === 0) continue;
    let focus: string;
    if (c.weight >= 8) focus = "PRIMARY focus";
    else if (c.weight >= 4) focus = "Secondary focus";
    else focus = "Light check";
    lines.push(`${index}. **${c.name}** [${focus}, weight ${c.weight}/10]: ${c.description}`);
    index++;
  }

  let result = lines.join("\n");

  if (customInstructions.trim()) {
    result += `\n\n## Additional Instructions\n${customInstructions.trim()}`;
  }

  return result;
}

function buildPrompt(diff: string, config: ResolvedConfig): { system: string; user: string } {
  const criteria = buildGradingCriteria(config.weights, config.customInstructions);

  const system = `You are a code QA evaluator. Your role is to review git diffs and identify real issues that could cause bugs, regressions, or poor quality code. Be precise and actionable. Only flag genuine problems — do not invent issues.

Respond ONLY with valid JSON matching this schema:
{
  "verdict": "PASS" | "FAIL",
  "findings": [
    {
      "severity": "critical" | "warning",
      "category": "<category name>",
      "description": "<what the issue is>",
      "suggestion": "<how to fix it>"
    }
  ],
  "summary": "<one-line summary of your assessment>"
}

Use "FAIL" if there are any critical findings. Use "PASS" if there are no critical findings (warnings alone do not fail unless instructed).`;

  const user = `## Grading Criteria\n${criteria}\n\n## Git Diff\n\`\`\`\n${diff}\n\`\`\`\n\nReview the diff above and respond with a JSON verdict.`;

  return { system, user };
}

// --- Git Diff ---

async function collectDiff(maxLines: number): Promise<string> {
  let staged = "";
  let unstaged = "";

  try {
    const stagedResult = await Bun.$`git diff --cached`.text();
    staged = stagedResult.trim();
  } catch {
    // no staged changes or not a git repo
  }

  try {
    const unstagedResult = await Bun.$`git diff`.text();
    unstaged = unstagedResult.trim();
  } catch {
    // no unstaged changes
  }

  const parts: string[] = [];
  if (staged) parts.push(`=== STAGED CHANGES ===\n${staged}`);
  if (unstaged) parts.push(`=== UNSTAGED CHANGES ===\n${unstaged}`);

  const combined = parts.join("\n\n");
  if (!combined) return "";

  const lines = combined.split("\n");
  if (lines.length <= maxLines) return combined;
  return lines.slice(0, maxLines).join("\n") + `\n... (truncated at ${maxLines} lines)`;
}

function countDiffLines(diff: string): number {
  if (!diff) return 0;
  return diff.split("\n").filter(line =>
    !line.startsWith("=== ") && line.trim() !== ""
  ).length;
}

// --- Project Name ---

async function getProjectName(): Promise<string> {
  try {
    const remote = await Bun.$`git remote get-url origin`.text();
    const url = remote.trim();
    // Extract repo name from URL like git@github.com:user/repo.git or https://github.com/user/repo.git
    const match = url.match(/\/([^/]+?)(?:\.git)?$/);
    if (match) return match[1];
  } catch {
    // not a git repo or no remote
  }
  // Fallback to directory name
  return process.cwd().split("/").pop() ?? "unknown";
}

// --- Retry Tracking ---

function getRetryFilePath(sessionId: string): string {
  return `/tmp/hookqa-${sessionId}-retries`;
}

async function getRetryCount(sessionId: string): Promise<number> {
  try {
    const file = Bun.file(getRetryFilePath(sessionId));
    const exists = await file.exists();
    if (!exists) return 0;
    const text = await file.text();
    const count = parseInt(text.trim(), 10);
    return isNaN(count) ? 0 : count;
  } catch {
    return 0;
  }
}

async function incrementRetryCount(sessionId: string, current: number): Promise<void> {
  await Bun.write(getRetryFilePath(sessionId), String(current + 1));
}

async function deleteRetryFile(sessionId: string): Promise<void> {
  try {
    const path = getRetryFilePath(sessionId);
    const file = Bun.file(path);
    const exists = await file.exists();
    if (exists) {
      await Bun.$`rm -f ${path}`.quiet();
    }
  } catch {
    // ignore cleanup errors
  }
}

// --- Logging ---

async function appendLog(config: ResolvedConfig, entry: LogEntry): Promise<void> {
  if (!config.logging.enabled) return;
  try {
    const logPath = expandTilde(config.logging.logFile);
    const line = JSON.stringify(entry) + "\n";
    const file = Bun.file(logPath);
    const exists = await file.exists();
    const existing = exists ? await file.text() : "";
    await Bun.write(logPath, existing + line);
  } catch {
    // never fail on logging errors
  }
}

// --- Ollama API Call ---

const CLOUD_BASE_URL = "https://ollama.com";
const CLOUD_SUFFIX = ":cloud";

function resolveEndpoint(model: string, localBase: string): { baseURL: string; apiModel: string } {
  if (model.endsWith(CLOUD_SUFFIX)) {
    return { baseURL: CLOUD_BASE_URL, apiModel: model.slice(0, -CLOUD_SUFFIX.length) };
  }
  return { baseURL: localBase, apiModel: model };
}

async function callOllama(config: ResolvedConfig, prompt: { system: string; user: string }): Promise<{ response: QAResponse | null; durationMs: number }> {
  const apiStart = Date.now();
  const { baseURL, apiModel } = resolveEndpoint(config.model, config.ollamaUrl);

  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (config.apiKey) {
    headers["Authorization"] = `Bearer ${config.apiKey}`;
  }

  const body = JSON.stringify({
    model: apiModel,
    messages: [
      { role: "system", content: prompt.system },
      { role: "user", content: prompt.user },
    ],
    stream: false,
    options: { temperature: config.temperature },
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.timeout * 1000);

  try {
    const res = await fetch(`${baseURL}/api/chat`, {
      method: "POST",
      headers,
      body,
      signal: controller.signal,
    });

    clearTimeout(timer);
    const durationMs = Date.now() - apiStart;

    if (!res.ok) {
      return { response: null, durationMs };
    }

    const data = await res.json() as { message?: { content?: string } };
    const content = data?.message?.content ?? "";

    // Extract JSON from response (handle thinking models that wrap output in text)
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return { response: null, durationMs };

    const parsed = JSON.parse(jsonMatch[0]) as QAResponse;

    // Validate structure
    if (!parsed.verdict || !Array.isArray(parsed.findings)) {
      return { response: null, durationMs };
    }

    return { response: parsed, durationMs };
  } catch {
    clearTimeout(timer);
    return { response: null, durationMs: Date.now() - apiStart };
  }
}

// --- Feedback Formatting ---

function formatFeedback(response: QAResponse): string {
  const lines: string[] = [
    `HookQA Review: ${response.verdict}`,
    `Summary: ${response.summary}`,
    "",
  ];

  const criticals = response.findings.filter(f => f.severity === "critical");
  const warnings = response.findings.filter(f => f.severity === "warning");

  if (criticals.length > 0) {
    lines.push(`Critical Issues (${criticals.length}):`);
    for (const f of criticals) {
      lines.push(`  [${f.category}] ${f.description}`);
      lines.push(`  Fix: ${f.suggestion}`);
    }
    lines.push("");
  }

  if (warnings.length > 0) {
    lines.push(`Warnings (${warnings.length}):`);
    for (const f of warnings) {
      lines.push(`  [${f.category}] ${f.description}`);
      lines.push(`  Suggestion: ${f.suggestion}`);
    }
    lines.push("");
  }

  lines.push("Please address the issues above before proceeding.");
  return lines.join("\n");
}

// --- Main ---

async function main(): Promise<void> {
  // Read stdin from Claude Code
  let stdinData: { stop_hook_active?: boolean; session_id?: string } = {};
  try {
    const stdinText = await Bun.stdin.text();
    if (stdinText.trim()) {
      stdinData = JSON.parse(stdinText.trim());
    }
  } catch {
    // malformed stdin — carry on
  }

  const stopHookActive = stdinData.stop_hook_active === true;
  // Use session_id from stdin, fallback to ppid
  const sessionId = stdinData.session_id ?? String(process.ppid ?? "default");

  const config = await loadConfig();

  if (!config.enabled) {
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  if (!config.model) {
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  // Check stop_hook_active + retries scenario
  const currentRetries = await getRetryCount(sessionId);

  if (stopHookActive && currentRetries >= config.maxRetries) {
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  // Collect diff
  const diff = await collectDiff(config.maxDiffLines);
  const diffLineCount = countDiffLines(diff);

  if (diffLineCount < config.minDiffLines) {
    // Not enough diff to review — skip
    const project = await getProjectName();
    await appendLog(config, {
      timestamp: new Date().toISOString(),
      project,
      model: config.model,
      verdict: "SKIPPED",
      findings: 0,
      criticals: 0,
      warnings: 0,
      summary: `Diff too small (${diffLineCount} lines, min ${config.minDiffLines})`,
      durationMs: 0,
    });
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  // Call Ollama
  const prompt = buildPrompt(diff, config);
  const { response, durationMs } = await callOllama(config, prompt);
  const project = await getProjectName();

  if (!response) {
    // Could not get a valid response — fail gracefully
    await appendLog(config, {
      timestamp: new Date().toISOString(),
      project,
      model: config.model,
      verdict: "ERROR",
      findings: 0,
      criticals: 0,
      warnings: 0,
      summary: "Failed to get valid response from Ollama",
      durationMs,
    });
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  const criticals = response.findings.filter(f => f.severity === "critical");
  const warnings = response.findings.filter(f => f.severity === "warning");
  const shouldBlock = criticals.length > 0 || (config.blockOnWarnings && warnings.length > 0);

  await appendLog(config, {
    timestamp: new Date().toISOString(),
    project,
    model: config.model,
    verdict: response.verdict,
    findings: response.findings.length,
    criticals: criticals.length,
    warnings: warnings.length,
    summary: response.summary,
    durationMs,
  });

  if (!shouldBlock) {
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  // Block — but only if retries allow it
  if (currentRetries >= config.maxRetries) {
    await deleteRetryFile(sessionId);
    process.exit(0);
  }

  await incrementRetryCount(sessionId, currentRetries);
  const feedback = formatFeedback(response);
  process.stderr.write(feedback + "\n");
  process.exit(2);
}

main().catch(() => {
  // Never crash Claude Code
  process.exit(0);
});
