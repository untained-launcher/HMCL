# Repository Requirements

These rules apply to all changes made to this repository. The code style sections apply to all Java code written or modified in this repository.

## Nullability

Apply the following requirements when writing or modifying code. Do not use them as code-review criteria.

- Every class declared in a newly added Java source file must be annotated with JetBrains Annotations `@NotNullByDefault`.
- When writing or modifying Java code, any type, field, parameter, return value, local variable, or generic type argument that may be `null` must be explicitly annotated with `@Nullable`.
- Nullability in code being written or modified must never be implicit.

## Immutability

- Immutable arrays and collections must be explicitly annotated with JetBrains Annotations `@Unmodifiable` or `@UnmodifiableView` as appropriate.
- For arrays, use type-use syntax such as `String @Unmodifiable []`.

## Documentation

Apply the following requirements when writing or modifying code. Do not use them as code-review criteria.

- Every class, field, and method must have documentation.
- Documentation must use `///` Markdown-style Javadoc comments.
- Keep documentation accurate and specific to the actual behavior, constraints, and side effects.
- Add concise implementation comments inside complex logic whenever they materially improve readability or explain non-obvious behavior.

## Confidentiality

These requirements apply to every change committed to this repository, regardless of who or what produced it.

- Never disclose personal information. Commit messages, diffs, source code, comments, documentation, test fixtures, build logs, and generated files must not contain real names, personal email addresses, phone numbers, home addresses, identity numbers, personal accounts, or any other data that can identify an individual.
- Do not add `Assisted-by:`, `Co-authored-by:`, or any other attribution trailer to commit messages. Such trailers are not required by this project, and they only serve to expose the identities of the people involved.
- Keep the git identity anonymized: use the repository's preconfigured anonymous identity rather than a real name, a personal email address, or any address that can be traced back to the account. A GitHub no-reply address still embeds the account name, so it hides the mailbox but not the identity.
- Never commit credentials. Tokens, passwords, private keys, and `.env` files must be referenced from repository or organization secrets instead.
- When importing third-party code or assets, record the upstream project and its license, but keep the upstream author's personal contact details out of the repository.
- Artifacts published by CI, including release notes and changelogs, must be free of personal information as well. Workflow definitions must not embed personal identities in their names, descriptions, or output.
