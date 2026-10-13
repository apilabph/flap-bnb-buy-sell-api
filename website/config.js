export const config = {
  slug: "flap-bnb-buy-sell-api",
  short: "Flap",
  name: "Flap BNB Buy and Sell API",
  host: "flap-bnb-trade",
  network: "BNB Smart Chain · 56",
  native: "BNB",
  evm: true,
  accent: "#d0ff00",
  port: 8813,
  fee: "0x940BB768d8cD2fBa11f9fE7692dce4C0cdedFcc1",
  hero: "Buy and Sell Flap API",
  lead: "Inspect native-BNB Flap tokens and integrate a stage-aware transaction builder with exact approvals and a minimum net output.",
  status:
    "Market inspection is available. Quote, trade and approval endpoints need the operator’s settlement contract deployment. Funded trading and fee collection are not active.",
  statusLabel: "Inspection beta",
  stage: "Flap → Pancake",
  coverage: [
    "Native-BNB Flap curves for reviewed token versions 0–7.",
    "Canonical Pancake V2 graduation pools.",
    "Pancake V3 adapter is implemented; mainnet simulation verification is still pending.",
  ],
  limits: [
    "Infinity / V4 markets and non-native quote assets.",
    "Duel, staged, killed and unknown future token versions.",
    "Sells taxed on transfer from your wallet into the settlement contract.",
  ],
  evidence:
    "Read-only state-overlay tests exercised curve and Pancake V2 buy/sell roundtrips against mainnet protocol state. The router was not deployed and no funds moved. Pancake V3 mainnet verification is pending.",
  special:
    "Use a native-BNB Flap token address. Market inspection can work before the settlement contract exists; that does not mean trading is activated.",
  api: "https://flap-bnb-trade.apilabph.workers.dev",
  github: "https://github.com/apilabph/flap-bnb-buy-sell-api",
};
