# Responsible Security Disclosure

## Version

**version 0.0.9**

## Our Security Policy and Your Responsibility

- **POLICY**:

_Our security policy is to fix security vulnerabilities prior to making other changes. a. priori we set out to provide test coverage including coverage of vulnerable use cases to avoid or eliminate the possibility of security vulnerabilities. We solicit feedback from our community as well as encourage transparency through open source software processes._

The "Collective Governance" team and community take all security bugs in "Collective Governance" seriously. Thank you for improving the security of "Collective Governance". We appreciate your efforts and responsible disclosure and will make every effort to acknowledge your contributions.

Report security bugs by emailing the maintainers at security@collective.xyz and include the word "SECURITY" in the subject line.

The lead maintainer will acknowledge your email within a week, and will send a more detailed response 48 hours after that indicating the next steps in handling your report. After the initial reply to your report, the security team will endeavor to keep you informed of the progress towards a fix and full announcement, and may ask for additional information or guidance.

- "Collective Governance" will confirm the problem and determine the affected versions.
- "Collective Governance" will audit code to find any potential similar problems.
- "Collective Governance" will prepare fixes and stage a future release. These fixes will be released as they become available.

Report security bugs in third-party modules to the person or team maintaining that module.

- **SECURITY DISCLOSURE**:

_Your responsibility is to report vulnerabilities to us using the guidelines outlined below._

Please give detailed steps on how to reproduce the vulnerability. Keep these [OWASP](https://www.owasp.org/index.php/Vulnerability_Disclosure_Cheat_Sheet) guidelines in mind. Below are some recommendations for security disclosures:

- "Collective Governance" security contact: mailto:security@collective.xyz
- Disclosure format: When disclosing vulnerabilities please include
  1. Your name and affiliation (if any).
  2. Include scope of vulnerability. Let us know who could use this exploit.
  3. Document steps to identify the vulnerability. It is important that we can reproduce your findings.
  4. Show how to exploit the vulnerability and provide an attack scenario.
  5. Text documents

## "Collective Governance" Checklist: Security Recommendations

Follow these steps to improve security when using "Collective Governance".

1. Always minimize the list of project supervisors
2. Always configure and make final a proposed vote as soon as possible
3. Always provide sufficient voting time of at least one day
4. Use of a voting delay is recommended
5. Always veto suspect proposals immediately.  A proposal can be renewed, but a confirmed transaction can never be cancelled.

### Encryption key for security@collective.xyz

For critical flaws and sensitive security information you may encrypt your transmission with key below.

It is recommended to obtain this signature on a trusted [public keyserver](https://keys.openpgp.org/search?q=DD453D1420D17CA0102FF85C7BEF3762B55F70AD).  The fingerprint of this key is `DD453D1420D17CA0102FF85C7BEF3762B55F70AD` and must be manually confirmed prior to trust.

Or download ascii version of [public_key.asc](public_key.asc)

This document is signed with the above key, see [SECURITY.md.asc](SECURITY.md.asc)

## Semantic Versioning

- Major version incremented when contact information changes in the `security.md` file or in the `security.txt` file that refers to this file. Or a required field in the `security.txt` has changed in a non backwards compatible manner.
- Minor update is a backward compatible change has been made to the aforementioned files.
- Patch update is when a minor typo is fixed but no significant change has been made.
