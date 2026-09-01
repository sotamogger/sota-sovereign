# Sota Minds — Sovereign v2

Simpler sovereign token for the SOTA NFT. One CEO spends the treasury; holders
vote (simple majority, 3-day window) to replace the CEO, rewrite the
constitution, or open a fixed-price raise. No bonding curve.

- `THRESHOLD_PCT = 50`, `VOTE_DURATION = 3 days`, `raise_price` starts at 1e-8 ETH/token.
- Target chain: Robinhood Chain (EVM L2, chain 4663).
- 10 lifecycle tests in `test/` (bootstrap, raise, buy caps, spend auth, CEO handover, vote expiry, minority can't pass).

Replaces the Base-deployed v1 (which had the bonding curve + lock machinery). Same brand/token: Sota Minds (MINDS).
