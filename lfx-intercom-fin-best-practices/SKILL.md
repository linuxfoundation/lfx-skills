---
name: lfx-intercom-fin-best-practices
description: >
  Intercom Fin AI best practices and optimization tips from the Intercom Community. Use this skill whenever
  the user asks about improving Fin performance, writing Fin Guidance rules, optimizing Help Center content
  for Fin, improving resolution rates, Fin CX scores, Fin escalation patterns, Copilot tips, Fin content
  strategy, daily review rituals, Fin Procedures/Tasks/Attributes, or any question about getting better
  results from Fin. Trigger on: "Fin tips", "Fin best practices", "improve Fin", "train Fin",
  "Fin resolution rate", "Fin guidance", "Fin snippets", "Fin suggestions", "Topics Explorer",
  "Copilot tips", "Fin re-engagement", "Fin handoff", or general Intercom AI support optimization questions.
  Complements intercom-fin-workflow-builder and intercom-banner-creator.
---

# Intercom Fin AI Best Practices

This skill contains proven tips and patterns from the Intercom Community's expert users and the Intercom product team. Use it to give well-informed advice on optimizing Fin AI Agent performance.

## When to use this skill

- User asks how to improve Fin's resolution rate or CX scores
- User needs help writing or improving Fin Guidance rules
- User wants to optimize Help Center content for Fin
- User asks about Fin workflows, escalation, or handoff patterns
- User wants to set up a continuous improvement process for Fin
- User asks about Copilot best practices
- User is preparing content for a Fin deployment or product release
- User asks general "how do I make Fin better?" questions

## Quick Reference: The 7 Pillars of Fin Excellence

These are the recurring themes from teams achieving 60-80%+ resolution rates:

### 1. Write Guidance Like You're Coaching a New Agent
Fin interprets guidance literally. Use if-then logic, specific examples, and plain language. Never give vague instructions like "be helpful" - instead spell out exactly what to say and when.

**Pattern:** "If [condition], then [specific action with example phrasing]."

### 2. Optimize Content for Two Audiences
Your Help Center serves both humans browsing and Fin searching. Restate questions within answers (especially in collapsible FAQ sections), use customer language instead of internal jargon, and ensure every article gives a complete answer that Fin can use standalone.

### 3. Build a Daily Review Ritual
The highest-performing teams spend 15 minutes daily reviewing conversations Fin could not resolve. Turn those into better articles, snippets, or guidance. Use Topics Explorer to find exactly where Fin struggles instead of guessing.

### 4. Use AI-Powered Suggestions
After deploying Fin, check Fin AI Agent > Train > Suggestions weekly. It automatically identifies where Fin stumbled and recommends fixes. Most teams approve ~70% of suggestions with minimal editing.

### 5. Tag and Categorize Systematically
Use Fin Attributes to auto-categorize conversations instead of relying on inconsistent manual tags. Set conversation data (Department, Product Category) BEFORE Fin handles the conversation so every interaction is tracked, not just escalated ones.

### 6. Design Smart Escalation Paths
Go AI-first with a clear "talk to a human" option. Use Fin Attributes in workflows for intelligent routing. Enable AI Summaries at handoff so agents do not re-ask what Fin already covered. Re-engage waiting customers with Fin if a human has not responded yet.

### 7. Prepare for Product Releases
Use content tagging to identify all articles affected by a release. Prepare drafts ahead of time, then bulk-publish when the feature ships. This keeps Fin's knowledge accurate through every launch.

## Detailed Reference

For the full collection of tips with specific implementation details, examples, and real-world benchmarks, read:
`references/community-tips-detailed.md`

This reference includes:
- Detailed guidance-writing patterns with before/after examples
- The "Fix the Support Loop" pattern (preventing Fin from telling customers to contact support when they're already in a conversation)
- Step-by-step setup for Fin re-engagement workflows
- Custom Slack notifications via Data Connectors
- How to feed Fin transcripts to internal AI tools for improvement
- Copilot use cases beyond simple Q&A
- Resolution rate benchmarks from real deployments (55% to 80%+ trajectories)
- Case closure hygiene patterns for AI readiness

## Benchmarks to Calibrate Expectations

When advising on Fin performance targets, use these real-world reference points:

- **Good starting point:** 50-55% resolution rate
- **Strong after optimization:** 65-75% resolution rate
- **Exceptional (with deep content investment):** 75-80%+ resolution rate
- **CX Scores:** Top performers achieve 90+ across channels
- **AI involvement:** Leading teams see 60-97% AI involvement across support channels
- **Time to improve:** Significant gains are achievable in 2-4 months with consistent daily review

## Source

All tips sourced from: https://community.intercom.com/fin-tips-and-best-practices-82
Contributors include Intercom employees (Karl O'Sullivan, Kevin Furlong, Beth-Ann, Dawn, Fred Walton, Paul D, Mateusz Leszkiewicz) and community experts (Conor Pendergrast, Nathan Sudds, Trevor, Sherice, Nico Magbiray, Daniel Ronnberg, Lance Black, Julian Murray).
