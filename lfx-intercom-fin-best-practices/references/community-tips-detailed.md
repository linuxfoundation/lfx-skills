# Fin Community Best Practices — Detailed Reference

Source: https://community.intercom.com/fin-tips-and-best-practices-82
Last updated: March 2026

This document contains the full text of tips from the Intercom Community's "Fin Tips and Best Practices" section. Tips come from two groups: **Expert Users** (customers running Fin in production) and **Intercom Team** members (employees sharing internal patterns).

---

## Table of Contents

1. [Writing Effective Fin Guidance](#1-writing-effective-fin-guidance)
2. [Knowledge Base & Content Strategy](#2-knowledge-base--content-strategy)
3. [Continuous Improvement Rituals](#3-continuous-improvement-rituals)
4. [Workflows, Tasks & Escalation Patterns](#4-workflows-tasks--escalation-patterns)
5. [Copilot for Human Agents](#5-copilot-for-human-agents)
6. [Data Quality & Conversation Tagging](#6-data-quality--conversation-tagging)
7. [Integrations & Advanced Patterns](#7-integrations--advanced-patterns)
8. [Success Stories & Benchmarks](#8-success-stories--benchmarks)

---

## 1. Writing Effective Fin Guidance

### Use If-Then Logic in Guidance (Karl O'Sullivan, Intercom Team)

One of the easiest ways to improve how Fin handles conversations is to use if-then logic in your Guidance. It helps Fin understand exactly when to apply a response, and what that response should look like.

**Example:** "If a customer asks how to change their password, tell them to click 'Forgot password?' on the login screen and follow the steps."

That is much clearer than: "Explain the password reset process."

By adding a condition and a specific action, you give Fin a clear playbook to follow.

### Simple Language Makes Fin Guidance Smarter (Karl O'Sullivan, Intercom Team)

Fin is not reading between the lines. It takes your guidance literally, so the simpler and more specific your language, the better the results.

**Weak:** "Be friendly and professional."
**Strong:** "Use a professional yet warm tone. Keep responses short and avoid jargon. When a customer is frustrated, acknowledge the issue and say something like, 'I understand how that can be frustrating. Here's what we can do.'"

Think of it like coaching a new team member — if you would not rely on vague tone tips when onboarding a new agent, do not use them with Fin either.

### Start with the Outcome in Mind (Karl O'Sullivan, Intercom Team)

A stronger guidance version: "If a customer asks about the 'search' feature, first ask which product they're using. Then give product-specific instructions."

When writing guidance, ask yourself: what should Fin say first? What should happen next? That simple shift in thinking can make your guidance 10x more effective.

### Use Customer Language, Not Internal Jargon (Mateusz Leszkiewicz, Intercom Team)

Use simple, specific language that mirrors the words your customers actually use. Avoid technical jargon or internal terms. For example, say "log in" instead of "authenticate" to improve understanding and AI searchability.

### Fix the Support Loop (Fred Walton, Intercom Team)

A recurring issue: Fin surfaces Help Center content that includes phrases such as "please contact support" or "reach out to us through the Messenger." This causes confusion during a live support interaction — giving the impression the customer is not already receiving support.

**The fix:** Provide specific guidance instructing Fin not to include phrasing that directs customers to contact support, since they are already in a support conversation. Instead, Fin should treat the interaction as part of the support experience by either providing the information the customer needs or asking for clarification.

---

## 2. Knowledge Base & Content Strategy

### Be Precise — Restate Questions in Answers (Mateusz Leszkiewicz, Intercom Team)

Enhance the clarity of your help articles by restating user questions within the answers. Instead of a simple "Yes" or "No," provide full-sentence responses that mirror the user's query.

**Example:** If a user asks, "Do I need to use the original shipping box to return an item?"
- **Weak:** "No."
- **Strong:** "You can use your own packaging when sending an item back for a return or exchange; there's no need to save the original shipping box."

### Boost AI Answers with a FAQs Tip (Dawn, Intercom Team)

When using collapsible sections in your articles, consider repeating the core question of your FAQ within the answer itself. This significantly helps AI agents like Fin more accurately find and utilize the relevant content.

### Use AI for Content Creation and Optimization (Beth-Ann, Intercom Team)

You can use AI tools like Claude or ChatGPT to repurpose internal documents into customer-friendly Help Center articles and review/rewrite existing content to match customer language.

Create a style guide with structure, formatting, tone of voice, and template. Then use prompts like:

**For new content:** "Transform the attached internal document into a polished, customer-friendly Help Center article that strictly follows the attached Style Guide."

**For optimization:** "Restructure the attached article into a customer-friendly Help Center article following the Style Guide. Do not add, omit, or modify any factual information — only restructure and reformat."

### Use Content Tagging to Prepare Fin for Product Releases (Beth-Ann, Intercom Team)

1. Create a tag like "[Feature name] content updates"
2. Search the Knowledge Hub for content related to the release and apply the tag to anything that needs updating
3. Filter by your tag to create a list of all impacted content
4. Save updates as drafts ahead of the release
5. When ready to ship, filter by tag + status "Published with pending draft", then bulk publish

### Upgrade Fin's Knowledge Base Over Coffee (Beth-Ann, Intercom Team)

After deploying Fin, head to **Fin AI Agent > Train > Suggestions**. You will see AI-generated recommendations for improving your content, with links to the original conversations. Review them once a week and approve about 70% with just a few clicks.

---

## 3. Continuous Improvement Rituals

### The 15-Minute Daily Ritual (Conor Pendergrast, Expert User)

Most teams switch on Fin and hope for the best. The best teams build a ritual:
- Find the conversations Fin could not resolve
- Turn those conversations into better answers with snippets and articles
- Avoid snippet sprawl — too many snippets become unmanageable
- Build habits that help Fin and your team get smarter every day

### Use Topics Explorer to Upgrade Fin Fast (Conor Pendergrast, Expert User)

Guessing where to improve Fin wastes time. Topics Explorer shows you the exact conversations where Fin struggles:

1. Select the right scope and metric to surface real opportunities
2. Generate a Testing Group from past conversations by topic
3. Rate answers with keyboard shortcuts and product-expert notes
4. Decide the fix type: content (articles/snippets), data (attributes/connectors), or actions (Fin Tasks)
5. Prevent wrong-product answers by pushing the right user attributes into Intercom

### Feeding Fin Conversation Transcripts to Internal AI Tools (Trevor, Expert User)

**Result:** Resolution rate increased by 6% (up to 54%+) over four weeks.

Setup:
1. Build a custom report pulling Fin AI Agent conversations where CX score was 1, 2, or 3
2. Pull transcripts each week
3. Train an internal AI agent on all tools available to train Fin
4. Use the OPTIMIZE button on all guidance — it improves logic and finds conflicts

### How Pupil Progress Went from 55% to 75% Resolution Rate in 2 Months (Conor Pendergrast, Expert User)

Key strategies:
- Go AI-first with a clear "talk to a human" option
- Rewrite the help center for two audiences: people and Fin
- Use audiences and attributes so answers change by role, subject, or context
- Use custom answers, snippets, and narrow articles for precise guidance
- Focus relentlessly on content quality

Result: Resolution rate now holds steady at 75-80% weekly.

---

## 4. Workflows, Tasks & Escalation Patterns

### Use Fin to Re-engage Customers Waiting on a First Reply (Kevin Furlong, Intercom Team)

Enable Fin to re-engage customers if their conversation has not been picked up yet. After a set wait time, Fin checks back in: "While you're waiting, would you like to chat with me (Fin AI Agent)?"

How to enable:
1. Go to your Workflows page
2. Create a new workflow using the "If teammate has been unresponsive" trigger
3. In audience rules, select the team inbox(es)
4. Add the Fin re-engagement step

### Save Time with AI Summaries at Handoff (Kevin Furlong, Intercom Team)

Intercom generates a clean summary at the point of handoff from Fin as an internal note, so teammates do not need to scroll through everything to understand what was covered.

How to enable:
1. Go to your Workflows page
2. In an existing triage workflow, add the "Add summary note" action before assigning to an inbox

This is also powerful when an old conversation is reopened and teammates need to get quickly up to speed.

### Fin Attributes for Escalations in Workflows & Tasks (Nathan Sudds, Expert User)

Use Fin Attributes within workflows and tasks to create smarter escalation routing. Fin can detect conversation attributes (like product area, issue type, urgency) and these can be used in workflow conditions to route escalations to the right team automatically.

### Procedures vs. Tasks (Conor Pendergrast, Expert User)

Fin Procedures have replaced the older Tasks system:
- Procedures offer more flexibility in controlling how Fin behaves
- Important for support leaders and CX teams to plan migration to Procedures
- Understanding the differences matters for your AI support strategy

---

## 5. Copilot for Human Agents

### Use Copilot Beyond Simple Q&A (Kevin Furlong, Intercom Team)

Production use cases from Intercom's own team:

- **Faster Onboarding:** New joiners use Copilot as a guide, sourcing internal resources and examples from previous chats — drastically shortening ramp time
- **Internal Process Guidance:** For "how do we do this again?" moments, Copilot answers from internal articles and documentation
- **Time Savings:** By aggregating info from external knowledge bases (Notion, Guru, Confluence), past tickets, macros, and PDFs, Copilot delivers summarized responses in one place
- **Drafting Messages:** Copilot helps agents craft responses with the right tone and on-brand consistency
- **Multilingual Support:** For teammates who speak English as a second language, Copilot smooths terminology and phrasing

---

## 6. Data Quality & Conversation Tagging

### When Your Data Doesn't Tell the Truth (Sherice, Expert User)

When tagging is inconsistent, the data turns unreliable. Use Fin's AI categorization to replace inconsistent manual tagging. Let Fin detect and categorize issues automatically using Fin Attributes. This produces consistent, accurate data that enables early problem detection.

### Case Closure Hygiene & Fin AI Readiness (Lance Black, Expert User)

Build a structured Case Closure Data Model. Recommended structured closure fields:
- Technology / Sub-Technology
- Problem Code / Resolution Action / Root Cause
- Repeatability / Escalation / Customer Effort
- KB Article Linked

The intent is to improve data quality, reduce "Other" categories, and help Fin identify repeatable automation candidates over time.

---

## 7. Integrations & Advanced Patterns

### Send Custom Slack Notifications via Workflows and Data Connectors (Paul D, Intercom Team)

The default "Notify Slack Channel" action does not allow customization. With a Data Connector, you can create custom Slack notifications:

1. Set up a webhook in Slack: Settings > Manage apps > Incoming WebHooks > Add to Slack > copy the Webhook URL
2. Create the Data Connector in Intercom calling the Slack webhook URL with your custom message payload

### Using Intercom as a ChatGPT Connector (Daniel Ronnberg, Expert User)

With a Business license, connect Intercom directly to ChatGPT to:
- Scan recent conversations and surface common feedback patterns
- Gather feedback on specific topics across conversations
- When launching a new feature, have ChatGPT review help articles and flag where updates are needed

---

## 8. Success Stories & Benchmarks

| Company | Industry | Key Metric | Result |
|---------|----------|-----------|--------|
| IG Group | Financial trading | CX Scores | 90s across channels |
| IG Group | Financial trading | Chat deflection | Up to 70% |
| AppFolio | Real estate | AI involvement | 60-70% across support |
| AppFolio | Real estate | End-to-end resolutions | 60-65% |
| AppFolio | Real estate | CX Score | 93% |
| Topstep | Trading | AI involvement | 97% across channels |
| Topstep | Trading | Resolution rate | 65% |
| Topstep | Trading | Resolution time | Cut in half (under 1 hour) |
| ZayZoon | Fintech | Self-service rate | 80%+ |
| ZayZoon | Fintech | Monthly volume | 50,000 conversations |
| Pupil Progress | Education | Resolution rate | 55% to 75-80% in 2 months |
| Underdog | Fantasy sports | Ticket deflection | 7,000+ in 48 hours |
| Underdog | Fantasy sports | Resolution rate | 2x previous workflows |

### Common Patterns in High-Performing Deployments

- AI-first approach with clear human escalation path
- Help center rewritten for both humans AND AI
- Daily or weekly review ritual for Fin's missed conversations
- Structured use of Fin Attributes for automatic categorization
- Content tagging and release management processes
- Copilot enabled for human agents to supplement Fin
- The OPTIMIZE button used on all new guidance entries
- Named guidance entries for easy management at scale
- Suggestions feature reviewed weekly for knowledge base improvements
