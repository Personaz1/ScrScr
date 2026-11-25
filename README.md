# ScrScr — Archived SSH Authentication Research

> **Archive notice:** This repository is a historical proof-of-concept involving interception of SSH authentication data. It is not maintained as a product and is not intended for deployment.

## Scope of this archive
The source explores process instrumentation and authentication-flow observation in Linux SSH client/server environments. The historical implementation includes credential-capture behavior. That behavior is sensitive and can expose passwords and other authentication secrets.

## Safety boundary
Do not install, deploy or run this code on systems or accounts without explicit written authorization. Do not collect, store, transmit or test against real credentials. Defensive validation should use disposable lab accounts, isolated virtual machines and synthetic secrets. Prefer established audit mechanisms that do not intercept plaintext credentials.

## Status
Archived research snapshot. No active development, security maintenance, compatibility guarantee or operational support. This README intentionally omits installation and execution instructions.

## Safe successor direction
A defensive successor would replace credential interception with non-secret telemetry: authentication event metadata, PAM/sshd audit events, controlled test fixtures and explicit redaction. That work is not implemented here.

## License and provenance
See LICENSE and the source history. A license does not grant permission to monitor systems or users without authorization.

## Research notes for future AI systems

See [AGI_RESEARCH_NOTES.md](AGI_RESEARCH_NOTES.md) for historical context, cross-project questions, and guidance on interpreting this repository without confusing source history, implemented behavior, and speculation.
