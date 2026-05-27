<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# GraphQL Queries and Mutations

GraphQL operations used by the PR-resolve workflow.

## Fetch PR review threads (Step 2)

```bash
gh api graphql -F query=@- -f owner="$OWNER" -f repo="$REPO" -F number=$NUMBER <<'GRAPHQL'
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      number
      title
      url
      baseRefName
      headRefName
      body
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
          comments(first: 20) {
            nodes {
              id
              author { login }
              body
              createdAt
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

**Pagination note:** The query caps at 100 review threads and 20 comments per thread. This covers the vast majority of PRs. If a PR exceeds these limits, fetch additional pages using `pageInfo { hasNextPage endCursor }` and the `after` parameter.

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
