<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Help Center content standards for Fin

Use this reference when writing a new Help Center article, rewriting or restructuring an existing one, or reviewing
one before it is published. It builds on [fin-best-practices.md](fin-best-practices.md) and does not replace it: that
file covers Fin as a whole, and this one covers the article itself.

**Audience:** Support/CX team members and anyone drafting articles with an AI assistant. No coding required.

---

## How Fin uses articles

Fin doesn't invent answers. It retrieves published content and rephrases it, so a weak article produces a weak
answer. Two consequences shape every rule below:

- **If it confuses a person, it confuses Fin.** Clear structure helps both.
- **Fin may retrieve one section, not the whole article.** A paragraph that depends on the one above it is still
  shown to the customer on its own, so every section must make sense in isolation.

---

## Writing rules

### One question per article

Each article answers one question, and its title is that question, phrased the way a customer would ask it. This
applies to anything that needs steps, a policy, or more than a short answer: a page that answers several of those
becomes several articles, each linking to its neighbors. Scope matters more than length: a focused article gives Fin
one clear match instead of several competing ones.

Short standalone answers can go in an FAQ article instead, with one header per question and each answer complete on
its own, so Fin can retrieve any one of them in isolation.

### Specificity and exact values

Vague articles make Fin hedge, guess, or give up. State the figure the source supports.

Don't write "shortly", "approximately", "may" or "a few minutes" unless the source says exactly that. Fin repeats the
hedge, and the customer still doesn't have an answer.

### Single path (articles)

Give one clear answer per article, and avoid "if X, then Y, otherwise Z". Fin handles straight-line answers far
better. If an answer truly branches, split it into separate articles.

### Actionable, with clean hand-offs

Every article either resolves the question or gives the customer a concrete next step. When the team has to act, the
article says so, lists the details the team needs, and stops there.

Don't tell the customer to email, reply, or contact support, and never include an email address that routes into an
Intercom inbox. The customer is often already in a conversation with Fin, so those instructions send them in a loop.
Handover belongs in Fin Guidance: guidance tells Fin to ask for any missing details once, then hand off. This is the
article-side half of "Fix the Support Loop" in [fin-best-practices.md](fin-best-practices.md).

### Exact UI labels

Use labels exactly as they appear in the product, in bold, and never paraphrase on-screen text. Customers search for
the words they see, and one wrong label can make an article useless.

Every screenshot needs matching text, because the text is what Fin reads.

### Consistent terminology

Use one term per concept, everywhere. Fin matches words, so if two articles use different words for the same
thing, Fin may answer the same question two ways. This goes further than defining terms on
first use (pillar 8 in [fin-best-practices.md](fin-best-practices.md)): a term can be defined and still drift.

Keep a glossary with three columns (the term to use, what it means, and the terms to avoid), and share it
with everyone who drafts articles.

### Logical structure with keyword repetition

Open with the answer, repeat key terms, and end with a clear outcome. Repeat the main keywords in every section, and
don't swap in synonyms, so Fin can match whichever section it retrieves. Stop at two uses of a word per paragraph;
beyond that, writing turns robotic. This extends pillar 2: restating the question helps Fin find the article, and
repeating keywords helps it find the right section.

### Explicit context

Fin can't fill gaps the way a teammate can. Spell out the starting point, what should happen, and when something has
gone wrong.

### No vague references

Never use "this", "that", or "the system" without a clear noun before it. A section retrieved on its own loses the
sentence that explained what "this" meant.

### No volume claims or internal notes

Nothing like "our most common question" or "review this later". Fin repeats whatever is published, including notes
meant for the team.

### Legal and policy wording stays intact

Wording taken from terms of service or a published policy (deadlines, eligibility, limits, final-sale terms) is not
rewritten. Paraphrasing a policy changes its meaning, and Fin will repeat the paraphrase as policy.

---

## Shape of a good article

Use this structure as the default. It orders information the way the customer needs it: what it is, why it matters,
then how to do it.

| Section | What goes in it |
| --- | --- |
| **Description** | The article's description field, not the body. One sentence, 140 characters or fewer, saying what the article answers. |
| **Overview** | The direct answer, in at least two sentences. If the article is role-specific, it also says who it applies to. |
| **Why it matters** | When and why a customer needs this. This lets Fin match a vaguely worded question to the right article. |
| **How to do it** | Numbered steps. Each says what the customer does, what they see, and what happens. |
| **Result** | What changed, and what the customer can do next. |
| **Related articles** | Links to the neighboring questions. |

A section with only one or two sentences gives Fin very little to work with, so add the context the source supports.
Don't reference steps, concepts, or terms before they have been introduced.

---

## Formatting

These are house-style defaults. Confirm or adjust them for your Help Center.

- **Headings:** sentence case, except proper nouns and named features. Don't start headings with -ing verbs.
- **Lists:** numbered lists for sequential steps only, and bullets for options and breakdowns.
- **Bold before colons:** bold the word or phrase before a colon.
- **Short paragraphs:** three or four sentences at most.
- **Punctuation:** end every sentence and list item with punctuation. No emojis, no ALL CAPS, and no em dashes.

---

## Source of truth

When sources disagree, the higher one wins. Flag the conflict rather than choosing between them, because a silent
choice hides a contradiction that will surface again in another article.

1. Terms of service and published policies.
2. Answers confirmed by the owning team.
3. Published Help Center articles.
4. Drafts, FAQ sheets, and internal notes.

---

## Five failures that break a Help Center

1. **Duplicates.** The biggest risk, because Fin picks between them unpredictably. Search the Help Center before
   adding anything, and merge articles that answer the same question.
2. **Contradictions.** Different figures in different places. Resolve them using the source-of-truth order above.
3. **Terminology drift.** Several words for the same thing. It accumulates quietly and degrades every answer.
4. **Empty placeholders.** A titled article with no content is worse than none, because Fin can still retrieve it.
   Fill it or delete it.
5. **Content Fin can't read.** Broken or internal links, and content that exists only as a PDF or image.
   Multi-column PDFs read as a jumble, so convert them to regular articles.

---

## What belongs in an article, and what doesn't

| Help Center article | Fin Guidance | Fin Attributes |
| --- | --- | --- |
| What something is and why it exists. | Which words Fin should use, and synonym mapping. | How conversations are classified for reporting and routing. |
| Step-by-step instructions. | Tone and register. | |
| What the result of an action is. | When to ask a clarifying question. | |
| Links to related articles. | When and how to hand over to the team. | |

---

## Drafting articles with an AI assistant

Set up a project so every conversation shares the same context, and attach:

- **The Help Center structure:** the collections and the questions in each, so the assistant knows where every
  article belongs.
- **Legal and policy documents:** the source of truth for money, eligibility, and deadlines.
- **Existing articles and drafts,** however rough. Accurate rough notes beat polished but outdated prose.
- **Screenshots of every screen a customer uses.** The assistant can't see the product, and without screenshots it
  guesses button labels.
- **The glossary.**
- **The Fin Guidance and Fin Attributes configured in Intercom,** so articles agree with the wording Fin has been told
  to use.
- **This file,** as the structural standard.

Then work like this:

- **Never let it assume.** Tell the assistant to ask when anything is unclear, rather than fill gaps with plausible
  guesses.
- **One article per conversation.** Long threads covering several articles drift.
- **Start with what the customer is trying to do,** not what you want written.
- **Answer its clarifying questions properly.** The whole article depends on the answers.
- **Review before publishing.** The assistant sounds confident whether or not the facts are right. You check the
  facts, and this standard checks the structure.

---

## Keeping articles current

When a policy, fee, or screen changes, update the affected articles the same week, and publish articles for new
features before they go live. This turns pillar 7's release prep into a deadline.

---

## Pre-publish checklist

The first five checks are the content-quality questions from
[fin-best-practices.md](fin-best-practices.md#content-quality-standards-fin-academy). The rest come from this file.

1. Is the first sentence a direct answer?
2. Are procedures in numbered steps, not prose?
3. Does it state who it applies to if role-specific?
4. Are all acronyms defined on first use?
5. Does the language match how users actually phrase their questions?
6. Does it answer one question only, with the question as the title? For an FAQ article, does each question have its
   own header and a complete answer?
7. Is the description written, in 140 characters or fewer?
8. Did you search the Help Center first, and confirm no other article answers this question?
9. Does every section make sense when read on its own?
10. Is it specific and single-path, with no vague phrasing and no branching?
11. Are all figures and UI labels exact and confirmed, with glossary terms throughout?
12. Is every word used no more than twice in a paragraph?
13. Does it end in a concrete next step, with any hand-off listing what the team needs and no "contact support" or
    routed email address?
14. Do screenshots have matching text?
15. Do all links work and point to public pages?

---

## Sources

- Intercom: [Optimize your Help Center for Fin AI Agent](https://www.intercom.com/help/en/articles/7269326-optimize-your-help-center-for-fin-ai-agent)
- Intercom: [Optimizing content for Fin](https://www.intercom.com/help/en/articles/7860255-optimizing-content-for-fin)
- Intercom: [Top ten ways to optimize Fin](https://www.intercom.com/help/en/articles/9790492-top-ten-ways-to-optimize-fin)
