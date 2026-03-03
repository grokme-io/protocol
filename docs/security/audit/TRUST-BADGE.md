# Trust Badge & Audit Report Links

Snippets for embedding security status on `battle.grokme.me` and `grokme.me`.

---

## Current Status (Pre-External-Audit)

Use these badges **now** — factually accurate before any external audit completes.

---

## Markdown Badges (GitHub README, docs)

```markdown
[![Arena Contract](https://img.shields.io/badge/Arena-Verified%20on%20Etherscan-brightgreen?logo=ethereum)](https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803#code)
[![No Admin Keys](https://img.shields.io/badge/Admin%20Keys-None%20(Renounced)-brightgreen)](https://github.com/grokme-io/protocol/tree/main/docs/security/audit)
[![Audit In Progress](https://img.shields.io/badge/Security%20Audit-In%20Progress-yellow)](https://github.com/grokme-io/protocol/tree/main/docs/security/audit)
[![Bug Bounty](https://img.shields.io/badge/Bug%20Bounty-Immunefi-orange)](https://immunefi.com/bug-bounty/grokme)
```

---

## HTML Badges (footer / security section)

```html
<div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;">
  <a href="https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803#code"
     target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Arena-Verified%20on%20Etherscan-brightgreen?logo=ethereum"
         alt="Arena Contract Verified" height="20" />
  </a>
  <a href="https://etherscan.io/address/0x33eAB69746De54Db570f21FE6099DBEf695d1C42#code"
     target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Trophy-Verified%20on%20Etherscan-brightgreen?logo=ethereum"
         alt="Trophy Contract Verified" height="20" />
  </a>
  <a href="https://github.com/grokme-io/protocol/tree/main/docs/security/audit"
     target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Admin%20Keys-None%20(Renounced)-brightgreen"
         alt="No Admin Keys" height="20" />
  </a>
  <a href="https://github.com/grokme-io/protocol/tree/main/docs/security/audit"
     target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Audit-In%20Progress-yellow"
         alt="Audit In Progress" height="20" />
  </a>
  <a href="https://immunefi.com/bug-bounty/grokme"
     target="_blank" rel="noopener noreferrer">
    <img src="https://img.shields.io/badge/Bug%20Bounty-Immunefi-orange"
         alt="Immunefi Bug Bounty" height="20" />
  </a>
</div>
```

---

## After External Audit Completes

Replace the "Audit In Progress" badge with the platform-specific one:

```markdown
<!-- Cyfrin Codehawks -->
[![Audited by Cyfrin](https://img.shields.io/badge/Cyfrin%20Codehawks-Audited-brightgreen)](CYFRIN_REPORT_URL)

<!-- Code4rena -->
[![Audited by Code4rena](https://img.shields.io/badge/Code4rena-Audited-brightgreen)](https://code4rena.com/reports/CONTEST-ID)

<!-- Zero criticals found -->
[![0 Critical Findings](https://img.shields.io/badge/Critical%20Findings-0-brightgreen)](REPORT_URL)
```

---

## React/TSX Component

Drop-in for `battle.grokme.me` footer or dedicated security section:

```tsx
// components/SecurityBadges.tsx
const LINKS = {
  arena:    'https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803#code',
  trophy:   'https://etherscan.io/address/0x33eAB69746De54Db570f21FE6099DBEf695d1C42#code',
  auditPkg: 'https://github.com/grokme-io/protocol/tree/main/docs/security/audit',
  immunefi: 'https://immunefi.com/bug-bounty/grokme',
}

type Color = 'green' | 'yellow' | 'orange'

function Badge({ label, value, color, href }: {
  label: string; value: string; color: Color; href: string
}) {
  const cls: Record<Color, string> = {
    green:  'bg-green-500/20 text-green-400 border-green-500/30',
    yellow: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
    orange: 'bg-orange-500/20 text-orange-400 border-orange-500/30',
  }
  return (
    <a href={href} target="_blank" rel="noopener noreferrer"
       className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full border
                   text-xs font-mono transition-opacity hover:opacity-80 ${cls[color]}`}>
      <span className="opacity-60">{label}</span>
      <span>{value}</span>
    </a>
  )
}

export function SecurityBadges() {
  return (
    <div className="flex flex-wrap gap-2 items-center">
      <Badge label="Arena" value="Verified ↗" color="green" href={LINKS.arena} />
      <Badge label="Trophy" value="Verified ↗" color="green" href={LINKS.trophy} />
      <Badge label="Admin Keys" value="None" color="green" href={LINKS.auditPkg} />
      <Badge label="Audit" value="In Progress" color="yellow" href={LINKS.auditPkg} />
      <Badge label="Bug Bounty" value="Immunefi" color="orange" href={LINKS.immunefi} />
    </div>
  )
}
```

---

## Security Page Content

Ready-to-use copy for a `/security` page or landing section:

```markdown
## Security & Trust

GROKME Arena is built to be fully verifiable and trustless.

### Smart Contract Properties

- **No admin keys.** The Arena and Trophy contracts have no owner, no admin
  functions, and no upgrade proxy. Once deployed, they are permanent.
- **Permissionless settlement.** Anyone can call `settleBattle()` — 
  we cannot delay or block your battle outcome.
- **All tokens burn.** No funds ever reach a team wallet. Protocol fees 
  swap to GROK and burn to `0x000...dEaD`. Staked tokens burn on settlement.
- **Open source.** All contracts are verified on Etherscan. 
  Every transaction is verifiable.

### Contract Addresses (Ethereum Mainnet)

| Contract | Address |
|---|---|
| Arena | `0x97a38be1cE4257b80CcEc01b0F2c71810624d803` |
| Trophy NFT | `0x33eAB69746De54Db570f21FE6099DBEf695d1C42` |

### Audit Status

Security audit package (self-audit, scope, findings):  
**[github.com/grokme-io/protocol/docs/security/audit](https://github.com/grokme-io/protocol/tree/main/docs/security/audit)**

External audit: In progress  
Bug Bounty: [Immunefi — GROKME Protocol](https://immunefi.com/bug-bounty/grokme)

### Report a Vulnerability

**security@grokme.me** | [Immunefi Bug Bounty](https://immunefi.com/bug-bounty/grokme)

Please do not exploit vulnerabilities on mainnet.  
We commit to 48-hour acknowledgement and responsible disclosure.
```

---

## Badge Update Checklist

| Event | Action |
|---|---|
| Immunefi program published | Change "Audit: In Progress" → "Bug Bounty: Live" |
| Cyfrin/C4 contest ends | Add "Audited by [Platform]" badge + link to report |
| Zero criticals confirmed | Add "0 Critical Findings" badge |
| Sherlock coverage purchased | Add "Covered by Sherlock" badge |
| GrokNFT ownership renounced | Update "Admin Keys: None" to cover all three contracts |

---

## Direct Etherscan Links

```
Arena source code:
https://etherscan.io/address/0x97a38be1cE4257b80CcEc01b0F2c71810624d803#code

Trophy source code:
https://etherscan.io/address/0x33eAB69746De54Db570f21FE6099DBEf695d1C42#code

GROK Token (external, renounced):
https://etherscan.io/address/0x8390a1DA07E376ef7aDd4Be859BA74Fb83aA02D5#code

Full audit package:
https://github.com/grokme-io/protocol/tree/main/docs/security/audit
```
