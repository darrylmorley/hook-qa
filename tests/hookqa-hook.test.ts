import { describe, test, expect } from "bun:test";
import { countMeaningfulDiffLines, isCommentLine, isImportLine } from "../HookQA/HookQA/Resources/hookqa-hook.ts";

describe("countMeaningfulDiffLines", () => {
  test("counts real code changes, ignores metadata and context lines", () => {
    const diff = [
      "diff --git a/src/foo.ts b/src/foo.ts",
      "index 1234567..89abcde 100644",
      "--- a/src/foo.ts",
      "+++ b/src/foo.ts",
      "@@ -1,5 +1,6 @@",
      " function foo() {",
      "-  return 1;",
      "+  return 2;",
      '+  console.log("added");',
      " }",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(3);
  });

  test("import-only diff counts 0 across languages", () => {
    const diff = [
      "@@ -1,10 +1,10 @@",
      '-import fs from "fs";',
      '+import path from "path";',
      "-from os import path",
      "+import Foundation",
      "-#include <stdio.h>",
      "+use std::io;",
      '+const fs = require("fs");',
      '+export { thing } from "./thing";',
      "+using System.Text;",
      "+@testable import HookQA",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(0);
  });

  test("whitespace-only reindent cancels to 0", () => {
    const diff = [
      "@@ -1,2 +1,2 @@",
      "-  const x = 1;",
      "+      const x = 1;",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(0);
  });

  test("comment-only diff counts 0", () => {
    const diff = [
      "@@ -1,6 +1,6 @@",
      "-// old comment",
      "+// new comment",
      "+# a shell comment",
      "+/* block open",
      "+ * continuation",
      "+ */",
      "+<!-- html comment -->",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(0);
  });

  test("mixed diff counts only the meaningful lines", () => {
    const diff = [
      "diff --git a/src/bar.ts b/src/bar.ts",
      "index abcdef0..1234567 100644",
      "--- a/src/bar.ts",
      "+++ b/src/bar.ts",
      "@@ -1,8 +1,9 @@",
      '-import old from "old";',
      '+import fresh from "fresh";',
      " const unchanged = true;",
      "-// stale comment",
      "-  let total = 0;",
      "+      let total = 0;",
      "+let sum = items.reduce((a, b) => a + b, 0);",
      "+return sum * 2;",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(2);
  });

  test("#include is import-filtered but #define and #! count as meaningful", () => {
    const diff = [
      "@@ -1,3 +1,3 @@",
      "+#include <stdlib.h>",
      "+#define MAX_SIZE 1024",
      "+#!/usr/bin/env bun",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(2);
  });

  test("*ptr style code is not treated as a block comment", () => {
    const diff = [
      "@@ -1,2 +1,2 @@",
      "+*ptr = value;",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(1);
  });

  test("line moved within the same hunk cancels to 0", () => {
    const diff = [
      "@@ -1,5 +1,5 @@",
      "-doThing();",
      " other();",
      "+doThing();",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(0);
  });

  test("line moved across files/hunks does not cancel", () => {
    const diff = [
      "diff --git a/a.ts b/a.ts",
      "index 1111111..2222222 100644",
      "--- a/a.ts",
      "+++ b/a.ts",
      "@@ -1,3 +1,2 @@",
      "-doThing();",
      "diff --git a/b.ts b/b.ts",
      "index 3333333..4444444 100644",
      "--- a/b.ts",
      "+++ b/b.ts",
      "@@ -1,2 +1,3 @@",
      "+doThing();",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(2);
  });

  test("duplicate lines use multiset semantics", () => {
    const diff = [
      "@@ -1,4 +1,3 @@",
      "-x++;",
      "-x++;",
      "+x++;",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(1);
  });

  test("empty string returns 0", () => {
    expect(countMeaningfulDiffLines("")).toBe(0);
  });

  test("staged/unstaged separators are ignored", () => {
    const diff = [
      "=== STAGED CHANGES ===",
      "diff --git a/src/foo.ts b/src/foo.ts",
      "index 1234567..89abcde 100644",
      "--- a/src/foo.ts",
      "+++ b/src/foo.ts",
      "@@ -1,2 +1,2 @@",
      "-const a = 1;",
      "+const a = 2;",
      "",
      "=== UNSTAGED CHANGES ===",
      "diff --git a/src/baz.ts b/src/baz.ts",
      "index 5555555..6666666 100644",
      "--- a/src/baz.ts",
      "+++ b/src/baz.ts",
      "@@ -1,1 +1,2 @@",
      "+const b = 3;",
    ].join("\n");
    expect(countMeaningfulDiffLines(diff)).toBe(3);
  });
});

describe("isCommentLine", () => {
  test("recognises comment forms", () => {
    expect(isCommentLine("// foo")).toBe(true);
    expect(isCommentLine("/* foo")).toBe(true);
    expect(isCommentLine("*/")).toBe(true);
    expect(isCommentLine("* continuation")).toBe(true);
    expect(isCommentLine("*")).toBe(true);
    expect(isCommentLine("# foo")).toBe(true);
    expect(isCommentLine("#")).toBe(true);
    expect(isCommentLine("<!-- foo")).toBe(true);
    expect(isCommentLine("-->")).toBe(true);
  });

  test("does not match code that resembles comments", () => {
    expect(isCommentLine("*ptr = x;")).toBe(false);
    expect(isCommentLine("#include <stdio.h>")).toBe(false);
    expect(isCommentLine("#define MAX 1")).toBe(false);
    expect(isCommentLine("#!/usr/bin/env bun")).toBe(false);
  });
});

describe("isImportLine", () => {
  test("recognises import forms", () => {
    expect(isImportLine('import fs from "fs";')).toBe(true);
    expect(isImportLine("import Foundation")).toBe(true);
    expect(isImportLine("from os import path")).toBe(true);
    expect(isImportLine('export { a } from "./a";')).toBe(true);
    expect(isImportLine('export * from "./b";')).toBe(true);
    expect(isImportLine('const fs = require("fs");')).toBe(true);
    expect(isImportLine('require "json"')).toBe(true);
    expect(isImportLine('require_relative "helper"')).toBe(true);
    expect(isImportLine("#include <stdio.h>")).toBe(true);
    expect(isImportLine("#import <Foundation/Foundation.h>")).toBe(true);
    expect(isImportLine("using System.Text;")).toBe(true);
    expect(isImportLine("use std::collections::HashMap;")).toBe(true);
    expect(isImportLine("@testable import HookQA")).toBe(true);
  });

  test("does not match ordinary code", () => {
    expect(isImportLine("const x = 1;")).toBe(false);
    expect(isImportLine("importantFunction();")).toBe(false);
    expect(isImportLine("user.from = sender;")).toBe(false);
    expect(isImportLine("#define MAX 1")).toBe(false);
  });
});
