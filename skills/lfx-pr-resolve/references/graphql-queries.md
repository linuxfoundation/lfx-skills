<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# GraphQL Queries and Mutations

GraphQL operations used by the PR-resolve workflow.

## Fetch PR review threads (Step 2)

```bash
THREAD_QUERY=$(cat <<'GRAPHQL'
query($owner: String!, $repo: String!, $number: Int!, $threadsCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      number
      title
      url
      baseRefName
      headRefName
      body
      reviewThreads(first: 100, after: $threadsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
          comments(first: 20) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              url
              author { login }
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
      reviews(last: 20) {
        nodes {
          state
          author { login }
          body
          submittedAt
        }
      }
    }
  }
}
GRAPHQL
)
gh api graphql -f query="$THREAD_QUERY" \
  -f owner="$OWNER" -f repo="$REPO" -F number="$NUMBER"
```

Keep `THREAD_QUERY` for subsequent pages. Start without a cursor. While
`reviewThreads.pageInfo.hasNextPage` is true, set `THREADS_CURSOR` to that
page's `endCursor` and run:

```bash
gh api graphql -f query="$THREAD_QUERY" \
  -f owner="$OWNER" -f repo="$REPO" -F number="$NUMBER" \
  -f threadsCursor="$THREADS_CURSOR"
```

Accumulate threads from every page by thread ID. For **each** thread whose
`comments.pageInfo.hasNextPage` is true, set `THREAD_ID` to its ID and
`COMMENTS_CURSOR` to its comment connection's `endCursor`, then run:

```bash
COMMENT_QUERY=$(cat <<'GRAPHQL'
query($threadId: ID!, $commentsCursor: String!) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      id
      comments(first: 100, after: $commentsCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          url
          author { login }
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
)
gh api graphql -f query="$COMMENT_QUERY" \
  -f threadId="$THREAD_ID" -f commentsCursor="$COMMENTS_CURSOR"
```

Append these comments to that thread's initial comments, deduplicating by
comment ID. While `node.comments.pageInfo.hasNextPage` is true, replace
`COMMENTS_CURSOR` with its `endCursor` and repeat the last command. Drain every
thread's comment pages on every thread page before assessing feedback; a reply
beyond either initial limit is still part of the conversation. Treat a failed
page fetch or a missing thread node as an incomplete fetch, not empty feedback.

Retain each comment's `url` from both queries as its permalink for approval plans
and replies; the PR URL alone does not identify an inline conversation.

## Fetch general PR feedback (Steps 2 and 14)

Fetch all pages of general review bodies and PR conversation comments, rather
than relying on the thread query's last 20 reviews. Keep IDs and bodies to
recognize already-handled feedback; conversation comments also have `updated_at`
for detecting edits. Use REST review records as the authoritative general-review
feedback items, keyed by review ID; do not separately assess the same review
bodies from the GraphQL summary. This avoids duplicate plans and replies without
matching an ID-less GraphQL review to a REST record.

```bash
gh api --paginate "repos/$OWNER/$REPO/pulls/$NUMBER/reviews?per_page=100"
gh api --paginate "repos/$OWNER/$REPO/issues/$NUMBER/comments?per_page=100"
```

Before each monitoring fetch, check that the PR is still open:

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
    comment { id }
  }
}
GRAPHQL
```

## Reply to non-thread feedback (Step 9)

General review bodies and PR conversation comments have no review thread ID.
Set `RESPONSE_BODY` to the approved reply, identifying the source and ID/link
(`html_url` from the REST record), and the reviewer: `@mention` humans but use
plain bot names without `@`. Include the fix commit only when files changed.

```bash
gh pr comment "$NUMBER" --repo "$OWNER/$REPO" --body "$RESPONSE_BODY"
```

Record the posted reply as workflow-authored feedback for monitoring. Do not
call `addPullRequestReviewThreadReply` or `resolveReviewThread` for these sources.

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
