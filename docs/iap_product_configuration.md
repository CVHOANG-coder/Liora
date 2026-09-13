# IAP product configuration

The app uses the same product identifiers on Google Play and App Store Connect.
Create the store products with these exact, case-sensitive IDs.

## Auto-renewing subscriptions

| Product | Product ID | Period | API group |
| --- | --- | --- | --- |
| Weekly Pro | `com.lioraai.videogenerator.weekly` | 1 week | `SUBSCRIPTION` |
| Annually Pro | `com.lioraai.videogenerator.annually` | 1 year | `SUBSCRIPTION` |
| Annually Sale | `com.lioraai.videogenerator.annuallysale` | 1 year | `SALE` |

Put all three App Store products in the same subscription group. On Google Play,
configure the weekly and annual billing periods to match the API duration. The
sale product remains a separate product because the current API exposes it as a
separate SKU.

## Consumable credits

| Credits | Standard product ID | Subscriber product ID |
| ---: | --- | --- |
| 70 | `com.lioraai.videogenerator.70_credits` | `com.lioraai.videogenerator.70_credits_vip` |
| 150 | `com.lioraai.videogenerator.150_credits` | `com.lioraai.videogenerator.150_credits_vip` |
| 500 | `com.lioraai.videogenerator.500_credits` | `com.lioraai.videogenerator.500_credits_vip` |
| 1000 | `com.lioraai.videogenerator.1000_credits` | `com.lioraai.videogenerator.1000_credits_vip` |
| 5000 | `com.lioraai.videogenerator.5000_credits` | `com.lioraai.videogenerator.5000_credits_vip` |

All ten credit products must be configured as consumable products. The API
returns the subscriber-priced products in `CONSUMABLE_VIP` only when
`isSubscribed` is true; `isVIP` is not used for credit pricing.

## Backend catalog

The `/get-all-package` response must use the IDs above for both `ANDROID` and
`IOS`. In particular, replace the legacy sale ID
`com.nostalia.videogenerator.annuallysale` with
`com.lioraai.videogenerator.annuallysale` before enabling the product in either
store.

Until products exist in the stores, product lookup is expected to return them
as unavailable. Do not treat this as a successful purchase or grant credits.

The Flutter client is prepared to load the matching runtime catalog on Android
and iOS. Before enabling iOS commerce, the backend verification endpoint must
validate App Store receipt data and return the populated `IOS` catalog. Android
continues to validate Google Play purchase tokens.

The Flutter client is prepared to query and finish purchases on both Android
and iOS. Before enabling iOS commerce, the backend verification endpoint must
accept and validate the App Store receipt delivered in `purchaseToken`, and the
API must populate the `IOS` catalog with the matching products.
