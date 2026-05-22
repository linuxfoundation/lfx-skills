<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Intercom Fin AI Best Practices

This reference contains proven tips and patterns from the Intercom Community's expert users and the
Intercom product team. Use it when the user needs help optimizing Fin AI Agent performance — not
code integration.

**Audience:** Support/CX team members writing Fin Guidance, managing Help Center content, and
improving resolution rates. No coding required.

---

## The 7 Pillars of Fin Excellence

These are the recurring themes from teams achieving 60-80%+ resolution rates.

### 1. Write Guidance Like You're Coaching a New Agent
Fin interprets guidance literally. Use if-then logic, specific examples, and plain language. Never
give vague instructions like "be helpful" — spell out exactly what to say and when.

**Pattern:** "If [condition], then [specific action with example phrasing]."

**Weak:** "Be friendly and professional."
**Strong:** "Use a professional yet warm tone. Keep responses short and avoid jargon. When a customer
is frustrated, acknowledge the issue and say something like, 'I understand how that can be
frustrating. Here's what we can do.'"

### 2. Optimize Content for Two Audiences
Your Help Center serves both humans browsing and Fin searching. Restate questions within answers
(especially in collapsible FAQ sections), use customer language instead of internal jargon, and
ensure every article gives a complete answer that Fin can use standalone.

**Example:** If a user asks "Do I need to use the original shipping box to return an item?"
- Weak: "No."
- Strong: "You can use your own packaging when sending an item back; there's no need to save the original shipping box."

### 3. Build a Daily Review Ritual
The highest-performing teams spend 15 minutes daily reviewing conversations Fin couldn't resolve.
Turn those into better articles, snippets, or guidance. Use Topics Explorer to find exactly where
Fin struggles instead of guessing:
1. Select the right scope and metric to surface real opportunities
2. Generate a Testing Group from past conversations by topic
3. Rate answers and decide the fix type: content, data (attributes/connectors), or actions (Fin Tasks)

### 4. Use AI-Powered Suggestions
After deploying Fin, check **Fin AI Agent > Train > Suggestions** weekly. It automatically identifies
where Fin stumbled and recommends fixes. Most teams approve ~70% of suggestions with minimal editing.
Use the **OPTIMIZE button** on all new guidance entries — it improves logic and surfaces conflicts.

### 5. Tag and Categorize Systematically
Use Fin Attributes to auto-categorize conversations instead of relying on inconsistent manual tags.
Set conversation data (Department, Product Category) BEFORE Fin handles the conversation so every
interaction is tracked, not just escalated ones.

### 6. Design Smart Escalation Paths
- Go AI-first with a clear "talk to a human" option
- Use Fin Attributes in workflows for intelligent routing
- Enable **AI Summaries at handoff** so agents don't re-ask what Fin already covered
  (Workflows > add "Add summary note" action before assigning to inbox)
- Re-engage waiting customers with Fin if a human hasn't responded yet
  (Workflows > "If teammate has been unresponsive" trigger > add Fin re-engagement step)

### 7. Prepare for Product Releases
Use content tagging to identify all articles affected by a release. Prepare drafts ahead of time,
then bulk-publish when the feature ships:
1. Create a tag like "[Feature name] content updates"
2. Search Knowledge Hub, apply the tag to impacted content
3. Save updates as drafts ahead of release
4. Filter by tag + status "Published with pending draft" and bulk publish on ship day

---

## Continuous Improvement Patterns

### Feeding Fin Transcripts to Internal AI Tools (Trevor, Expert User)
**Result:** Resolution rate increased 6% (to 54%+) over four weeks.

1. Build a custom report pulling Fin conversations where CX score was 1, 2, or 3
2. Pull transcripts each week
3. Feed to an internal AI agent trained on your full knowledge base
4. Use this prompt: "Using the tools I have to train this AI support agent, and without changing
   the product, how could Fin be trained better to improve the customer experience with this engagement?"

### Fix the Support Loop (Fred Walton, Intercom Team)
Fin sometimes surfaces Help Center content that says "please contact support" — confusing customers
who are already in a support conversation. Fix: add Fin Guidance explicitly telling it not to direct
customers to contact support during a live interaction.

### Use AI to Optimize Help Center Content (Beth-Ann, Intercom Team)
Use Claude or ChatGPT with a style guide to repurpose internal docs into customer-friendly articles.

**Prompt for new content:**
> "Transform the attached internal document into a polished, customer-friendly Help Center article
> that strictly follows the attached Style Guide. Use only facts present in the internal doc."

**Prompt for optimization:**
> "Restructure the attached article following the Style Guide. Do not add, omit, or modify any
> factual information — only restructure and reformat."

---

## Copilot for Human Agents

Beyond simple Q&A, Copilot helps human agents with:
- **Faster onboarding:** Acts as a guide sourcing internal resources and past conversation examples
- **Internal process guidance:** Answers "how do we do this again?" from internal documentation
- **Drafting messages:** Helps craft responses with the right tone and brand consistency
- **Multilingual support:** Smooths terminology and phrasing for non-native English speakers

---

## Data Quality

### Replace Manual Tags with Fin Attributes (Sherice, Expert User)
Inconsistent manual tagging makes reports unreliable. Use Fin's AI categorization to automatically
detect and categorize issues. This produces consistent data that enables early problem detection.

### Case Closure Hygiene for AI Readiness (Lance Black, Expert User)
Build a structured closure model with fields like: Technology, Problem Code, Resolution Action,
Root Cause, Repeatability, Escalation level, Customer Effort, KB Article Linked. This improves
data quality and helps Fin identify repeatable automation candidates over time.

---

## Real-World Benchmarks

| Company | Industry | Metric | Result |
|---------|----------|--------|--------|
| IG Group | Financial trading | CX Scores | 90s across channels |
| IG Group | Financial trading | Chat deflection | Up to 70% |
| AppFolio | Real estate | AI involvement | 60-70% |
| AppFolio | Real estate | End-to-end resolutions | 60-65% |
| AppFolio | Real estate | CX Score | 93% |
| Topstep | Trading | AI involvement | 97% across channels |
| Topstep | Trading | Resolution rate | 65% |
| Topstep | Trading | Resolution time | Cut in half (under 1 hour) |
| ZayZoon | Fintech | Self-service rate | 80%+ |
| Pupil Progress | Education | Resolution rate | 55% to 75-80% in 2 months |
| Underdog | Fantasy sports | Ticket deflection | 7,000+ in 48 hours |

**Calibration targets:**
- Good starting point: 50-55% resolution rate
- Strong after optimization: 65-75%
- Exceptional (with deep content investment): 75-80%+
- CX Scores: Top performers achieve 90+ across channels
- Meaningful gains achievable in 2-4 months with consistent daily review

---

## Source
All tips sourced from: https://community.intercom.com/fin-tips-and-best-practices-82
Contributors include Intercom employees (Karl O'Sullivan, Kevin Furlong, Beth-Ann, Dawn, Fred Walton,
Paul D, Mateusz Leszkiewicz) and community experts (Conor Pendergrast, Nathan Sudds, Trevor, Sherice,
Nico Magbiray, Daniel Ronnberg, Lance Black, Julian Murray).
