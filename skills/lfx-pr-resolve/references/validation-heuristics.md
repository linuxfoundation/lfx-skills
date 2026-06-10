<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Validation Heuristics and False-Positive Handling

How to assess whether a reviewer's comment is actually correct before implementing it.

## Per-comment validation

Reviewers can make mistakes, they may misread the code, apply conventions from a different repo, or flag something that is already handled elsewhere. Blindly implementing every comment can introduce regressions.

For each unresolved thread and each collected general PR review comment:

1. **Read the actual code** at the referenced file and line, not just the diff snippet the reviewer saw. Read enough surrounding context (20-30 lines) to understand what the code is doing.
2. **Check the repo's existing patterns**, search for how similar code is written elsewhere in the codebase. If the reviewer says "use X pattern" but the rest of the repo uses Y pattern, that's a red flag.
   ```bash
   # Example: reviewer says "use BehaviorSubject" but check what the repo actually does
   grep -r "signal(" src/app/modules/ --include="*.ts" -l | head -10
   grep -r "BehaviorSubject" src/app/modules/ --include="*.ts" -l | head -10
   ```
3. **Cross-reference with project conventions**, check CLAUDE.md, eslint configs, or other style guides in the repo. The reviewer's suggestion may conflict with established conventions.
4. **Assess the comment's validity:**

| Assessment | Meaning | Action |
|------------|---------|--------|
| **Valid** | The reviewer is correct, the code needs to change | Proceed to categorize and address |
| **Likely false positive** | The reviewer appears to have misread the code or applied the wrong convention | Flag for user with your reasoning |
| **Partially valid** | The reviewer has a point but their suggested fix is wrong or incomplete | Flag with a recommended alternative |
| **Outdated** | The code has changed since the comment, the issue no longer exists | Flag as already addressed |

The goal is not to dismiss reviewer feedback, it's to catch cases where implementing the suggestion would make the code worse. When in doubt, lean toward implementing the change, but always surface your assessment to the user.

## Responding to a confirmed false positive

When the user confirms a comment is a false positive, draft a respectful response that:
- Acknowledges the reviewer's intent ("Good eye on this, I can see why it looks off")
- Explains the repo convention or pattern with evidence ("This repo uses signals for component-local state, you can see the same pattern in `member-form.component.ts`, `attendance-list.component.ts`, etc.")
- Offers to discuss further if the reviewer disagrees ("Happy to discuss if you think we should approach this differently")

Never be dismissive. The reviewer took time to read the code, even a wrong comment shows engagement.
