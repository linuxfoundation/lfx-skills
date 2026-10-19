<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# GraphQL Queries and Mutations

GraphQL operations used by the PR-resolve workflow.

## Scan PR review threads (Step 2)

> Use this scan to enumerate all thread IDs; metadata alone cannot detect comment changes.

```bash
gh api graphql -F query=@- -f owner="$OWNER" -f repo="$REPO" -F number=$NUMBER <<'GRAPHQL'
query($owner: String!, $repo: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      number
      title
      url
      baseRefName
      headRefName
      headRefOid
      body
      reviewThreads(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
        }
      }
    }
  }
}
GRAPHQL
```

> This is the completeness pass, not the full-conversation pass.

The first call omits `after` and returns up to 100 thread metadata records.
Preserve every page's nodes and inspect `reviewThreads.pageInfo`; a successful
first call does not establish that the scan is complete.

While `reviewThreads.pageInfo.hasNextPage` is true, set `THREAD_CURSOR` to that
connection's `endCursor` and repeat the command above with
`-f after="$THREAD_CURSOR"` added before the heredoc. Continue until it is
false.

Do not stop at "no unresolved threads" until you have also fetched general
review bodies and PR conversation comments; inline threads are not the only
feedback source.

Treat the scan as source enumeration, not an eligibility filter. After it
completes, hydrate every unresolved thread's full conversation on every pass,
including monitoring and fresh reruns. Only then compare comment IDs, bodies,
and update timestamps with the assessed-feedback record and select eligible
items. A previously handled or deferred thread can receive a new reply or edit
without changing its metadata or `headRefOid`; neither is a safe reason to skip
reading it. Unchanged handled items remain excluded from action after comparison.

## Hydrate an unresolved thread conversation (Step 2)

> Read every unresolved conversation completely before comparing or filtering feedback.

```bash
gh api graphql -F query=@- -f threadId="$THREAD_ID" <<'GRAPHQL'
query($threadId: ID!) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      id
      isResolved
      isOutdated
      path
      line
      startLine
      diffSide
      comments(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          url
          author { login __typename }
          body
          createdAt
          updatedAt
          path
          line
          startLine
        }
      }
    }
  }
}
GRAPHQL
```

Keep thread-page cursors and comment cursors separate.

If `comments.pageInfo.hasNextPage` is true, set `COMMENT_CURSOR` to that
connection's `endCursor`, keep `THREAD_ID` fixed, and continue with:

```bash
gh api graphql -F query=@- -f threadId="$THREAD_ID" -f after="$COMMENT_CURSOR" <<'GRAPHQL'
query($threadId: ID!, $after: String!) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      comments(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          url
          author { login __typename }
          body
          createdAt
          updatedAt
          path
          line
          startLine
        }
      }
    }
  }
}
GRAPHQL
```

Append returned comments to that thread's conversation and repeat until
`hasNextPage` is false. Do not validate or act on a truncated conversation if
any required page fetch fails.

## Fetch general PR feedback (Steps 2 and 14)

> Fetch these sources on every pass; they are not covered by thread hydration.

Fetch all pages of general review bodies and PR conversation comments, rather
than relying on thread data or recent commits alone. Keep IDs, bodies, and
available timestamps to recognize already-handled feedback and detect edits.
Assess each review body only once even if it appears in multiple API responses.

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$NUMBER/reviews?per_page=100"
gh api --paginate "repos/$OWNER/$REPO/issues/$NUMBER/comments?per_page=100"
```

> Before each monitoring fetch, confirm the PR is still open.

```bash
gh pr view "$NUMBER" --repo "$OWNER/$REPO" --json state --jq '.state'
```

## Reply to a review thread (Step 9)

```bash
gh api graphql -F query=@- -f threadId="$THREAD_ID" -f body="$RESPONSE_BODY" <<'GRAPHQL'
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId
    body: $body
  }) {
    comment { id url }
  }
}
GRAPHQL
```

## Reply to general PR feedback (Step 9)

For a general review body or PR conversation comment, set `RESPONSE_BODY` to a
specific answer that links to the source's permalink and identifies the reviewer
(plain bot name, never an `@mention` for a bot). Include the published fixing
commit SHA when applicable; omit a commit reference when no change was needed.

```bash
gh api --method POST "repos/$OWNER/$REPO/issues/$NUMBER/comments" \
  -f body="$RESPONSE_BODY"
```

Require a returned comment `id` and `html_url` before recording the response as
posted. Retain its permalink in the Step 2 assessed-feedback record. General
feedback has no review thread to resolve; do not call `resolveReviewThread` for it.

## Resolve a review thread (Step 10)

```bash
gh api graphql -F query=@- -f threadId="$THREAD_ID" <<'GRAPHQL'
mutation($threadId: ID!) {
  resolveReviewThread(input: {
    threadId: $threadId
  }) {
    thread { isResolved }
  }
}
GRAPHQL
```
