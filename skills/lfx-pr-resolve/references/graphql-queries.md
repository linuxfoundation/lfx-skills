<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# GraphQL Queries and Mutations

GraphQL operations used by the PR-resolve workflow.

## Fetch PR review threads (Step 2)

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
          comments(first: 20) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
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
```

The first call omits `after` and returns up to 100 threads plus the first 20
comments of each thread. Preserve every page's nodes and inspect both connections'
`pageInfo`; a successful first call does not establish that the fetch is complete.

For thread pages, while `reviewThreads.pageInfo.hasNextPage` is true, set
`THREAD_CURSOR` to that connection's `endCursor` and repeat the command above with
`-f after="$THREAD_CURSOR"` added before the heredoc. Continue until it is false.

For **each thread on every page**, while its `comments.pageInfo.hasNextPage` is
true, set `THREAD_ID` to that thread's `id` and `COMMENT_CURSOR` to its comments'
`endCursor`, then run:

```bash
gh api graphql -F query=@- -f threadId="$THREAD_ID" -f after="$COMMENT_CURSOR" <<'GRAPHQL'
query($threadId: ID!, $after: String!) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      comments(first: 20, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
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
```

Append these comments to that thread's conversation, update `COMMENT_CURSOR` from
the returned `comments.pageInfo.endCursor`, and repeat until `hasNextPage` is false.
Keep thread and comment cursors separate; reset the comment cursor for each thread.
Do not validate or act on a truncated conversation if any page fetch fails.

## Fetch general PR feedback (Steps 2 and 14)

Fetch all pages of general review bodies and PR conversation comments, rather
than relying on the thread query's last 20 reviews. Keep IDs and bodies to
recognize already-handled feedback; conversation comments also have `updated_at`
for detecting edits. Assess each review body only once even if it appears in
both the GraphQL and REST responses.

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
